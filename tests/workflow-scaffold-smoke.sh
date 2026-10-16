#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/deploy-workflow"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_file() {
  [ -f "$1" ] || {
    printf 'missing file: %s\n' "$1" >&2
    exit 1
  }
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -Fq -- "$needle" "$path" || {
    printf 'expected %s in %s\n' "$needle" "$path" >&2
    exit 1
  }
}

assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
    exit 1
  }
}

assert_same() {
  local expected="$1"
  local actual="$2"

  cmp -s "$expected" "$actual" || {
    printf 'expected %s to match %s\n' "$actual" "$expected" >&2
    exit 1
  }
}

NEW_PROJECT="$TMP_DIR/new-project"
"$SCRIPT" "$NEW_PROJECT" >/dev/null

HELP_OUTPUT="$TMP_DIR/deploy-workflow-help.out"
"$SCRIPT" --help >"$HELP_OUTPUT"
assert_contains "$HELP_OUTPUT" "--check"

assert_file "$NEW_PROJECT/AGENTS.md"
assert_file "$NEW_PROJECT/docs/agent-workflow.md"
assert_file "$NEW_PROJECT/docs/agent-memory/README.md"
assert_file "$NEW_PROJECT/docs/plan/README.md"
assert_file "$NEW_PROJECT/docs/claude-code-workflow.md"
assert_file "$NEW_PROJECT/docs/project-context.md"
assert_file "$NEW_PROJECT/workflow/memory.md"
assert_file "$NEW_PROJECT/workflow/plan-archive.md"
assert_file "$NEW_PROJECT/workflow/spec.md"
assert_file "$NEW_PROJECT/workflow/contract-details.md"
assert_file "$NEW_PROJECT/workflow/answer-quality.md"
assert_file "$NEW_PROJECT/workflow/skill-design.md"
assert_file "$NEW_PROJECT/workflow/git-contract.md"
assert_file "$NEW_PROJECT/workflow/pr-body-contract.md"
assert_file "$NEW_PROJECT/workflow/verification-report-template.md"
assert_file "$NEW_PROJECT/workflow/templates/escaped-defect.md"
assert_same "$ROOT_DIR/workflow/project-constraints.md" "$NEW_PROJECT/workflow/project-constraints.md"
assert_contains "$NEW_PROJECT/AGENTS.md" '`workflow/project-constraints.md`'
assert_file "$NEW_PROJECT/workflow/review-rubric.md"
assert_file "$NEW_PROJECT/workflow/ticket-template.md"
assert_file "$NEW_PROJECT/workflow/linear-ticket-template.md"
assert_file "$NEW_PROJECT/workflow/evidence-pack.schema.json"
assert_file "$NEW_PROJECT/workflow/templates/evidence-pack.json"
assert_file "$NEW_PROJECT/workflow/templates/review-logic-hunter.md"
assert_file "$NEW_PROJECT/workflow/templates/review-spec-hunter.md"
assert_file "$NEW_PROJECT/workflow/templates/review-lead.md"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
for managed in scripts/lib/plan-cleanup-command.mjs scripts/lib/plan-status.mjs; do
 assert_file "$NEW_PROJECT/$managed"
 assert_same "$ROOT_DIR/$managed" "$NEW_PROJECT/$managed"
done
assert_file "$NEW_PROJECT/scripts/plan-cleanup"
assert_file "$NEW_PROJECT/scripts/lib/hash.sh"

[ -x "$NEW_PROJECT/scripts/plan-cleanup" ] || {
  printf 'expected deployed plan-cleanup to be executable\n' >&2
  exit 1
}
assert_same "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" "$NEW_PROJECT/AGENTS.md"
assert_not_exists "$NEW_PROJECT/CLAUDE.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" "$NEW_PROJECT/docs/agent-workflow.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-memory.md" "$NEW_PROJECT/docs/agent-memory/README.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/plan.md" "$NEW_PROJECT/docs/plan/README.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/claude-code-workflow.md" "$NEW_PROJECT/docs/claude-code-workflow.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/project-context.md" "$NEW_PROJECT/docs/project-context.md"
assert_same "$ROOT_DIR/workflow/memory.md" "$NEW_PROJECT/workflow/memory.md"
assert_same "$ROOT_DIR/workflow/plan-archive.md" "$NEW_PROJECT/workflow/plan-archive.md"
assert_same "$ROOT_DIR/workflow/spec.md" "$NEW_PROJECT/workflow/spec.md"
assert_same "$ROOT_DIR/workflow/review-rubric.md" "$NEW_PROJECT/workflow/review-rubric.md"
assert_same "$ROOT_DIR/workflow/ticket-template.md" "$NEW_PROJECT/workflow/ticket-template.md"
assert_same "$ROOT_DIR/workflow/linear-ticket-template.md" "$NEW_PROJECT/workflow/linear-ticket-template.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE.md" "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
assert_same "$ROOT_DIR/scripts/plan-cleanup" "$NEW_PROJECT/scripts/plan-cleanup"

