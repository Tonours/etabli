#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/tests/lib/workflow-scaffold.sh"

KEPT_PROJECT="$TMP_DIR/kept-project"
"$SCRIPT" "$KEPT_PROJECT" >/dev/null
shipped_copy scripts/lib/hash.sh "$KEPT_PROJECT/scripts/lib/hash.sh"
git -C "$KEPT_PROJECT" init -q .
git -C "$KEPT_PROJECT" add -f scripts/lib/hash.sh
git -C "$KEPT_PROJECT" -c user.name=smoke -c user.email=smoke@example.invalid commit -q -m "track retired"
for mode in "" --force "--force --refresh-tracked"; do
  "$SCRIPT" "$KEPT_PROJECT" $mode >/dev/null
  assert_same "$ROOT_DIR/tests/lib/hash.sh" "$KEPT_PROJECT/scripts/lib/hash.sh"
  assert_no_backup "$KEPT_PROJECT/scripts/lib/hash.sh"
  [ -n "$(git -C "$KEPT_PROJECT" ls-files scripts/lib/hash.sh)" ] || {
    printf 'a run without --prune unindexed a tracked retired file (%s)\n' "${mode:-default}" >&2
    exit 1
  }
done
"$SCRIPT" "$KEPT_PROJECT" --prune >"$TMP_DIR/kept-prune.out"
assert_contains "$TMP_DIR/kept-prune.out" "GIT_RM    scripts/lib/hash.sh"
assert_backup "$KEPT_PROJECT/scripts/lib/hash.sh"

index_snapshot() {
  git -C "$1" ls-files --stage
}

UNINDEX_PROJECT="$TMP_DIR/unindex-project"
"$SCRIPT" "$UNINDEX_PROJECT" >/dev/null
shipped_copy workflow/events.md "$UNINDEX_PROJECT/workflow/events.md"
mkdir -p "$UNINDEX_PROJECT/scripts/project-verification"
printf 'tracked witness\n' >"$UNINDEX_PROJECT/scripts/project-verification/witness"
git -C "$UNINDEX_PROJECT" init -q .
git -C "$UNINDEX_PROJECT" add -f workflow/events.md scripts/project-verification/witness
git -C "$UNINDEX_PROJECT" -c user.name=smoke -c user.email=smoke@example.invalid commit -q -m "track retired"
rm "$UNINDEX_PROJECT/workflow/events.md"
"$SCRIPT" "$UNINDEX_PROJECT" --prune --prune-foreign --dry-run >"$TMP_DIR/unindex-dry.out"
assert_contains "$TMP_DIR/unindex-dry.out" "WOULD_UNINDEX workflow/events.md"
"$SCRIPT" "$UNINDEX_PROJECT" --prune --prune-foreign >"$TMP_DIR/unindex.out"
assert_contains "$TMP_DIR/unindex.out" "UNINDEX   workflow/events.md"
assert_contains "$TMP_DIR/unindex.out" "GIT_RM    scripts/project-verification"
if [ -n "$(git -C "$UNINDEX_PROJECT" ls-files workflow/events.md scripts/project-verification)" ]; then
  printf 'expected missing and directory retired paths to leave the index\n' >&2
  exit 1
fi
assert_backup "$UNINDEX_PROJECT/scripts/project-verification"
"$SCRIPT" "$UNINDEX_PROJECT" --prune >"$TMP_DIR/unindex-again.out"
assert_contains "$TMP_DIR/unindex-again.out" "0 removed"

GONE_PROJECT="$TMP_DIR/gone-project"
"$SCRIPT" "$GONE_PROJECT" >/dev/null
mkdir -p "$GONE_PROJECT/workflow/verification"
shipped_copy workflow-scaffold/templates/verification/cli-app.mjs "$GONE_PROJECT/workflow/verification/cli-app.mjs"
shipped_copy workflow/events.md "$GONE_PROJECT/workflow/events.md"
git -C "$GONE_PROJECT" init -q .
git -C "$GONE_PROJECT" add -f workflow/verification/cli-app.mjs workflow/events.md
git -C "$GONE_PROJECT" -c user.name=smoke -c user.email=smoke@example.invalid commit -q -m "track retired"
printf 'staged only\n' >"$GONE_PROJECT/workflow/verification/cli-app.mjs"
git -C "$GONE_PROJECT" add -f workflow/verification/cli-app.mjs
rm -r "$GONE_PROJECT/workflow/verification"
git -C "$GONE_PROJECT" rm -q --cached workflow/events.md
index_snapshot "$GONE_PROJECT" >"$TMP_DIR/gone-index.before"
for mode in --dry-run "" --prune-foreign; do
  if "$SCRIPT" "$GONE_PROJECT" --prune $mode >"$TMP_DIR/gone.out" 2>&1; then
    printf 'expected prune to refuse staged retired paths\n' >&2
    exit 1
  fi
  assert_contains "$TMP_DIR/gone.out" "workflow/verification/cli-app.mjs has staged changes"
  assert_contains "$TMP_DIR/gone.out" "workflow/events.md has staged changes"
