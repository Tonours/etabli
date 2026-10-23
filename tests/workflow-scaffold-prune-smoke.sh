#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/tests/lib/workflow-scaffold.sh"

PRUNE_PROJECT="$TMP_DIR/prune-project"
"$SCRIPT" "$PRUNE_PROJECT" >/dev/null
RETIRED_SET="workflow/events.md scripts/workflow-event workflow/verification/cli-app.mjs scripts/lib/plan-status.mjs scripts/lib/hash.sh scripts/vendor/commonmark/commonmark.cjs"
mkdir -p "$PRUNE_PROJECT/workflow/verification" "$PRUNE_PROJECT/scripts/lib" "$PRUNE_PROJECT/scripts/vendor/commonmark"
for retired in scripts/lib/plan-status.mjs scripts/lib/hash.sh scripts/vendor/commonmark/commonmark.cjs; do
  shipped_copy "$retired" "$PRUNE_PROJECT/$retired"
done
shipped_copy workflow/events.md "$PRUNE_PROJECT/workflow/events.md"
shipped_copy scripts/workflow-event "$PRUNE_PROJECT/scripts/workflow-event"
shipped_copy workflow-scaffold/templates/verification/cli-app.mjs "$PRUNE_PROJECT/workflow/verification/cli-app.mjs"
"$SCRIPT" "$PRUNE_PROJECT" --prune --dry-run >"$TMP_DIR/prune-dry.out"
assert_contains "$TMP_DIR/prune-dry.out" "WOULD_REMOVE workflow/events.md"
assert_file "$PRUNE_PROJECT/workflow/events.md"
"$SCRIPT" "$PRUNE_PROJECT" --prune >"$TMP_DIR/prune.out"
for retired in $RETIRED_SET; do
  assert_not_exists "$PRUNE_PROJECT/$retired"
  assert_no_backup "$PRUNE_PROJECT/$retired"
done
assert_contains "$TMP_DIR/prune.out" "6 removed"
"$SCRIPT" "$PRUNE_PROJECT" --prune >"$TMP_DIR/prune-again.out"
assert_contains "$TMP_DIR/prune-again.out" "0 removed"

FOREIGN_PROJECT="$TMP_DIR/foreign-project"
"$SCRIPT" "$FOREIGN_PROJECT" >/dev/null
shipped_copy workflow/events.md "$FOREIGN_PROJECT/workflow/events.md"
shipped_copy workflow/spec.md "$FOREIGN_PROJECT/workflow/agent-quick-card.md"
printf 'project predicates\n' >"$FOREIGN_PROJECT/scripts/lib/predicates.mjs"
mkdir -p "$FOREIGN_PROJECT/scripts/project-verification"
printf 'witness\n' >"$FOREIGN_PROJECT/scripts/project-verification/witness"
ln -s missing-target "$FOREIGN_PROJECT/scripts/lib/workflow-events.mjs"
shipped_copy scripts/workflow-event "$TMP_DIR/shipped-readme"
ln -s "$TMP_DIR/shipped-readme" "$FOREIGN_PROJECT/scripts/workflow-event"
: >"$FOREIGN_PROJECT/scripts/lib/review-rounds.jq"
FOREIGN_SET="workflow/agent-quick-card.md scripts/lib/predicates.mjs scripts/project-verification scripts/lib/workflow-events.mjs scripts/workflow-event scripts/lib/review-rounds.jq"
for mode in --dry-run ""; do
  if "$SCRIPT" "$FOREIGN_PROJECT" --prune $mode >"$TMP_DIR/foreign.out" 2>&1; then
    printf 'expected prune to refuse project-owned retired paths\n' >&2
    exit 1
  fi
  for retired in $FOREIGN_SET; do
    assert_contains "$TMP_DIR/foreign.out" "CONFLICT  $retired is not a copy etabli shipped"
  done
  assert_not_contains "$TMP_DIR/foreign.out" "workflow/events.md is not a copy"
done
assert_file "$FOREIGN_PROJECT/workflow/events.md"
assert_file "$FOREIGN_PROJECT/scripts/lib/predicates.mjs"
assert_file "$FOREIGN_PROJECT/scripts/project-verification/witness"
[ -L "$FOREIGN_PROJECT/scripts/lib/workflow-events.mjs" ] || {
  printf 'expected the project symlink to stay\n' >&2
  exit 1
}
if "$SCRIPT" "$FOREIGN_PROJECT" --prune-foreign >/dev/null 2>&1; then
  printf 'expected --prune-foreign without --prune to fail\n' >&2
  exit 1
fi
"$SCRIPT" "$FOREIGN_PROJECT" --prune --prune-foreign >"$TMP_DIR/foreign-forced.out"
assert_not_exists "$FOREIGN_PROJECT/workflow/events.md"
assert_no_backup "$FOREIGN_PROJECT/workflow/events.md"
for retired in $FOREIGN_SET; do
  assert_not_exists "$FOREIGN_PROJECT/$retired"
  assert_backup "$FOREIGN_PROJECT/$retired"
done
assert_contains "$TMP_DIR/foreign-forced.out" "7 removed"
assert_file "$TMP_DIR/shipped-readme"

PRUNE_LINKED="$TMP_DIR/prune-linked"
PRUNE_OUTSIDE="$TMP_DIR/prune-outside"
"$SCRIPT" "$PRUNE_LINKED" >/dev/null
mkdir -p "$PRUNE_OUTSIDE"
mv "$PRUNE_LINKED/scripts/lib" "$PRUNE_OUTSIDE/lib"
ln -s "$PRUNE_OUTSIDE/lib" "$PRUNE_LINKED/scripts/lib"
printf 'outside\n' >"$PRUNE_OUTSIDE/lib/workflow-events.mjs"
printf 'inside\n' >"$PRUNE_LINKED/workflow/events.md"
if "$SCRIPT" "$PRUNE_LINKED" --prune >"$TMP_DIR/prune-linked.out" 2>&1; then
  printf 'expected prune to refuse a symlinked parent\n' >&2
  exit 1
