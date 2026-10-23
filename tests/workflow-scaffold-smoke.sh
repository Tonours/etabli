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

assert_not_contains() {
  if grep -Fq -- "$2" "$1"; then
    printf 'unexpected %s in %s\n' "$2" "$1" >&2
    exit 1
  fi
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
assert_same "$ROOT_DIR/scripts/lib/plan-cleanup-command.mjs" "$NEW_PROJECT/scripts/lib/plan-cleanup-command.mjs"
assert_file "$NEW_PROJECT/scripts/plan-cleanup"
for retired in scripts/lib/plan-status.mjs scripts/lib/hash.sh scripts/vendor; do
  assert_not_exists "$NEW_PROJECT/$retired"
done

[ -x "$NEW_PROJECT/scripts/plan-cleanup" ] || {
  printf 'expected deployed plan-cleanup to be executable\n' >&2
  exit 1
}
assert_same "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" "$NEW_PROJECT/AGENTS.md"
assert_not_exists "$NEW_PROJECT/CLAUDE.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" "$NEW_PROJECT/docs/agent-workflow.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-memory.md" "$NEW_PROJECT/docs/agent-memory/README.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/plan.md" "$NEW_PROJECT/docs/plan/README.md"
assert_contains "$NEW_PROJECT/docs/plan/README.md" '- Source plan: `PLAN.md`'
assert_contains "$NEW_PROJECT/docs/plan/README.md" '- Source plan SHA-256:'
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
ETABLI_ONLY_REFS='^workflow/(runtime/|run/|self-improvement/)'
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
for managed in scripts/plan-cleanup scripts/lib/plan-cleanup-command.mjs; do
  git -C "$NEW_PROJECT" check-ignore -q -- "$managed" || { printf 'managed tooling exposed to project Git: %s\n' "$managed" >&2; exit 1; }
done
LINKED_MAIN="$TMP_DIR/linked-main"
LINKED_WORKTREE="$TMP_DIR/linked-worktree"
git init -q "$LINKED_MAIN"
git -C "$LINKED_MAIN" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m base
git -C "$LINKED_MAIN" worktree add -q "$LINKED_WORKTREE"
"$SCRIPT" "$LINKED_WORKTREE" >/dev/null
assert_contains "$LINKED_MAIN/.git/info/exclude" "etabli personal workflow ignores"
OLD_GIT_BIN="$TMP_DIR/old-git-bin"
OLD_GIT_PROJECT="$TMP_DIR/old-git-project"
mkdir -p "$OLD_GIT_BIN"
REAL_GIT="$(command -v git)"
cat >"$OLD_GIT_BIN/git" <<EOF
#!/bin/sh
for arg in "\$@"; do
  case "\$arg" in --path-format=*) printf '%s\\n' "\$arg"; exit 0 ;; esac
done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$OLD_GIT_BIN/git"
git init -q "$OLD_GIT_PROJECT"
PATH="$OLD_GIT_BIN:$PATH" "$SCRIPT" "$OLD_GIT_PROJECT" >/dev/null
assert_contains "$OLD_GIT_PROJECT/.git/info/exclude" "etabli personal workflow ignores"
linked_status="$(git -C "$LINKED_WORKTREE" status --porcelain --untracked-files=all)"
[ -z "$linked_status" ] || { printf 'scaffold files exposed in a linked worktree:\n%s\n' "$linked_status" >&2; exit 1; }
printf '// changed managed helper\n' >>"$NEW_PROJECT/scripts/lib/plan-cleanup-command.mjs"
"$SCRIPT" "$NEW_PROJECT" --force >/dev/null
assert_same "$ROOT_DIR/scripts/lib/plan-cleanup-command.mjs" "$NEW_PROJECT/scripts/lib/plan-cleanup-command.mjs"
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
git -C "$ROOT_DIR" show "$(git -C "$ROOT_DIR" log -2 --format=%H -- workflow/answer-quality.md | tail -1):workflow/answer-quality.md" >"$CHECK_DRIFT_PROJECT/workflow/answer-quality.md"
git -C "$ROOT_DIR" show HEAD:AGENTS.md >"$CHECK_DRIFT_PROJECT/AGENTS.md"
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
assert_contains "$CHECK_DRIFT_OUTPUT" "EDITED    workflow/spec.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "STALE     workflow/answer-quality.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "EDITED    AGENTS.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "MISSING   PLAN_TEMPLATE.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "Summary: 3 drifted, 1 missing"
assert_contains "$CHECK_DRIFT_OUTPUT" "Fix: $SCRIPT $(cd "$CHECK_DRIFT_PROJECT" && pwd) writes MISSING and refreshes STALE copies; review EDITED copies, then rerun it with --force"
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

assert_no_backup() {
  if compgen -G "$1.bak.*" >/dev/null; then
    printf 'unexpected backup of %s\n' "$1" >&2
    exit 1
  fi
}

shipped_copy() {
  git -C "$ROOT_DIR" show "$(git -C "$ROOT_DIR" log -1 --format=%H --diff-filter=AM -- "$1"):$1" >"$2"
}

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

STALE_PROJECT="$TMP_DIR/stale-project"
"$SCRIPT" "$STALE_PROJECT" >/dev/null
git -C "$ROOT_DIR" show "$(git -C "$ROOT_DIR" log -2 --format=%H -- workflow/answer-quality.md | tail -1):workflow/answer-quality.md" >"$STALE_PROJECT/workflow/answer-quality.md"
"$SCRIPT" "$STALE_PROJECT" --dry-run >"$TMP_DIR/stale-dry.out"
assert_contains "$TMP_DIR/stale-dry.out" "WOULD_REFRESH workflow/answer-quality.md"
"$SCRIPT" "$STALE_PROJECT" >"$TMP_DIR/stale.out"
assert_contains "$TMP_DIR/stale.out" "REFRESH   workflow/answer-quality.md"
assert_same "$ROOT_DIR/workflow/answer-quality.md" "$STALE_PROJECT/workflow/answer-quality.md"
if compgen -G "$STALE_PROJECT/workflow/answer-quality.md.bak.*" >/dev/null; then
  printf 'a STALE refresh left a backup\n' >&2
  exit 1
fi
"$SCRIPT" "$STALE_PROJECT" --check >/dev/null
STALE_OUTSIDE="$TMP_DIR/stale-outside"
mkdir -p "$STALE_OUTSIDE"
mv "$STALE_PROJECT/workflow" "$STALE_OUTSIDE/workflow"
ln -s "$STALE_OUTSIDE/workflow" "$STALE_PROJECT/workflow"
git -C "$ROOT_DIR" show "$(git -C "$ROOT_DIR" log -2 --format=%H -- workflow/answer-quality.md | tail -1):workflow/answer-quality.md" >"$STALE_OUTSIDE/workflow/answer-quality.md"
cp "$STALE_OUTSIDE/workflow/answer-quality.md" "$TMP_DIR/stale-outside.before"
if "$SCRIPT" "$STALE_PROJECT" >"$TMP_DIR/stale-outside.out" 2>&1; then
  printf 'expected a refresh through a symlinked parent to conflict\n' >&2
  exit 1
fi
assert_contains "$TMP_DIR/stale-outside.out" "CONFLICT  workflow/answer-quality.md exists"
assert_same "$TMP_DIR/stale-outside.before" "$STALE_OUTSIDE/workflow/answer-quality.md"

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

printf 'workflow scaffold smoke test: ok\n'
