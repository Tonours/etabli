#!/bin/bash
set -uo pipefail
umask 077

MODE="${1:?usage: review-run.sh <council|verify|approve> <owner/repo> <number> <sha> <since> <url> <report> <state-key>}"
REPO="${2:?}"
NUMBER="${3:?}"
SHA="${4:?}"
SINCE="${5:?}"
URL="${6:?}"
REPORT="${7:?}"
KEY="${8:?}"
HERE="$(cd "$(dirname "$0")" && pwd)"
canonical_key="$(cd "$(dirname "$KEY")" && pwd -P)/${KEY##*/}" || exit 1
if [ "$KEY" != "$canonical_key" ]; then exec "$HERE/review-run.sh" "$MODE" "$REPO" "$NUMBER" "$SHA" "$SINCE" "$URL" "$REPORT" "$canonical_key"; fi
COUNCIL="${PR_REVIEW_WATCH_COUNCIL:-$HOME/.claude/scripts/pr-council-review/run.sh}"
TIMEOUT="${PR_REVIEW_WATCH_TIMEOUT:-2700}"
VERIFY_MODEL="${PR_REVIEW_WATCH_VERIFY_MODEL:-opus}"
VERIFY_EFFORT="${PR_REVIEW_WATCH_VERIFY_EFFORT:-low}"

# Preserve the eight-argument CLI; only the immediate supervised child may enter.
if [ "${PR_REVIEW_WATCH_SUPERVISOR:-}" != "$PPID" ] || [ "${PR_REVIEW_WATCH_RUN_KEY:-}" != "$KEY" ] \
  || [ "$(cat "$KEY.execution/pid" 2>/dev/null)" != "$PPID" ] \
  || [ "${PR_REVIEW_WATCH_RUN_TOKEN:-}" != "$(cat "$KEY.execution/token" 2>/dev/null)" ]; then
  attempt=1
  IFS=$'\t' read -r status_sha status_mode status_rc status_attempt <"$KEY.status" 2>/dev/null || true
  if [ "${status_sha:-}" = "$SHA" ] && [[ "${status_attempt:-}" =~ ^[1-9][0-9]*$ ]]; then attempt="$status_attempt"; fi
  exec "$HERE/launch-run.sh" "$KEY" - "$MODE" "$SHA" "$attempt" "$HERE/review-run.sh" "$@"
fi

# Advertise the child too: a killed supervisor must not hide a live runner.
printf '%s\n' "$$" >"$KEY.pid"
finish() {
  local rc=$?
  echo "=== exit $rc"
  if [ "$rc" -ne 0 ] && declare -F notify >/dev/null; then
    notify "PR review failed ($MODE, $rc)" "$REPO#$NUMBER @${SHA:0:8}" "file://$REPORT"
  fi
}
trap finish EXIT
trap 'declare -F stop_children >/dev/null && stop_children; exit 130' INT
trap 'declare -F stop_children >/dev/null && stop_children; exit 143' TERM
trap 'declare -F stop_children >/dev/null && stop_children; exit 129' HUP
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
. "$HERE/../pr-council-review/lib.sh" || exit 1
. "$HERE/gates.sh" || exit 1

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
  local body="$1" url pending actor registered_sha registered_actor reviews response status
  actor="$(gh api user --jq .login)" || actor=''
  actor="$(printf '%s' "$actor" | tr '[:upper:]' '[:lower:]')"
  registered_actor="$(printf '%s' "$ME" | tr '[:upper:]' '[:lower:]')"
  if [ -f "$KEY.registered" ]; then
    IFS=$'\t' read -r registered_sha registered_actor <"$KEY.registered" || registered_actor=''
  fi
  if [ -z "$actor" ] || [ "$actor" != "$registered_actor" ]; then
    keep_pending_approval "$body"
    echo '=== approval pending: authenticated account changed or unavailable'
    return 0
  fi
  reviews="$(gh api --paginate "repos/$REPO/pulls/$NUMBER/reviews")" || {
    keep_pending_approval "$body"
    echo '=== approval pending: review history unavailable'
    return 0
  }
  url="$(printf '%s' "$reviews" | jq -csr --arg me "$actor" --arg sha "$SHA" '
    [.[][] | select((.user.login|ascii_downcase) == $me)
      | select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "DISMISSED")]
    | max_by(.id) // {} | select(.state == "APPROVED" and .commit_id == $sha) | .html_url // "confirmed"')" || {
    keep_pending_approval "$body"; echo '=== approval pending: unreadable review history'; return 0
  }
  if [ -n "$url" ]; then
    rm -f "$KEY.approval-pending" "$KEY.approval-body"
    echo "=== approved: $url (already confirmed on this head)"
    return 0
  fi
  if ! response="$(gh api --include "repos/$REPO/pulls/$NUMBER/reviews" -f event=APPROVE -f commit_id="$SHA" -f body="$body")"; then
    status="$(printf '%s\n' "$response" | sed -n 's/^HTTP\/[^ ]* \([0-9][0-9][0-9]\).*/\1/p' | tail -1)"
    case "$status" in
      400|401|403|404|405|410|422)
        # A rate-limit response is retryable; other deterministic 4xx refusals
        # cannot become approvals by posting the same proof every minute.
        if ! printf '%s\n' "$response" | grep -qiE '^(retry-after:|x-ratelimit-remaining: 0)|rate limit'; then
          rm -f "$KEY.approval-pending" "$KEY.approval-body"
          echo "=== approval terminal: GitHub refused HTTP $status; no automatic retry"
          notify 'PR approval refused' "$REPO#$NUMBER: HTTP $status" "$URL"
          return 0
        fi ;;
    esac
    response=''
  fi
  url="$(printf '%s\n' "$response" | awk 'body {print} /^\r?$/ {body=1}' | jq -er '.html_url | select(type == "string" and startswith("https://"))' 2>/dev/null)" || url=''
  if [ -z "$url" ]; then
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

