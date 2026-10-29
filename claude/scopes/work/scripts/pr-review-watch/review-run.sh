#!/bin/bash
set -uo pipefail

MODE="${1:?usage: review-run.sh <council|verify|approve> <owner/repo> <number> <sha> <since> <url> <report> <state-key>}"
REPO="${2:?}"
NUMBER="${3:?}"
SHA="${4:?}"
SINCE="${5:?}"
URL="${6:?}"
REPORT="${7:?}"
KEY="${8:?}"
HERE="$(cd "$(dirname "$0")" && pwd)"
COUNCIL="${PR_REVIEW_WATCH_COUNCIL:-$HOME/.claude/scripts/pr-council-review/run.sh}"
TIMEOUT="${PR_REVIEW_WATCH_TIMEOUT:-2700}"
VERIFY_MODEL="${PR_REVIEW_WATCH_VERIFY_MODEL:-opus}"
VERIFY_EFFORT="${PR_REVIEW_WATCH_VERIFY_EFFORT:-low}"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
. "$HERE/../pr-council-review/lib.sh"
. "$HERE/gates.sh"

finish() {
  local rc=$? attempt
  attempt="$(cut -f4 "$KEY.status" 2>/dev/null || echo 1)"
  [ "$MODE" = approve ] || printf '%s\t%s\t%s\t%s\n' "$SHA" "$MODE" "$rc" "${attempt:-1}" >"$KEY.status"
  rm -f "$KEY.pid"
  echo "=== exit $rc"
  [ "$rc" -eq 0 ] || notify "PR review failed ($MODE, $rc)" "$REPO#$NUMBER @${SHA:0:8}" "file://$REPORT"
}

my_review_count() {
  gh pr view "$NUMBER" --repo "$REPO" --json latestReviews \
    | jq --arg me "$ME" '[.latestReviews[] | select(.author.login == $me)] | length'
}

LINKED_FILE=""
linked_once() {
  local dir
  [ -z "$LINKED_FILE" ] || return 0
  purge_old_dirs "${TMPDIR:-/tmp}" "pr-linked-*" 7
  dir="$(mktemp -d "${TMPDIR:-/tmp}/pr-linked-$NUMBER.XXXXXX")" || return 0
  LINKED_FILE="$dir/section.md"
  linked_section "$REPO" "$NUMBER" "$dir" >"$LINKED_FILE"
}

verify_prompt() {
  render_template "$HERE/../pr-council-review/verify-prompt.md" VERIFY_SKILL="$VERIFY_SKILL_NAME" PR_NUMBER="$NUMBER" REPO="$REPO" SINCE_SHORT="${SINCE:0:8}" \
    LINKED_SECTION="$(cat "$LINKED_FILE" 2>/dev/null)"
}

keep_pending_approval() {
  echo "$SHA" >"$KEY.approval-pending"
  printf '%s' "$1" >"$KEY.approval-body"
}

post_approval() {
  local body="$1" url pending
  if ! url="$(gh api "repos/$REPO/pulls/$NUMBER/reviews" -f event=APPROVE -f commit_id="$SHA" -f body="$body" --jq .html_url)"; then
    pending="$(cat "$KEY.approval-pending" 2>/dev/null)"
    keep_pending_approval "$body"
    echo "=== approval pending: the approval POST failed (retried by the watcher without a new review)"
    [ "$pending" = "$SHA" ] || notify "PR approval pending" "$REPO#$NUMBER: the approval POST failed" "$URL"
    return 0
  fi
  rm -f "$KEY.approval-pending" "$KEY.approval-body"
  echo "=== approved: $url"
  notify "PR approved" "$REPO#$NUMBER @${SHA:0:8}" "$URL"
}

decide_and_approve() {
  local model_blocker="$1" body="$2" blocker
  if [ -n "$model_blocker" ]; then
    echo "=== not approved: $model_blocker"
    notify "PR not approved" "$REPO#$NUMBER: $model_blocker" "$URL"
    return 0
  fi
  blocker="$(objective_blocker)"
  if [ -n "$blocker" ]; then
    keep_pending_approval "$body"
    echo "=== approval pending: $blocker (retried by the watcher without a new review)"
    notify "PR approval pending" "$REPO#$NUMBER: $blocker" "$URL"
    return 0
  fi
  post_approval "$body"
}