fi
assert_contains "$TMP_DIR/prune-linked.out" "resolves outside the target"
assert_file "$PRUNE_OUTSIDE/lib/workflow-events.mjs"
assert_file "$PRUNE_LINKED/workflow/events.md"

TRACKED_PROJECT="$TMP_DIR/tracked-project"
"$SCRIPT" "$TRACKED_PROJECT" >/dev/null
printf '\nproject edit\n' >>"$TRACKED_PROJECT/workflow/spec.md"
shipped_copy scripts/workflow-event "$TRACKED_PROJECT/scripts/workflow-event"
git -C "$TRACKED_PROJECT" init -q .
printf '\nproject seed\n' >>"$TRACKED_PROJECT/docs/project-context.md"
printf '\nold template\n' >>"$TRACKED_PROJECT/docs/agent-workflow.md"
printf '\nold script\n' >>"$TRACKED_PROJECT/scripts/plan-cleanup"
TRACKED_OUTSIDE="$TMP_DIR/tracked-outside.md"
printf 'outside target\n' >"$TRACKED_OUTSIDE"
rm "$TRACKED_PROJECT/workflow/review-rubric.md"
ln -s "$TRACKED_OUTSIDE" "$TRACKED_PROJECT/workflow/review-rubric.md"
git -C "$TRACKED_PROJECT" add -f workflow/spec.md scripts/workflow-event docs/project-context.md docs/agent-workflow.md scripts/plan-cleanup workflow/review-rubric.md
git -C "$TRACKED_PROJECT" -c user.name=smoke -c user.email=smoke@example.invalid commit -q -m "track scaffold"
if "$SCRIPT" "$TRACKED_PROJECT" --refresh-tracked >/dev/null 2>&1; then
  printf 'expected --refresh-tracked without --force to fail\n' >&2
  exit 1
fi
"$SCRIPT" "$TRACKED_PROJECT" --force >"$TMP_DIR/tracked-force.out"
assert_contains "$TMP_DIR/tracked-force.out" "PROTECTED workflow/spec.md"
assert_contains "$TRACKED_PROJECT/workflow/spec.md" "project edit"
printf 'uncommitted edit\n' >>"$TRACKED_PROJECT/workflow/spec.md"
"$SCRIPT" "$TRACKED_PROJECT" --force --refresh-tracked >"$TMP_DIR/tracked-dirty.out"
assert_contains "$TMP_DIR/tracked-dirty.out" "workflow/spec.md has uncommitted changes"
assert_contains "$TRACKED_PROJECT/workflow/spec.md" "uncommitted edit"
git -C "$TRACKED_PROJECT" checkout -q -- workflow/spec.md
"$SCRIPT" "$TRACKED_PROJECT" --force --refresh-tracked --prune >"$TMP_DIR/tracked-refresh.out"
assert_same "$ROOT_DIR/workflow/spec.md" "$TRACKED_PROJECT/workflow/spec.md"
assert_contains "$TRACKED_PROJECT/docs/project-context.md" "project seed"
assert_contains "$TMP_DIR/tracked-refresh.out" "docs/project-context.md is a project-owned seed"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" "$TRACKED_PROJECT/docs/agent-workflow.md"
assert_contains "$TMP_DIR/tracked-refresh.out" "scripts/plan-cleanup is a tracked script"
assert_contains "$TRACKED_PROJECT/scripts/plan-cleanup" "old script"
assert_contains "$TMP_DIR/tracked-refresh.out" "workflow/review-rubric.md is a tracked symlink"
assert_contains "$TRACKED_OUTSIDE" "outside target"
assert_contains "$TMP_DIR/tracked-refresh.out" "GIT_RM    scripts/workflow-event"
assert_not_exists "$TRACKED_PROJECT/scripts/workflow-event"
assert_backup "$TRACKED_PROJECT/scripts/workflow-event"
if git -C "$TRACKED_PROJECT" ls-files --error-unmatch scripts/workflow-event >/dev/null 2>&1; then
  printf 'expected tracked retired file to leave the index\n' >&2
  exit 1
fi

STAGED_PROJECT="$TMP_DIR/staged-project"
"$SCRIPT" "$STAGED_PROJECT" >/dev/null
printf 'committed\n' >"$STAGED_PROJECT/workflow/events.md"
printf 'untracked retired\n' >"$STAGED_PROJECT/scripts/workflow-event"
git -C "$STAGED_PROJECT" init -q .
git -C "$STAGED_PROJECT" add -f workflow/events.md
git -C "$STAGED_PROJECT" -c user.name=smoke -c user.email=smoke@example.invalid commit -q -m "track retired"
printf 'staged only\n' >"$STAGED_PROJECT/workflow/events.md"
git -C "$STAGED_PROJECT" add -f workflow/events.md
if "$SCRIPT" "$STAGED_PROJECT" --prune >"$TMP_DIR/staged.out" 2>&1; then
  printf 'expected prune to refuse a retired file with staged changes\n' >&2
  exit 1
fi
assert_contains "$TMP_DIR/staged.out" "workflow/events.md has staged changes"
assert_file "$STAGED_PROJECT/workflow/events.md"
assert_file "$STAGED_PROJECT/scripts/workflow-event"

printf 'workflow scaffold prune smoke test: ok\n'
