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

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
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

run_with_timeout() {
  perl -e 'setpgrp(0, 0); exec @ARGV or die "exec: $!"' "$@" &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$TIMEOUT" ]; then
      echo "=== timeout after ${TIMEOUT}s, killing process group $pid"
      kill -TERM -- "-$pid" 2>/dev/null
      sleep 5
      kill -KILL -- "-$pid" 2>/dev/null
      return 124
    fi
    sleep 10
    waited=$((waited + 10))
  done
  wait "$pid"
}

claude_bin() {
  [ -r "$HOME/.claude/scripts/claude-bin.sh" ] && . "$HOME/.claude/scripts/claude-bin.sh"
  printf '%s' "${PR_REVIEW_WATCH_CLAUDE:-${CLAUDE:-}}"
}

my_review_count() {
  gh pr view "$NUMBER" --repo "$REPO" --json latestReviews \
    | jq --arg me "$ME" '[.latestReviews[] | select(.author.login == $me)] | length'
}

verify_prompt() {
  render_template "$HERE/../pr-council-review/verify-prompt.md" PR_NUMBER="$NUMBER" REPO="$REPO" SINCE_SHORT="${SINCE:0:8}"
}

post_approval() {
  local body="$1" url
  url="$(gh api "repos/$REPO/pulls/$NUMBER/reviews" -f event=APPROVE -f commit_id="$SHA" -f body="$body" --jq .html_url)" \
    || { echo "=== approval POST failed"; return 1; }
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
    echo "$SHA" >"$KEY.approval-pending"
    printf '%s' "$body" >"$KEY.approval-body"
    echo "=== approval pending: $blocker (retried by the watcher without a new review)"
    notify "PR approval pending" "$REPO#$NUMBER: $blocker" "$URL"
    return 0
  fi
  post_approval "$body"
}

run_council() {
  local body
  run_with_timeout "$COUNCIL" "$NUMBER" "$REPO" --post </dev/null 2>&1 | tee "$REPORT"
  [ "${PIPESTATUS[0]}" -eq 0 ] || return 1
  echo "$SHA" >"$KEY.council-done"
  [ "$(validator_run_findings "$REPORT" "$SHA")" = 0 ] || return 0
  echo "$SHA" >"$KEY.council-clean"
  echo "=== validator run marker reports 0 findings: PR recorded as clean at ${SHA:0:8}"
  echo "=== approval"
  body="$(validator_approval_body "$REPORT" "$SHA" 2>&1)" || { decide_and_approve "$body" ""; return 0; }
  decide_and_approve "" "$body"
}

run_delta() {
  local log="$1" rc
  run_with_timeout "$HERE/delta-review.sh" "$REPO" "$NUMBER" "$SINCE" </dev/null >"$log" 2>&1
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
  local claude tree raw rc base
  claude="$(claude_bin)"
  [ -n "$claude" ] || { echo "claude binary not found"; return 1; }
  tree="$(mktemp -d "${TMPDIR:-/tmp}/pr-verify-$NUMBER.XXXXXX")/tree"
  raw="${REPORT%.md}.json"
  base="$(verify_merge_base)" && [ -n "$base" ] || { echo "cannot resolve the merge base for the verify pass"; return 1; }
  git worktree add -q --detach "$tree" "$SHA" || { echo "cannot create verify worktree"; return 1; }
  neutralize_author_config "$tree" "$SHA" "$base"
  (cd "$tree" && run_with_timeout "$claude" -p --dangerously-skip-permissions --output-format json \
    --model "$VERIFY_MODEL" --effort "$VERIFY_EFFORT" --settings '{"disableAllHooks":true}' \
    --strict-mcp-config --setting-sources project,local "$(verify_prompt)" </dev/null) >"$raw" 2>"$raw.err"
  rc=$?
  git worktree remove --force "$tree" >/dev/null 2>&1
  extract_result "$raw" | tee "$REPORT"
  [ "${PIPESTATUS[0]}" -eq 0 ] || rc=1
  record_usage "$raw" "verify" "$REPO#$NUMBER"
  return "$rc"
}

run_verify() {
  local delta_log="${REPORT%.md}-delta.md" delta_findings reviewed
  echo "=== step 1: /code-review on the commits since ${SINCE:0:8}, findings posted"
  run_delta "$delta_log" || return 1
  delta_findings="$(sed -n 's/^DELTA_FINDINGS \([0-9]*\).*/\1/p' "$delta_log" | tail -1)"
  grep -q '^=== nothing new since' "$delta_log" && { delta_findings=0; echo "DELTA_CONFIDENT value=true" >>"$delta_log"; }

  if [ -f "$KEY.council-clean" ] && [ "$(my_review_count)" = 0 ]; then
    echo "=== step 2: skipped, the full review found nothing to verify"
    echo "$SHA" >"$KEY.watermark"
    decide_and_approve "$(clean_blocker "$delta_log" "$delta_findings")" \
      "Approved: the full review at $(cut -c1-8 "$KEY.council-clean") found nothing, and the commits since add no finding."
    return
  fi

  echo "=== step 2: verify-fixes"
  run_verify_fixes || return 1
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
trap 'exit 143' TERM INT
ME="$(gh api user --jq .login)" || exit 1
echo "=== $MODE $REPO#$NUMBER @${SHA:0:8} — $URL"
case "$MODE" in
  council) run_council ;;
  verify) run_verify ;;
  approve) run_pending_approval ;;
  *) echo "unknown mode $MODE" >&2; exit 2 ;;
esac
