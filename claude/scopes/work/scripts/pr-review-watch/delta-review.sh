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

USAGE_TARGET="$REPO#$NUMBER"
FINDINGS_SCHEMA='{"type":"object","additionalProperties":false,"required":["findings","confident"],"properties":{"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["path","line","body"],"properties":{"path":{"type":"string"},"line":{"type":"integer"},"body":{"type":"string"}}}},"confident":{"type":"boolean"}}}'

META="$(gh pr view "$NUMBER" --repo "$REPO" --json headRefOid,baseRefName,url \
  --jq '[.headRefOid, .baseRefName, .url] | @tsv')" || { echo "cannot read $REPO#$NUMBER" >&2; exit 1; }
IFS=$'\t' read -r HEAD_SHA BASE_REF PR_URL <<<"$META"

patch_id() { git diff --binary "$1" "$2" | git patch-id --verbatim | cut -d' ' -f1; }

# path:line for every line the PR adds or changes on the head; GitHub rejects a
# review whose comments sit elsewhere.
changed_lines() {
  git diff --unified=0 --no-color "$1" "$2" | awk '
    /^\+\+\+ / { path = substr($0, 7); next }
    /^@@ / { n = split(substr($3, 2), h, ","); count = n > 1 ? h[2] : 1; for (i = 0; i < count; i++) print path ":" (h[1] + i) }'
}

git worktree prune
git fetch -q origin "+refs/pull/$NUMBER/head:refs/remotes/origin/pr/$NUMBER" \
  "+refs/heads/$BASE_REF:refs/remotes/origin/$BASE_REF" || { echo "cannot fetch $REPO#$NUMBER" >&2; exit 1; }
MERGE_BASE="$(git merge-base "refs/remotes/origin/$BASE_REF" "$HEAD_SHA")" || { echo "no merge base" >&2; exit 1; }
if git cat-file -e "$SINCE^{commit}" 2>/dev/null && OLD_BASE="$(git merge-base "refs/remotes/origin/$BASE_REF" "$SINCE")" \
  && [ "$(patch_id "$OLD_BASE" "$SINCE")" = "$(patch_id "$MERGE_BASE" "$HEAD_SHA")" ]; then
  echo "=== nothing new since ${SINCE:0:8}: the head carries the same changes on a new base"
  exit 0
fi
if ! git cat-file -e "$SINCE^{commit}" 2>/dev/null || ! git merge-base --is-ancestor "$SINCE" "$HEAD_SHA"; then
  echo "=== ${SINCE:0:8} is not an ancestor of the head (rebase, force-push or no prior review): reviewing the whole PR diff"
  SINCE="$MERGE_BASE"
fi
[ "$SINCE" != "$HEAD_SHA" ] || { echo "=== nothing new since ${SINCE:0:8}"; exit 0; }

purge_old_dirs "${TMPDIR:-/tmp}" "pr-delta-*" 7
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-delta-$NUMBER.XXXXXX")"
WORKTREE="$WORK_DIR/tree"
trap 'git worktree remove --force "$WORKTREE" >/dev/null 2>&1' EXIT
git worktree add -q --detach "$WORKTREE" "$HEAD_SHA" || { echo "cannot create worktree" >&2; exit 1; }
git -C "$WORKTREE" reset -q --soft "$SINCE" || { echo "cannot stage the delta" >&2; exit 1; }
neutralize_author_config "$WORKTREE" "$SINCE" "$MERGE_BASE"

echo "=== delta ${SINCE:0:8}..${HEAD_SHA:0:8}: $(git -C "$WORKTREE" diff --cached --shortstat)"
PROMPT="$(render_template "$PROMPT_FILE" REPO="$REPO" PR_NUMBER="$NUMBER" PR_URL="$PR_URL" \
  SINCE_SHA="$SINCE" HEAD_SHA="$HEAD_SHA" SINCE_SHORT="${SINCE:0:8}" HEAD_SHORT="${HEAD_SHA:0:8}" REVIEW_LEVEL="$LEVEL")"

(cd "$WORKTREE" && claude_pass delta "$WORK_DIR/delta.json" read-only "$PROMPT" --model "$MODEL" --effort low \
  --json-schema "$FINDINGS_SCHEMA" "${ISOLATED_SETTINGS[@]}" >/dev/null) || exit
REVIEW="$(jq -ce '.structured_output | select(type == "object" and (.findings | type) == "array" and (.confident | type) == "boolean")' \
  "$WORK_DIR/delta.json")" || { echo "=== delta: the session returned no structured findings" >&2; exit "$REVIEW_INCOMPLETE_RC"; }
COUNT="$(jq '.findings | length' <<<"$REVIEW")"
jq -r '.findings[] | "\(.path):\(.line) — \(.body | split("\n")[0])"' <<<"$REVIEW"
if [ "$COUNT" -gt 0 ]; then
  jq --arg sha "$HEAD_SHA" --arg body "Incremental review of ${SINCE:0:8}..${HEAD_SHA:0:8}: $COUNT findings." \
    --rawfile changed <(changed_lines "$MERGE_BASE" "$HEAD_SHA") '
    ($changed | split("\n")) as $lines
    | (.findings | map(. + {anchored: ("\(.path):\(.line)" as $at | any($lines[]; . == $at))})) as $all
    | {event: "COMMENT", commit_id: $sha,
       body: ([$body] + [$all[] | select(.anchored | not) | "- `\(.path):\(.line)`: \(.body)"] | join("\n\n")),
       comments: [$all[] | select(.anchored) | {path, line, side: "RIGHT", body}]}' <<<"$REVIEW" >"$WORK_DIR/payload.json" \
    || { echo "=== delta: cannot build the review payload" >&2; exit 1; }
  URL="$(gh api "repos/$REPO/pulls/$NUMBER/reviews" --input "$WORK_DIR/payload.json" --jq .html_url)" \
    || { echo "=== delta: posting the review failed" >&2; exit 1; }
  echo "=== delta review posted: $URL"
else
  echo "no findings, nothing posted"
fi
echo "DELTA_FINDINGS $COUNT"
echo "DELTA_CONFIDENT value=$(jq .confident <<<"$REVIEW")"
