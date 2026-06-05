#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/deploy-harness"
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

  grep -Fq "$needle" "$path" || {
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
assert_file "$NEW_PROJECT/docs/agent-harness.md"
assert_file "$NEW_PROJECT/docs/claude-code-harness.md"
assert_file "$NEW_PROJECT/docs/project-context.md"
assert_file "$NEW_PROJECT/workflow/spec.md"
assert_file "$NEW_PROJECT/workflow/review-rubric.md"
assert_file "$NEW_PROJECT/workflow/ticket-template.md"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
assert_same "$ROOT_DIR/harness/templates/AGENTS.md" "$NEW_PROJECT/AGENTS.md"
assert_same "$ROOT_DIR/harness/templates/CLAUDE.md" "$NEW_PROJECT/CLAUDE.md"
assert_same "$ROOT_DIR/harness/templates/docs/agent-harness.md" "$NEW_PROJECT/docs/agent-harness.md"
assert_same "$ROOT_DIR/harness/templates/docs/claude-code-harness.md" "$NEW_PROJECT/docs/claude-code-harness.md"
assert_same "$ROOT_DIR/harness/templates/docs/project-context.md" "$NEW_PROJECT/docs/project-context.md"
assert_same "$ROOT_DIR/workflow/spec.md" "$NEW_PROJECT/workflow/spec.md"
assert_same "$ROOT_DIR/workflow/review-rubric.md" "$NEW_PROJECT/workflow/review-rubric.md"
assert_same "$ROOT_DIR/workflow/ticket-template.md" "$NEW_PROJECT/workflow/ticket-template.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE.md" "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
assert_contains "$NEW_PROJECT/AGENTS.md" "Treat this file as a map"
assert_contains "$NEW_PROJECT/CLAUDE.md" "Claude Code-specific adapter"
assert_contains "$NEW_PROJECT/CLAUDE.md" "docs/claude-code-harness.md"
assert_contains "$NEW_PROJECT/docs/agent-harness.md" "Pi Coding Agent"
assert_contains "$NEW_PROJECT/docs/agent-harness.md" "Claude Code"
assert_contains "$NEW_PROJECT/docs/claude-code-harness.md" "planner -> builder -> evaluator"
assert_contains "$NEW_PROJECT/docs/project-context.md" "Smallest useful check"
assert_contains "$NEW_PROJECT/.gitignore" "PLAN.md"

"$SCRIPT" "$NEW_PROJECT" >/dev/null

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

"$SCRIPT" "$PARENT_CONFLICT_PROJECT" --force >/dev/null
assert_file "$PARENT_CONFLICT_PROJECT/docs/agent-harness.md"
if ! ls "$PARENT_CONFLICT_PROJECT"/docs.bak.* >/dev/null 2>&1; then
  printf 'expected docs backup after --force parent conflict\n' >&2
  exit 1
fi

"$SCRIPT" "$CONFLICT_PROJECT" --force >/dev/null
assert_contains "$CONFLICT_PROJECT/AGENTS.md" "project harness"
if ! ls "$CONFLICT_PROJECT"/AGENTS.md.bak.* >/dev/null 2>&1; then
  printf 'expected AGENTS.md backup after --force\n' >&2
  exit 1
fi

printf 'harness smoke test: ok\n'
