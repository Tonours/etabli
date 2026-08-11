#!/bin/bash
set -uo pipefail

REPO="${1:?usage: run.sh <repo> <branch> <sha> <worktree>}"
BRANCH="${2:?}"
SHA="${3:?}"
WORKTREE="${4:?}"

STATE_DIR="$HOME/.claude/state"
LOG="$HOME/.claude/logs/pr-autoreview.log"
SEEN="$STATE_DIR/pr-autoreview-seen"
KILL_SWITCH="$STATE_DIR/pr-autoreview.off"
PROFILE_DIR="$HOME/.claude/scripts/pr-autoreview/profiles"
TIMEOUT="${PR_AUTOREVIEW_TIMEOUT:-900}"

mkdir -p "$STATE_DIR" "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "=== $(date '+%F %T') push $REPO/$BRANCH @${SHA:0:8} ==="

[ -f "$KILL_SWITCH" ] && { echo "kill switch present, skip"; exit 0; }

GH="$(command -v gh || echo /opt/homebrew/bin/gh)"
[ -x "$GH" ] || { echo "gh not found, skip"; exit 0; }

PR_LINE="$("$GH" pr list --repo "ForestAdmin/$REPO" --head "$BRANCH" --state open \
  --json number,author,url,createdAt,reviews --limit 1 \
  --jq '.[0] | [.number, .author.login, .url, .createdAt, ([.reviews[].author.login] | unique | join(","))] | @tsv' 2>/dev/null)"

[ -n "$PR_LINE" ] || { echo "no open PR for $BRANCH, skip"; exit 0; }
IFS=$'\t' read -r PR_NUMBER PR_AUTHOR PR_URL PR_CREATED PR_REVIEWERS <<< "$PR_LINE"

[ -n "${PR_NUMBER:-}" ] || { echo "cannot parse PR, skip"; exit 0; }
[ "$PR_AUTHOR" = "Tonours" ] || { echo "PR #$PR_NUMBER not authored by Tonours ($PR_AUTHOR), skip"; exit 0; }

PR_AGE_DAYS=$(( ( $(date +%s) - $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$PR_CREATED" +%s 2>/dev/null || echo 0) ) / 86400 ))
if [ "$PR_AGE_DAYS" -gt 30 ]; then
  echo "PR #$PR_NUMBER is $PR_AGE_DAYS days old (>30), skip"
  exit 0
fi

HUMAN_REVIEWERS=$(printf '%s' "${PR_REVIEWERS:-}" | tr ',' '\n' | grep -v '^Tonours$' | grep -v '^$' | tr '\n' ' ')
[ -n "$HUMAN_REVIEWERS" ] && echo "human reviewers present:$HUMAN_REVIEWERS (report-only mode enforced by prompt)"

SEEN_KEY="$REPO#$PR_NUMBER@$SHA"
if [ -f "$SEEN" ] && grep -qxF "$SEEN_KEY" "$SEEN" 2>/dev/null; then
  echo "already reviewed $SEEN_KEY, skip"
  exit 0
fi

PROFILE="$PROFILE_DIR/$REPO.md"
[ -f "$PROFILE" ] || { echo "no review profile for $REPO, skip"; exit 0; }

PROMPT_FILE="$HOME/.claude/scripts/pr-autoreview/prompt.md"
[ -f "$PROMPT_FILE" ] || { echo "prompt missing, skip"; exit 0; }

CLAUDE=""
[ -r "$HOME/.claude/scripts/claude-bin.sh" ] && . "$HOME/.claude/scripts/claude-bin.sh"
[ -n "$CLAUDE" ] || { echo "claude binary not found"; exit 1; }

echo "reviewing PR #$PR_NUMBER ($PR_URL) at ${SHA:0:8}"

PROMPT="$(sed \
  -e "s|{{REPO}}|ForestAdmin/$REPO|g" \
  -e "s|{{PR_NUMBER}}|$PR_NUMBER|g" \
  -e "s|{{PR_URL}}|$PR_URL|g" \
  -e "s|{{HEAD_SHA}}|$SHA|g" \
  -e "s|{{PROFILE_PATH}}|$PROFILE|g" \
  -e "s|{{WORKTREE}}|$WORKTREE|g" \
  "$PROMPT_FILE")"

cd "$HOME"
"$CLAUDE" -p "$PROMPT" --dangerously-skip-permissions </dev/null &
AGENT_PID=$!

WAITED=0
RC=0
while kill -0 "$AGENT_PID" 2>/dev/null; do
  if [ "$WAITED" -ge "$TIMEOUT" ]; then
    echo "TIMEOUT after ${WAITED}s, killing agent $AGENT_PID"
    pkill -KILL -P "$AGENT_PID" 2>/dev/null
    kill -KILL "$AGENT_PID" 2>/dev/null
    RC=124
    break
  fi
  sleep 15
  WAITED=$((WAITED + 15))
done
[ "$RC" -eq 0 ] && { wait "$AGENT_PID" || RC=$?; }

if [ "$RC" -eq 0 ]; then
  echo "$SEEN_KEY" >> "$SEEN"
  echo "=== $(date '+%F %T') done PR #$PR_NUMBER ==="
else
  echo "=== $(date '+%F %T') agent exited $RC for PR #$PR_NUMBER ==="
fi
exit 0