council_report_path() {
  printf '%s/%s-%s-%s-council.md' "$(dirname "$REPORT")" "${REPO//\//_}" "$NUMBER" "${1:0:8}"
}

council_state_complete() {
  local council findings actor_sha actor
  IFS=$'\t' read -r actor_sha actor <"$KEY.registered" 2>/dev/null || return 1
  [ "$actor" = "$(printf '%s' "$ME" | tr '[:upper:]' '[:lower:]')" ] || return 1
  council="$(cat "$KEY.council-done" 2>/dev/null)" && [ -n "$council" ] || return 1
  findings="$(validator_run_findings "$(council_report_path "$council")" "$council")" || return 1
  if [ -f "$KEY.council-clean" ]; then
    [ "$findings" = 0 ] && [ "$(cat "$KEY.council-clean")" = "$council" ] || return 1
  fi
}

run_council() {
  local body findings
  REPORT="$(council_report_path "$SHA")"
  rm -f "$KEY.council-done" "$KEY.council-clean" || return "$REVIEW_INCOMPLETE_RC"
  run_shown "$REPORT" "$COUNCIL" "$NUMBER" "$REPO" --post --no-watch-register || return
  if grep -q '^=== council degraded:' "$REPORT"; then
    echo '=== incomplete council: a required independent pass did not complete'
    return "$REVIEW_INCOMPLETE_RC"
  fi
  findings="$(validator_run_findings "$REPORT" "$SHA" 2>>"$REPORT")"
  [ -n "$findings" ] || {
    rm -f "$KEY.council-done" "$KEY.council-clean"
    echo "=== no complete validator run marker for ${SHA:0:8} (pending, ticketed, malformed or missing): the review is incomplete" | tee -a "$REPORT"
    return "$REVIEW_INCOMPLETE_RC"
  }
  echo "$SHA" >"$KEY.council-done"
  printf '%s\t%s\n' "$SHA" "$(printf '%s' "$ME" | tr '[:upper:]' '[:lower:]')" >"$KEY.registered"
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
  run_with_timeout "$TIMEOUT" "$HERE/delta-review.sh" "$REPO" "$NUMBER" "$SINCE" "$LINKED_FILE" "$SHA" </dev/null >"$log" 2>&1
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
  if ! council_state_complete; then
    echo "=== stored council report missing, incomplete or inconsistent: full council again"
    rm -f "$KEY".{council-done,council-clean,watermark,delta-done} || return "$REVIEW_INCOMPLETE_RC"
    run_council
    return
  fi
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
  if [ "$(head -1 "$KEY.delta-done" 2>/dev/null)" = "$SHA" ] && grep -qxF "DELTA_HEAD $SHA" "$KEY.delta-done"; then
    echo "=== step 1: skipped, the commits since ${SINCE:0:8} were already reviewed for ${SHA:0:8}"
    tail -n +2 "$KEY.delta-done" >"$delta_log"
  else
    echo "=== step 1: /code-review on the commits since ${SINCE:0:8}, findings posted"
    run_delta "$delta_log" || return
    { echo "$SHA"; grep -E '^DELTA_(HEAD|FINDINGS|CONFIDENT) ' "$delta_log"; } >"$KEY.delta-done"
  fi
  delta_findings="$(sed -n 's/^DELTA_FINDINGS \([0-9]*\).*/\1/p' "$delta_log" | tail -1)"

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
  decide_and_approve "$(verify_blocker "$REPORT" "$delta_findings" "$delta_log")" \
    "Approved after /verify-fixes: ${reviewed:-0} findings closed or accepted, none reopened, no new finding since ${SINCE:0:8}."
}

run_pending_approval() {
  local pending_sha blocker
  pending_sha="$(cat "$KEY.approval-pending" 2>/dev/null)"
  [ -f "$KEY.approval-body" ] || { rm -f "$KEY.approval-pending"; echo "=== pending approval has no body, dropped"; return 0; }
  [ "$pending_sha" = "$SHA" ] || { rm -f "$KEY.approval-pending" "$KEY.approval-body"; echo "=== pending approval was for ${pending_sha:0:8}, dropped"; return 0; }
  if ! council_state_complete; then
    rm -f "$KEY".{council-done,council-clean,watermark,delta-done,approval-pending,approval-body,status} || return "$REVIEW_INCOMPLETE_RC"
    echo "=== approval deferred: stored council report invalid; queued for a normal council next tick"
    return 0
  fi
  CI_WAIT_SECONDS=0
  blocker="$(objective_blocker)"
  [ -z "$blocker" ] || { echo "=== approval still pending: $blocker"; return 0; }
  post_approval "$(cat "$KEY.approval-body")"
}

if [ -f "${PR_REVIEW_WATCH_STATE_DIR:-$HOME/.claude/state/pr-review-watch}/off" ]; then
  if [ "$MODE" != approve ]; then
    printf '%s\t%s\n' "$SHA" "$(cut -f4 "$KEY.status")" >"$KEY.paused"
  fi
  exit 75
fi
USAGE_TARGET="$REPO#$NUMBER@$SHA"
ME="$(gh api user --jq .login)" || exit 1
echo "=== $MODE $REPO#$NUMBER @${SHA:0:8} — $URL"
case "$MODE" in
  council) run_council ;;
  verify) run_verify ;;
  approve) run_pending_approval ;;
  *) echo "unknown mode $MODE" >&2; exit 2 ;;
esac