# Deployed docs must not dangle: every workflow/** reference resolves in the
# scaffold unless the target is explicitly etabli-only.
ETABLI_ONLY_REFS='^workflow/(runtime-capabilities\.json$|runtime/|run/|self-improvement/)'
deployed_refs="$(grep -rhEo --include='*.md' 'workflow/[A-Za-z0-9._/-]+\.(md|json)' "$NEW_PROJECT" | sort -u)"
[ -n "$deployed_refs" ] || {
  printf 'reference scan found no workflow refs; the check is broken\n' >&2
  exit 1
}
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  if printf '%s\n' "$ref" | grep -Eq "$ETABLI_ONLY_REFS"; then
    continue
  fi
  if [ ! -e "$NEW_PROJECT/$ref" ]; then
    printf 'deployed doc references missing file: %s\n' "$ref" >&2
    exit 1
  fi
done <<<"$deployed_refs"

cat >"$NEW_PROJECT/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Subject: scaffold cleanup smoke
- Status: DRAFT
PLAN
(
  cd "$NEW_PROJECT"
  scripts/plan-cleanup --discard scaffold-smoke >/dev/null
)
assert_not_exists "$NEW_PROJECT/PLAN.md"
assert_file "$NEW_PROJECT/docs/plan/$(date -u +%Y%m%d)-discarded-scaffold-smoke.md"

while IFS= read -r contract_path; do
  contract_name="$(basename "$contract_path")"
  assert_file "$NEW_PROJECT/workflow/skills/$contract_name"
  assert_same "$contract_path" "$NEW_PROJECT/workflow/skills/$contract_name"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' | sort)
assert_contains "$NEW_PROJECT/AGENTS.md" "Ambient activation"
assert_contains "$NEW_PROJECT/AGENTS.md" "docs/agent-memory/"
assert_contains "$NEW_PROJECT/AGENTS.md" "docs/plan/"
assert_contains "$NEW_PROJECT/docs/agent-workflow.md" "Pi Coding Agent"
assert_contains "$NEW_PROJECT/docs/agent-workflow.md" "Claude Code"
assert_contains "$NEW_PROJECT/docs/claude-code-workflow.md" "planner -> builder -> evaluator"
assert_contains "$NEW_PROJECT/docs/claude-code-workflow.md" "workflow/skills/orchestration.md"
assert_contains "$NEW_PROJECT/docs/project-context.md" "Smallest useful check"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "## Outcome"
assert_contains "$NEW_PROJECT/workflow/linear-ticket-template.md" "Linear Fields"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "Autonomous completion requires:"
assert_contains "$NEW_PROJECT/workflow/skills/orchestration.md" "Capability Labels"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "## Stop conditions"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "Keep project-specific scope"
assert_not_exists "$NEW_PROJECT/.gitignore"
git -C "$NEW_PROJECT" init -q .
"$SCRIPT" "$NEW_PROJECT" >/dev/null
assert_contains "$NEW_PROJECT/.git/info/exclude" "etabli personal workflow ignores"
assert_contains "$NEW_PROJECT/.git/info/exclude" "/PLAN.md"
assert_contains "$NEW_PROJECT/.git/info/exclude" "/workflow/"
assert_contains "$NEW_PROJECT/.git/info/exclude" "/scripts/lib/hash.sh"
for managed in scripts/lib/plan-status.mjs scripts/lib/plan-cleanup-command.mjs scripts/vendor/commonmark/commonmark.cjs; do
  git -C "$NEW_PROJECT" check-ignore -q -- "$managed" || { printf 'managed tooling exposed to project Git: %s\n' "$managed" >&2; exit 1; }
done
printf '// changed managed helper\n' >>"$NEW_PROJECT/scripts/lib/plan-status.mjs"
"$SCRIPT" "$NEW_PROJECT" --force >/dev/null
assert_same "$ROOT_DIR/scripts/lib/plan-status.mjs" "$NEW_PROJECT/scripts/lib/plan-status.mjs"
assert_not_exists "$NEW_PROJECT/.gitignore"

"$SCRIPT" "$NEW_PROJECT" >/dev/null

CHECK_CLEAN_OUTPUT="$TMP_DIR/check-clean.out"
"$SCRIPT" "$NEW_PROJECT" --check >"$CHECK_CLEAN_OUTPUT"
assert_contains "$CHECK_CLEAN_OUTPUT" "OK        workflow/spec.md"
assert_contains "$CHECK_CLEAN_OUTPUT" "Summary: 0 drifted, 0 missing"