done
index_snapshot "$GONE_PROJECT" >"$TMP_DIR/gone-index.after"
cmp -s "$TMP_DIR/gone-index.before" "$TMP_DIR/gone-index.after" || {
  printf 'expected a refused prune to leave the index unchanged\n' >&2
  exit 1
}
assert_file "$GONE_PROJECT/workflow/events.md"

BLIND_PROJECT="$TMP_DIR/blind-project"
"$SCRIPT" "$BLIND_PROJECT" >/dev/null
shipped_copy workflow/events.md "$BLIND_PROJECT/workflow/events.md"
git -C "$BLIND_PROJECT" init -q .
printf 'workflow/events.md diff=blind\n' >"$BLIND_PROJECT/.gitattributes"
git -C "$BLIND_PROJECT" config diff.blind.textconv true
git -C "$BLIND_PROJECT" add -f workflow/events.md .gitattributes
git -C "$BLIND_PROJECT" -c user.name=smoke -c user.email=smoke@example.invalid commit -q -m "track retired"
printf 'unique staged content\n' >"$BLIND_PROJECT/workflow/events.md"
git -C "$BLIND_PROJECT" add -f workflow/events.md
rm "$BLIND_PROJECT/workflow/events.md"
index_snapshot "$BLIND_PROJECT" >"$TMP_DIR/blind-index.before"
if "$SCRIPT" "$BLIND_PROJECT" --prune >"$TMP_DIR/blind.out" 2>&1; then
  printf 'expected prune to see staged content through a textconv driver\n' >&2
  exit 1
fi
assert_contains "$TMP_DIR/blind.out" "workflow/events.md has staged changes"
index_snapshot "$BLIND_PROJECT" | cmp -s - "$TMP_DIR/blind-index.before" || {
  printf 'expected a refused prune to keep the staged entry\n' >&2
  exit 1
}

SPARSE_PROJECT="$TMP_DIR/sparse-project"
mkdir -p "$SPARSE_PROJECT/src" "$SPARSE_PROJECT/workflow"
printf 'keep\n' >"$SPARSE_PROJECT/src/keep"
shipped_copy workflow/events.md "$SPARSE_PROJECT/workflow/events.md"
git -C "$SPARSE_PROJECT" init -q .
git -C "$SPARSE_PROJECT" add src/keep workflow/events.md
git -C "$SPARSE_PROJECT" -c user.name=smoke -c user.email=smoke@example.invalid commit -q -m "track retired"
git -C "$SPARSE_PROJECT" sparse-checkout set --cone src
assert_not_exists "$SPARSE_PROJECT/workflow/events.md"
"$SCRIPT" "$SPARSE_PROJECT" --prune >"$TMP_DIR/sparse.out"
assert_contains "$TMP_DIR/sparse.out" "UNINDEX   workflow/events.md"
if [ -n "$(git -C "$SPARSE_PROJECT" ls-files workflow/events.md)" ]; then
  printf 'expected the sparse retired entry to leave the index\n' >&2
  exit 1
fi

UNBORN_PROJECT="$TMP_DIR/unborn-project"
"$SCRIPT" "$UNBORN_PROJECT" >/dev/null
shipped_copy workflow/events.md "$UNBORN_PROJECT/workflow/events.md"
git -C "$UNBORN_PROJECT" init -q .
git -C "$UNBORN_PROJECT" add -f workflow/events.md
if "$SCRIPT" "$UNBORN_PROJECT" --prune >"$TMP_DIR/unborn.out" 2>&1; then
  printf 'expected prune to refuse a retired file staged before the first commit\n' >&2
  exit 1
fi
assert_contains "$TMP_DIR/unborn.out" "workflow/events.md has staged changes"
assert_file "$UNBORN_PROJECT/workflow/events.md"

printf 'workflow scaffold prune index smoke test: ok\n'
