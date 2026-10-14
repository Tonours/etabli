#!/bin/bash
set -uo pipefail

REPO="${1:?usage: delta-review.sh <owner/repo> <number> <since-sha>}"
NUMBER="${2:?}"
SINCE="${3:?}"
MODEL="${PR_REVIEW_WATCH_DELTA_MODEL:-sonnet}"
LEVEL="${PR_REVIEW_WATCH_DELTA_LEVEL:-medium}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PROMPT_FILE="$HERE/delta-prompt.md"
. "$HERE/../pr-council-review/lib.sh"

[ -r "$HOME/.claude/scripts/claude-bin.sh" ] && . "$HOME/.claude/scripts/claude-bin.sh"
CLAUDE="${PR_REVIEW_WATCH_CLAUDE:-${CLAUDE:-}}"
[ -n "$CLAUDE" ] || { echo "claude binary not found" >&2; exit 1; }

META="$(gh pr view "$NUMBER" --repo "$REPO" --json headRefOid,baseRefName,url \
  --jq '[.headRefOid, .baseRefName, .url] | @tsv')" || { echo "cannot read $REPO#$NUMBER" >&2; exit 1; }
IFS=$'\t' read -r HEAD_SHA BASE_REF PR_URL <<<"$META"

git worktree prune
git fetch -q origin "+refs/pull/$NUMBER/head:refs/remotes/origin/pr/$NUMBER" \
  "+refs/heads/$BASE_REF:refs/remotes/origin/$BASE_REF" || { echo "cannot fetch $REPO#$NUMBER" >&2; exit 1; }
if ! git cat-file -e "$SINCE^{commit}" 2>/dev/null || ! git merge-base --is-ancestor "$SINCE" "$HEAD_SHA"; then
  echo "=== ${SINCE:0:8} is not an ancestor of the head (rebase, force-push or no prior review): reviewing the whole PR diff"
  SINCE="$(git merge-base "refs/remotes/origin/$BASE_REF" "$HEAD_SHA")" || { echo "no merge base" >&2; exit 1; }
fi
MERGE_BASE="$(git merge-base "refs/remotes/origin/$BASE_REF" "$HEAD_SHA")" || { echo "no merge base" >&2; exit 1; }
[ "$SINCE" != "$HEAD_SHA" ] || { echo "=== nothing new since ${SINCE:0:8}"; exit 0; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-delta-$NUMBER.XXXXXX")"
WORKTREE="$WORK_DIR/tree"
trap 'git worktree remove --force "$WORKTREE" >/dev/null 2>&1' EXIT
git worktree add -q --detach "$WORKTREE" "$HEAD_SHA" || { echo "cannot create worktree" >&2; exit 1; }
git -C "$WORKTREE" reset -q --soft "$SINCE" || { echo "cannot stage the delta" >&2; exit 1; }
neutralize_author_config "$WORKTREE" "$SINCE" "$MERGE_BASE"

echo "=== delta ${SINCE:0:8}..${HEAD_SHA:0:8}: $(git -C "$WORKTREE" diff --cached --shortstat)"
PROMPT="$(render_template "$PROMPT_FILE" REPO="$REPO" PR_NUMBER="$NUMBER" PR_URL="$PR_URL" \
  SINCE_SHA="$SINCE" HEAD_SHA="$HEAD_SHA" SINCE_SHORT="${SINCE:0:8}" HEAD_SHORT="${HEAD_SHA:0:8}" REVIEW_LEVEL="$LEVEL")"

RAW="$WORK_DIR/delta.json"
(cd "$WORKTREE" && "$CLAUDE" -p "$PROMPT" --dangerously-skip-permissions --output-format json \
  --model "$MODEL" --settings '{"disableAllHooks":true}' --strict-mcp-config \
  --setting-sources project,local </dev/null) >"$RAW" 2>"$RAW.err"
RC=$?
extract_result "$RAW" || RC=1
record_usage "$RAW" "delta" "$REPO#$NUMBER"
exit "$RC"
