#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/deploy-workflow"
SCAFFOLD_SCRIPT="$ROOT_DIR/scripts/scaffold-project"
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

assert_file "$NEW_PROJECT/AGENTS.md"
assert_file "$NEW_PROJECT/CLAUDE.md"
assert_file "$NEW_PROJECT/docs/agent-workflow.md"
assert_file "$NEW_PROJECT/docs/agent-memory/README.md"
assert_file "$NEW_PROJECT/docs/plan/README.md"
assert_file "$NEW_PROJECT/docs/claude-code-workflow.md"
assert_file "$NEW_PROJECT/docs/project-context.md"
assert_file "$NEW_PROJECT/workflow/memory.md"
assert_file "$NEW_PROJECT/workflow/plan-archive.md"
assert_file "$NEW_PROJECT/workflow/spec.md"
assert_file "$NEW_PROJECT/workflow/skills/adversary.md"
assert_file "$NEW_PROJECT/workflow/skills/implementation-loop.md"
assert_file "$NEW_PROJECT/workflow/skills/orchestration.md"
assert_file "$NEW_PROJECT/workflow/review-rubric.md"
assert_file "$NEW_PROJECT/workflow/ticket-template.md"
assert_file "$NEW_PROJECT/workflow/linear-ticket-template.md"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" "$NEW_PROJECT/AGENTS.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/CLAUDE.md" "$NEW_PROJECT/CLAUDE.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" "$NEW_PROJECT/docs/agent-workflow.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-memory.md" "$NEW_PROJECT/docs/agent-memory/README.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/plan.md" "$NEW_PROJECT/docs/plan/README.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/claude-code-workflow.md" "$NEW_PROJECT/docs/claude-code-workflow.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/project-context.md" "$NEW_PROJECT/docs/project-context.md"
assert_same "$ROOT_DIR/workflow/memory.md" "$NEW_PROJECT/workflow/memory.md"
assert_same "$ROOT_DIR/workflow/plan-archive.md" "$NEW_PROJECT/workflow/plan-archive.md"
assert_same "$ROOT_DIR/workflow/spec.md" "$NEW_PROJECT/workflow/spec.md"
assert_same "$ROOT_DIR/workflow/skills/adversary.md" "$NEW_PROJECT/workflow/skills/adversary.md"
assert_same "$ROOT_DIR/workflow/skills/implementation-loop.md" "$NEW_PROJECT/workflow/skills/implementation-loop.md"
assert_same "$ROOT_DIR/workflow/skills/orchestration.md" "$NEW_PROJECT/workflow/skills/orchestration.md"
assert_same "$ROOT_DIR/workflow/review-rubric.md" "$NEW_PROJECT/workflow/review-rubric.md"
assert_same "$ROOT_DIR/workflow/ticket-template.md" "$NEW_PROJECT/workflow/ticket-template.md"
assert_same "$ROOT_DIR/workflow/linear-ticket-template.md" "$NEW_PROJECT/workflow/linear-ticket-template.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE.md" "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
assert_contains "$NEW_PROJECT/AGENTS.md" "Treat this file as a map"
assert_contains "$NEW_PROJECT/AGENTS.md" "docs/agent-memory/"
assert_contains "$NEW_PROJECT/AGENTS.md" "docs/plan/"
assert_contains "$NEW_PROJECT/CLAUDE.md" "Claude Code-specific adapter"
assert_contains "$NEW_PROJECT/CLAUDE.md" "docs/claude-code-workflow.md"
assert_contains "$NEW_PROJECT/docs/agent-workflow.md" "Pi Coding Agent"
assert_contains "$NEW_PROJECT/docs/agent-workflow.md" "Claude Code"
assert_contains "$NEW_PROJECT/docs/claude-code-workflow.md" "planner -> builder -> evaluator"
assert_contains "$NEW_PROJECT/docs/claude-code-workflow.md" "workflow/skills/orchestration.md"
assert_contains "$NEW_PROJECT/docs/project-context.md" "Smallest useful check"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "## Outcome"
assert_contains "$NEW_PROJECT/workflow/linear-ticket-template.md" "Linear Fields"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "Autonomous implementation loops are complete only when"
assert_contains "$NEW_PROJECT/workflow/skills/orchestration.md" "Capability Labels"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "## Stop conditions"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "Keep project-specific scope"
assert_contains "$NEW_PROJECT/.gitignore" "PLAN.md"