CHECK_DRIFT_PROJECT="$TMP_DIR/check-drift-project"
CHECK_DRIFT_OUTPUT="$TMP_DIR/check-drift.out"
"$SCRIPT" "$CHECK_DRIFT_PROJECT" >/dev/null
printf '\nlocal change\n' >>"$CHECK_DRIFT_PROJECT/workflow/spec.md"
rm "$CHECK_DRIFT_PROJECT/PLAN_TEMPLATE.md"
find "$CHECK_DRIFT_PROJECT" -print | sort >"$TMP_DIR/check-drift.before"
if "$SCRIPT" "$CHECK_DRIFT_PROJECT" --check >"$CHECK_DRIFT_OUTPUT" 2>&1; then
  printf 'expected deploy --check to fail on drifted project\n' >&2
  exit 1
fi
find "$CHECK_DRIFT_PROJECT" -print | sort >"$TMP_DIR/check-drift.after"
if ! diff -u "$TMP_DIR/check-drift.before" "$TMP_DIR/check-drift.after"; then
  printf 'deploy --check mutated the checked project\n' >&2
  exit 1
fi
assert_contains "$CHECK_DRIFT_OUTPUT" "DRIFT     workflow/spec.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "MISSING   PLAN_TEMPLATE.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "Summary: 1 drifted, 1 missing"
assert_contains "$CHECK_DRIFT_PROJECT/workflow/spec.md" "local change"
assert_not_exists "$CHECK_DRIFT_PROJECT/PLAN_TEMPLATE.md"

CHECK_FLAG_OUTPUT="$TMP_DIR/check-flags.out"
if "$SCRIPT" "$NEW_PROJECT" --check --force >"$CHECK_FLAG_OUTPUT" 2>&1; then
  printf 'expected deploy --check --force to fail\n' >&2
  exit 1
fi
assert_contains "$CHECK_FLAG_OUTPUT" "flags are mutually exclusive"

if "$SCRIPT" "$NEW_PROJECT" --check --dry-run >"$CHECK_FLAG_OUTPUT" 2>&1; then
  printf 'expected deploy --check --dry-run to fail\n' >&2
  exit 1
fi
assert_contains "$CHECK_FLAG_OUTPUT" "flags are mutually exclusive"

DRY_PROJECT="$TMP_DIR/dry-project"
"$SCRIPT" "$DRY_PROJECT" --dry-run >/dev/null
assert_not_exists "$DRY_PROJECT"

CONFLICT_PROJECT="$TMP_DIR/conflict-project"
mkdir -p "$CONFLICT_PROJECT"
printf 'custom instructions\n' >"$CONFLICT_PROJECT/AGENTS.md"

if "$SCRIPT" "$CONFLICT_PROJECT" >/dev/null 2>&1; then
  printf 'expected conflict deploy to fail\n' >&2
  exit 1
fi
assert_contains "$CONFLICT_PROJECT/AGENTS.md" "custom instructions"
assert_not_exists "$CONFLICT_PROJECT/CLAUDE.md"
assert_not_exists "$CONFLICT_PROJECT/workflow"
assert_not_exists "$CONFLICT_PROJECT/docs"
assert_not_exists "$CONFLICT_PROJECT/PLAN_TEMPLATE.md"
assert_not_exists "$CONFLICT_PROJECT/.gitignore"

PARENT_CONFLICT_PROJECT="$TMP_DIR/parent-conflict-project"
mkdir -p "$PARENT_CONFLICT_PROJECT"
printf 'not a directory\n' >"$PARENT_CONFLICT_PROJECT/docs"

if "$SCRIPT" "$PARENT_CONFLICT_PROJECT" >/dev/null 2>&1; then
  printf 'expected parent path conflict deploy to fail\n' >&2
  exit 1
fi
assert_contains "$PARENT_CONFLICT_PROJECT/docs" "not a directory"
assert_not_exists "$PARENT_CONFLICT_PROJECT/AGENTS.md"
assert_not_exists "$PARENT_CONFLICT_PROJECT/CLAUDE.md"
assert_not_exists "$PARENT_CONFLICT_PROJECT/workflow"

TARGET_FILE_PROJECT="$TMP_DIR/target-file-project"
TARGET_FILE_OUTPUT="$TMP_DIR/target-file-project.out"
printf 'not a directory\n' >"$TARGET_FILE_PROJECT"

if "$SCRIPT" "$TARGET_FILE_PROJECT" --force >"$TARGET_FILE_OUTPUT" 2>&1; then
  printf 'expected deploy to fail when target path is a file, even with --force\n' >&2
  exit 1
