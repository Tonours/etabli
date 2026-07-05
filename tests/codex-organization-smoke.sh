#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DEPLOY_SCRIPT="$ROOT_DIR/scripts/deploy-codex"
AUDIT_SCRIPT="$ROOT_DIR/scripts/audit-codex-organization"
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

assert_symlink() {
  [ -L "$1" ] || {
    printf 'missing symlink: %s\n' "$1" >&2
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

"$AUDIT_SCRIPT" >/dev/null

DRY_HOME="$TMP_DIR/dry-home"
DRY_OUTPUT="$TMP_DIR/dry-run.out"
"$DEPLOY_SCRIPT" --dry-run --codex-home "$DRY_HOME" >"$DRY_OUTPUT"
assert_contains "$DRY_OUTPUT" "WOULD_LINK"
assert_not_exists "$DRY_HOME"

CODEX_HOME_DIR="$TMP_DIR/codex-home"
"$DEPLOY_SCRIPT" --apply --codex-home "$CODEX_HOME_DIR" >/dev/null

assert_symlink "$CODEX_HOME_DIR/AGENTS.md"
assert_symlink "$CODEX_HOME_DIR/config.managed.toml"
assert_symlink "$CODEX_HOME_DIR/hooks.json"
assert_file "$CODEX_HOME_DIR/workflow/dynamic-workflow-triggers.md"
assert_file "$CODEX_HOME_DIR/workflow/ticket-template.md"
while IFS= read -r contract_path; do
  contract_name="$(basename "$contract_path")"
  assert_symlink "$CODEX_HOME_DIR/workflow/skills/$contract_name"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' | sort)
assert_contains "$CODEX_HOME_DIR/workflow/ticket-template.md" "## Start here"
assert_contains "$CODEX_HOME_DIR/workflow/ticket-template.md" "## Stop conditions"
assert_contains "$CODEX_HOME_DIR/workflow/skills/linear-work.md" "LINEAR_MCP_UNAVAILABLE"
assert_contains "$CODEX_HOME_DIR/workflow/dynamic-workflow-triggers.md" "multi_agent_v1.spawn_agent"
assert_file "$CODEX_HOME_DIR/prompts/opsx-apply.md"
assert_file "$CODEX_HOME_DIR/automations/templates/repo-hygiene.template.toml"
assert_file "$CODEX_HOME_DIR/automations/templates/thread-checkpoint.template.toml"
assert_file "$CODEX_HOME_DIR/skills/codex-dynamic-workflows/SKILL.md"
assert_contains "$CODEX_HOME_DIR/AGENTS.md" "multi_agent_v1.spawn_agent"
assert_contains "$CODEX_HOME_DIR/skills/codex-dynamic-workflows/SKILL.md" "multi_agent_v1.spawn_agent"
assert_contains "$CODEX_HOME_DIR/hooks.json" '$HOME/.codex/herdr-agent-state.sh'
assert_not_exists "$CODEX_HOME_DIR/thread-organization"

"$DEPLOY_SCRIPT" --apply --codex-home "$CODEX_HOME_DIR" >/dev/null

CONFLICT_HOME="$TMP_DIR/conflict-home"
mkdir -p "$CONFLICT_HOME"
printf 'custom\n' >"$CONFLICT_HOME/AGENTS.md"

if "$DEPLOY_SCRIPT" --apply --codex-home "$CONFLICT_HOME" >/dev/null 2>&1; then
  printf 'expected conflict deploy to fail\n' >&2
  exit 1
fi

assert_contains "$CONFLICT_HOME/AGENTS.md" "custom"
assert_not_exists "$CONFLICT_HOME/hooks.json"

"$DEPLOY_SCRIPT" --apply --force --codex-home "$CONFLICT_HOME" >/dev/null
assert_symlink "$CONFLICT_HOME/AGENTS.md"
if ! ls "$CONFLICT_HOME"/AGENTS.md.bak.* >/dev/null 2>&1; then
  printf 'expected AGENTS.md backup after forced deploy\n' >&2
  exit 1
fi

printf 'codex organization smoke test: ok\n'