"$SCRIPT" "$NEW_PROJECT" >/dev/null

SCAFFOLD_PROJECT="$TMP_DIR/scaffold-project"
"$SCAFFOLD_SCRIPT" "$SCAFFOLD_PROJECT" --new >/dev/null
assert_file "$SCAFFOLD_PROJECT/AGENTS.md"
assert_file "$SCAFFOLD_PROJECT/docs/plan/README.md"

if "$SCAFFOLD_SCRIPT" "$SCAFFOLD_PROJECT" --new >/dev/null 2>&1; then
  printf 'expected scaffold --new to fail for a non-empty target\n' >&2
  exit 1
fi

CONVERT_PROJECT="$TMP_DIR/convert-project"
mkdir -p "$CONVERT_PROJECT"
printf 'existing project\n' > "$CONVERT_PROJECT/README.md"
"$SCAFFOLD_SCRIPT" "$CONVERT_PROJECT" --convert >/dev/null
assert_file "$CONVERT_PROJECT/AGENTS.md"
assert_contains "$CONVERT_PROJECT/README.md" "existing project"

MISSING_CONVERT_PROJECT="$TMP_DIR/missing-convert-project"
if "$SCAFFOLD_SCRIPT" "$MISSING_CONVERT_PROJECT" --convert >/dev/null 2>&1; then
  printf 'expected scaffold --convert to fail for a missing target\n' >&2
  exit 1
fi

DRY_PROJECT="$TMP_DIR/dry-project"
"$SCRIPT" "$DRY_PROJECT" --dry-run >/dev/null
assert_not_exists "$DRY_PROJECT"

CONFLICT_PROJECT="$TMP_DIR/conflict-project"
mkdir -p "$CONFLICT_PROJECT"
printf 'custom instructions\n' > "$CONFLICT_PROJECT/AGENTS.md"

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
printf 'not a directory\n' > "$PARENT_CONFLICT_PROJECT/docs"

if "$SCRIPT" "$PARENT_CONFLICT_PROJECT" >/dev/null 2>&1; then
  printf 'expected parent path conflict deploy to fail\n' >&2
  exit 1
fi
assert_contains "$PARENT_CONFLICT_PROJECT/docs" "not a directory"
assert_not_exists "$PARENT_CONFLICT_PROJECT/AGENTS.md"
assert_not_exists "$PARENT_CONFLICT_PROJECT/CLAUDE.md"
assert_not_exists "$PARENT_CONFLICT_PROJECT/workflow"

GITIGNORE_CONFLICT_PROJECT="$TMP_DIR/gitignore-conflict-project"
mkdir -p "$GITIGNORE_CONFLICT_PROJECT/.gitignore"

if "$SCRIPT" "$GITIGNORE_CONFLICT_PROJECT" >/dev/null 2>&1; then
  printf 'expected .gitignore directory conflict deploy to fail\n' >&2
  exit 1
fi
assert_not_exists "$GITIGNORE_CONFLICT_PROJECT/AGENTS.md"
assert_not_exists "$GITIGNORE_CONFLICT_PROJECT/CLAUDE.md"

TARGET_FILE_PROJECT="$TMP_DIR/target-file-project"
TARGET_FILE_OUTPUT="$TMP_DIR/target-file-project.out"
printf 'not a directory\n' > "$TARGET_FILE_PROJECT"

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

"$SCRIPT" "$GITIGNORE_CONFLICT_PROJECT" --force >/dev/null
assert_file "$GITIGNORE_CONFLICT_PROJECT/.gitignore"
assert_contains "$GITIGNORE_CONFLICT_PROJECT/.gitignore" "PLAN.md"
if ! ls "$GITIGNORE_CONFLICT_PROJECT"/.gitignore.bak.* >/dev/null 2>&1; then
  printf 'expected .gitignore backup after --force directory conflict\n' >&2
  exit 1
fi

"$SCRIPT" "$CONFLICT_PROJECT" --force >/dev/null
assert_contains "$CONFLICT_PROJECT/AGENTS.md" "project workflow scaffold"
if ! ls "$CONFLICT_PROJECT"/AGENTS.md.bak.* >/dev/null 2>&1; then
  printf 'expected AGENTS.md backup after --force\n' >&2
  exit 1
fi

printf 'custom instructions again\n' > "$CONFLICT_PROJECT/AGENTS.md"
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

printf 'workflow scaffold smoke test: ok\n'