run_shown() {
  local log="$1" rc
  shift
  { run_with_timeout "$TIMEOUT" "$@" </dev/null; echo "$?" >"$log.rc"; } 2>&1 | tee "$log" &
  wait "$!"
  rc="$(cat "$log.rc" 2>/dev/null || echo 1)"
  rm -f "$log.rc"
  return "$rc"
}

run_council() {
  local body findings
  run_shown "$REPORT" "$COUNCIL" "$NUMBER" "$REPO" --post || return
  findings="$(validator_run_findings "$REPORT" "$SHA")"
  [ -n "$findings" ] || { echo "=== no validator run marker for ${SHA:0:8}: the review is incomplete"; return "$REVIEW_INCOMPLETE_RC"; }
  echo "$SHA" >"$KEY.council-done"
  [ "$findings" = 0 ] || return 0
  echo "=== approval"
  body="$(validator_approval_body "$REPORT" "$SHA" 2>&1)" || { decide_and_approve "$body" ""; return 0; }
  echo "$SHA" >"$KEY.council-clean"
  echo "=== validator run marker reports 0 findings: PR recorded as clean at ${SHA:0:8}"
  decide_and_approve "" "$body"
}

run_delta() {
  local log="$1" rc
  linked_once
  run_with_timeout "$TIMEOUT" "$HERE/delta-review.sh" "$REPO" "$NUMBER" "$SINCE" "$LINKED_FILE" </dev/null >"$log" 2>&1
  rc=$?
  cat "$log"
  return "$rc"
}

verify_merge_base() {
  local base_ref
  base_ref="$(gh pr view "$NUMBER" --repo "$REPO" --json baseRefName --jq .baseRefName)" || return 1
  [ -n "$base_ref" ] || return 1
  git fetch -q origin "+refs/heads/$base_ref:refs/remotes/origin/$base_ref" || return 1
  git merge-base "refs/remotes/origin/$base_ref" "$SHA"
}

run_verify_fixes() {
  local tree raw rc base
  purge_old_dirs "${TMPDIR:-/tmp}" "pr-verify-*" 7
  tree="$(mktemp -d "${TMPDIR:-/tmp}/pr-verify-$NUMBER.XXXXXX")/tree"
  raw="${REPORT%.md}.json"
  base="$(verify_merge_base)" && [ -n "$base" ] || { echo "cannot resolve the merge base for the verify pass"; return 1; }
  linked_once
  git worktree add -q --detach "$tree" "$SHA" || { echo "cannot create verify worktree"; return 1; }
  neutralize_author_config "$tree" "$SHA" "$base"
  rc=0
  cd "$tree" || return 1
  claude_pass verify "$raw" read-only "$(verify_prompt)" \
    --model "$VERIFY_MODEL" --effort "$VERIFY_EFFORT" "${ISOLATED_SETTINGS[@]}" >"$REPORT" || rc=$?
  cd "$OLDPWD" || return 1
  cat "$REPORT"
  git worktree remove --force "$tree" >/dev/null 2>&1
  return "$rc"
}

# 0: the head extends the council's sha or carries the same changes; 1: a
# force-push replaced them; 2: the history could not be read.
council_in_history() {
  local council base_ref
  council="$(cat "$KEY.council-done" 2>/dev/null)"
  base_ref="$(gh pr view "$NUMBER" --repo "$REPO" --json baseRefName --jq .baseRefName)" && [ -n "$base_ref" ] || return 2
  git fetch -q origin "+refs/pull/$NUMBER/head:refs/remotes/origin/pr/$NUMBER" \
    "+refs/heads/$base_ref:refs/remotes/origin/$base_ref" || return 2
  git merge-base --is-ancestor "$council" "$SHA" 2>/dev/null && return 0
  same_patch "refs/remotes/origin/$base_ref" "$council" "$SHA" 2>/dev/null && return 0
  return 1
}

