#!/bin/bash
set -uo pipefail

REPO="${1:?usage: run.sh <owner/repo> <profile> <branch> <sha> <worktree>}"
PROFILE_NAME="${2:?}"
BRANCH="${3:?}"
SHA="${4:?}"
WORKTREE="${5:?}"

HERE="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="$HOME/.claude/state"
LOG="$HOME/.claude/logs/pr-autoreview.log"
SEEN="$STATE_DIR/pr-autoreview-seen"
KILL_SWITCH="$STATE_DIR/pr-autoreview.off"
LOCKS="$STATE_DIR/pr-autoreview-locks"
PROFILE_DIR="$HERE/profiles"
TIMEOUT="${PR_AUTOREVIEW_TIMEOUT:-900}"
HEAD_WAIT="${PR_AUTOREVIEW_HEAD_WAIT:-180}"
MODEL="${PR_AUTOREVIEW_MODEL:-sonnet}"
EFFORT="${PR_AUTOREVIEW_EFFORT:-low}"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
. "$HERE/../pr-council-review/lib.sh"

mkdir -p "$STATE_DIR" "$LOCKS" "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "=== $(date '+%F %T') push $REPO/$BRANCH @${SHA:0:8} ==="

[ -f "$KILL_SWITCH" ] && { echo "kill switch present, skip"; exit 0; }
command -v gh >/dev/null || { echo "gh not found, skip"; exit 0; }

ME="$(gh api user --jq .login 2>&1)" || { echo "gh failed: $ME"; exit 0; }

pr_line() {
  gh pr list --repo "$REPO" --head "$BRANCH" --state open \
    --json number,author,url,createdAt,reviews,headRefOid --limit 1 \
    --jq '.[0] // empty | [.number, .author.login, .url, (((now - (.createdAt | fromdateiso8601)) / 86400) | floor), .headRefOid, ([.reviews[].author.login] | unique | join(","))] | @tsv'
}

WAITED=0
while :; do
  PR_LINE="$(pr_line 2>&1)" || { echo "gh pr list failed: $PR_LINE"; exit 0; }
  [ -n "$PR_LINE" ] || { echo "no open PR for $BRANCH, skip"; exit 0; }
  IFS=$'\t' read -r PR_NUMBER PR_AUTHOR PR_URL PR_AGE_DAYS PR_HEAD PR_REVIEWERS <<< "$PR_LINE"
  [ "$PR_HEAD" = "$SHA" ] && break
  [ "$WAITED" -lt "$HEAD_WAIT" ] || { echo "PR head is ${PR_HEAD:0:8}, push of ${SHA:0:8} never landed, skip"; exit 0; }
  sleep 15
  WAITED=$((WAITED + 15))
done

[ -n "${PR_NUMBER:-}" ] || { echo "cannot parse PR, skip"; exit 0; }
[ "$PR_AUTHOR" = "$ME" ] || { echo "PR #$PR_NUMBER not authored by $ME ($PR_AUTHOR), skip"; exit 0; }

[ "$PR_AGE_DAYS" -le 30 ] || { echo "PR #$PR_NUMBER is $PR_AGE_DAYS days old (>30), skip"; exit 0; }

HUMAN_REVIEWERS=$(printf '%s' "${PR_REVIEWERS:-}" | tr ',' '\n' | grep -vxF "$ME" | grep -v '^$' | paste -sd ' ' -)
[ -n "$HUMAN_REVIEWERS" ] && echo "human reviewers present: $HUMAN_REVIEWERS"

LOCK="$LOCKS/${REPO//\//_}_$PR_NUMBER"
WAITED=0
until acquire_lock "$LOCK" 'pr-autoreview/run\.sh'; do
  [ "$WAITED" -lt "$TIMEOUT" ] || { echo "another review of #$PR_NUMBER still holds the lock, skip"; exit 0; }
  sleep 15
  WAITED=$((WAITED + 15))
done
trap 'rm -rf "$LOCK"' EXIT

SEEN_KEY="$REPO#$PR_NUMBER@$SHA"
if [ -f "$SEEN" ] && grep -qxF "$SEEN_KEY" "$SEEN" 2>/dev/null; then
  echo "already reviewed $SEEN_KEY, skip"
  exit 0
fi
CURRENT_HEAD=""
for attempt in 1 2 3; do
  CURRENT_HEAD="$(gh pr view "$PR_NUMBER" --repo "$REPO" --json headRefOid --jq .headRefOid 2>/dev/null)" && [ -n "$CURRENT_HEAD" ] && break
  CURRENT_HEAD=""
  [ "$attempt" -lt 3 ] && sleep 10
done
[ -n "$CURRENT_HEAD" ] || { echo "cannot read the head of #$PR_NUMBER"; exit 1; }
if [ "$CURRENT_HEAD" != "$SHA" ]; then
  echo "a newer push superseded ${SHA:0:8}, skip"
  exit 0
fi

PROFILE="$PROFILE_DIR/$PROFILE_NAME.md"
[ -f "$PROFILE" ] || { echo "no review profile $PROFILE_NAME.md for $REPO, skip"; exit 0; }
PROMPT_FILE="$HERE/prompt.md"
[ -f "$PROMPT_FILE" ] || { echo "prompt missing, skip"; exit 0; }

[ -n "$CLAUDE" ] || { echo "claude binary not found"; exit 1; }

purge_old_dirs "${TMPDIR:-/tmp}" "pr-autoreview-*" 7
RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-autoreview-$PR_NUMBER.XXXXXX")"
DONE_FILE="$RUN_DIR/delivered"
RAW="$RUN_DIR/session.json"
PROMPT="$(render_template "$PROMPT_FILE" REPO="$REPO" PR_NUMBER="$PR_NUMBER" PR_URL="$PR_URL" HEAD_SHA="$SHA" \
  PROFILE_PATH="$PROFILE" WORKTREE="$WORKTREE" DONE_FILE="$DONE_FILE" HUMAN_REVIEWERS="${HUMAN_REVIEWERS:-none}")"

echo "reviewing PR #$PR_NUMBER ($PR_URL) at ${SHA:0:8} with $MODEL"
cd "$HOME"
CLAUDE_PASS_TIMEOUT="$TIMEOUT"
USAGE_TARGET="$REPO#$PR_NUMBER"
RC=0
claude_pass autoreview "$RAW" read-only "$PROMPT" --model "$MODEL" --effort "$EFFORT" >"$RUN_DIR/result.md" || RC=$?

if [ "$RC" -eq 0 ] && [ -f "$DONE_FILE" ]; then
  echo "$SEEN_KEY" >> "$SEEN"
  echo "=== $(date '+%F %T') delivered PR #$PR_NUMBER ==="
  exit 0
fi
if [ "$RC" -eq "$REVIEW_VETO_RC" ]; then
  FAILURE="hit a permission denial"
elif [ "$RC" -eq 0 ]; then
  FAILURE="ended without delivering the Slack report"
else
  FAILURE="exited $RC"
fi
echo "=== $(date '+%F %T') PR #$PR_NUMBER autoreview $FAILURE, not marked seen ==="
notify "PR autoreview failed" "$REPO#$PR_NUMBER: $FAILURE" "$PR_URL"
exit 1