fi
assert_contains "$TARGET_FILE_OUTPUT" "exists but is not a directory"
assert_contains "$TARGET_FILE_PROJECT" "not a directory"

"$SCRIPT" "$PARENT_CONFLICT_PROJECT" --force >/dev/null
assert_file "$PARENT_CONFLICT_PROJECT/docs/agent-workflow.md"
if ! ls "$PARENT_CONFLICT_PROJECT"/docs.bak.* >/dev/null 2>&1; then
  printf 'expected docs backup after --force parent conflict\n' >&2
  exit 1
fi

"$SCRIPT" "$CONFLICT_PROJECT" --force >/dev/null
assert_contains "$CONFLICT_PROJECT/AGENTS.md" "project workflow scaffold"
if ! ls "$CONFLICT_PROJECT"/AGENTS.md.bak.* >/dev/null 2>&1; then
  printf 'expected AGENTS.md backup after --force\n' >&2
  exit 1
fi

printf 'custom instructions again\n' >"$CONFLICT_PROJECT/AGENTS.md"
"$SCRIPT" "$CONFLICT_PROJECT" --force >/dev/null
if [ "$(find "$CONFLICT_PROJECT" -maxdepth 1 -name 'AGENTS.md.bak.*' | wc -l | tr -d ' ')" -lt 2 ]; then
  printf 'expected repeated --force deploys to keep distinct AGENTS.md backups\n' >&2
  exit 1
fi

BROKEN_REPO="$TMP_DIR/broken-repo"
BROKEN_PROJECT="$TMP_DIR/broken-project"
BROKEN_OUTPUT="$TMP_DIR/broken-source.out"
mkdir -p "$BROKEN_REPO/scripts"
cp "$SCRIPT" "$BROKEN_REPO/scripts/deploy-workflow"
chmod +x "$BROKEN_REPO/scripts/deploy-workflow"

if "$BROKEN_REPO/scripts/deploy-workflow" "$BROKEN_PROJECT" --force >"$BROKEN_OUTPUT" 2>&1; then
  printf 'expected deploy to fail when workflow scaffold sources are missing, even with --force\n' >&2
  exit 1
fi
assert_contains "$BROKEN_OUTPUT" "MISSING"
assert_not_exists "$BROKEN_PROJECT"
assert_not_exists "$BROKEN_PROJECT/AGENTS.md"
assert_not_exists "$BROKEN_PROJECT/.gitignore"

assert_backup() {
  compgen -G "$1.bak.*" >/dev/null || {
    printf 'expected backup of %s\n' "$1" >&2
    exit 1
  }
}

PRUNE_PROJECT="$TMP_DIR/prune-project"
"$SCRIPT" "$PRUNE_PROJECT" >/dev/null
RETIRED_SET="workflow/events.md scripts/workflow-event scripts/lib/workflow-events.mjs scripts/lib/predicates.mjs"
for retired in $RETIRED_SET; do
  printf 'retired copy\n' >"$PRUNE_PROJECT/$retired"
done
printf '\nlocal consumer edit\n' >>"$PRUNE_PROJECT/workflow/events.md"
"$SCRIPT" "$PRUNE_PROJECT" --prune --dry-run >"$TMP_DIR/prune-dry.out"
assert_contains "$TMP_DIR/prune-dry.out" "WOULD_REMOVE workflow/events.md"
assert_file "$PRUNE_PROJECT/workflow/events.md"
"$SCRIPT" "$PRUNE_PROJECT" --prune >"$TMP_DIR/prune.out"
for retired in $RETIRED_SET; do
  assert_not_exists "$PRUNE_PROJECT/$retired"
  assert_backup "$PRUNE_PROJECT/$retired"
done
assert_contains "$TMP_DIR/prune.out" "4 removed"
"$SCRIPT" "$PRUNE_PROJECT" --prune >"$TMP_DIR/prune-again.out"
assert_contains "$TMP_DIR/prune-again.out" "0 removed"

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
printf 'tracked retired\n' >"$TRACKED_PROJECT/scripts/workflow-event"
git -C "$TRACKED_PROJECT" init -q .
git -C "$TRACKED_PROJECT" add -f workflow/spec.md scripts/workflow-event
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
assert_contains "$TMP_DIR/tracked-refresh.out" "GIT_RM    scripts/workflow-event"
assert_not_exists "$TRACKED_PROJECT/scripts/workflow-event"
assert_backup "$TRACKED_PROJECT/scripts/workflow-event"
if git -C "$TRACKED_PROJECT" ls-files --error-unmatch scripts/workflow-event >/dev/null 2>&1; then
  printf 'expected tracked retired file to leave the index\n' >&2
  exit 1
fi

printf 'workflow scaffold smoke test: ok\n'