run_verify() {
  local delta_log="${REPORT%.md}-delta.md" delta_findings reviewed history=0
  rm -f "$KEY.verify-unconfigured"
  council_in_history || history=$?
  case "$history" in
    0) ;;
    1)
      echo "=== the council at $(cut -c1-8 "$KEY.council-done") is not in the head's history: full council again"
      rm -f "$KEY".{council-done,council-clean,watermark,delta-done}
      run_council
      return ;;
    *) echo "=== cannot check the head's history against the council"; return 1 ;;
  esac
  if [ "$(head -1 "$KEY.delta-done" 2>/dev/null)" = "$SHA" ]; then
    echo "=== step 1: skipped, the commits since ${SINCE:0:8} were already reviewed for ${SHA:0:8}"
    tail -n +2 "$KEY.delta-done" >"$delta_log"
  else
    echo "=== step 1: /code-review on the commits since ${SINCE:0:8}, findings posted"
    run_delta "$delta_log" || return
    grep -q '^=== nothing new since' "$delta_log" && printf 'DELTA_FINDINGS 0\nDELTA_CONFIDENT value=true\n' >>"$delta_log"
    { echo "$SHA"; grep -E '^DELTA_(FINDINGS|CONFIDENT) ' "$delta_log"; } >"$KEY.delta-done"
  fi
  delta_findings="$(sed -n 's/^DELTA_FINDINGS \([0-9]*\).*/\1/p' "$delta_log" | tail -1)"

  if [ -f "$KEY.council-clean" ] && [ "$(my_review_count)" = 0 ]; then
    echo "=== step 2: skipped, the full review found nothing to verify"
    echo "$SHA" >"$KEY.watermark"
    decide_and_approve "$(clean_blocker "$delta_log" "$delta_findings")" \
      "Approved: the full review at $(cut -c1-8 "$KEY.council-clean") found nothing, and the commits since add no finding."
    return
  fi

  VERIFY_SKILL_NAME="$(verify_skill)" || {
    echo "$SHA" >"$KEY.verify-unconfigured"
    echo "=== step 2: verify: unconfigured (set PR_COUNCIL_VERIFY_SKILL or ~/.config/pr-council-review/verify-skill); no watermark, ${SHA:0:8} stays due"
    return "$VERIFY_UNCONFIGURED_RC"
  }
  echo "=== step 2: verify-fixes"
  run_verify_fixes || return
  echo "$SHA" >"$KEY.watermark"
  echo "=== step 3: approval"
  grep -E '^CONFIDENCE ' "$REPORT" | tail -1
  reviewed="$(field "$REPORT" VERIFY_VERDICT reviewed)"
  decide_and_approve "$(verify_blocker "$REPORT" "$delta_findings")" \
    "Approved after /verify-fixes: ${reviewed:-0} findings closed or accepted, none reopened, no new finding since ${SINCE:0:8}."
}

run_pending_approval() {
  local pending_sha blocker
  pending_sha="$(cat "$KEY.approval-pending" 2>/dev/null)"
  [ -f "$KEY.approval-body" ] || { rm -f "$KEY.approval-pending"; echo "=== pending approval has no body, dropped"; return 0; }
  [ "$pending_sha" = "$SHA" ] || { rm -f "$KEY.approval-pending" "$KEY.approval-body"; echo "=== pending approval was for ${pending_sha:0:8}, dropped"; return 0; }
  CI_WAIT_SECONDS=0
  blocker="$(objective_blocker)"
  [ -z "$blocker" ] || { echo "=== approval still pending: $blocker"; return 0; }
  post_approval "$(cat "$KEY.approval-body")"
}

[ -f "${PR_REVIEW_WATCH_STATE_DIR:-$HOME/.claude/state/pr-review-watch}/off" ] && { echo "kill switch is on"; exit 0; }
echo $$ >"$KEY.pid"
trap finish EXIT
trap 'stop_children; exit 130' INT
trap 'stop_children; exit 143' TERM
trap 'stop_children; exit 129' HUP
USAGE_TARGET="$REPO#$NUMBER"
ME="$(gh api user --jq .login)" || exit 1
echo "=== $MODE $REPO#$NUMBER @${SHA:0:8} — $URL"
case "$MODE" in
  council) run_council ;;
  verify) run_verify ;;
  approve) run_pending_approval ;;
  *) echo "unknown mode $MODE" >&2; exit 2 ;;
esac
