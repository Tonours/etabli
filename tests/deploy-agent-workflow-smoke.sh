#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DEPLOY_SCRIPT="$ROOT_DIR/scripts/deploy-agent-workflow"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="$TMP_DIR/home"
DRY_HOME_DIR="$TMP_DIR/dry-home"
mkdir -p "$HOME_DIR"

grep -Fq 'pi_node_modules="$HOME_DIR/.pi/agent/npm/node_modules"' "$DEPLOY_SCRIPT" || {
  printf 'deploy script must use the Pi agent npm directory\n' >&2
  exit 1
}

"$DEPLOY_SCRIPT" --dry-run --home "$DRY_HOME_DIR" >/dev/null
if [ -e "$DRY_HOME_DIR" ]; then
  printf 'dry-run created target home: %s\n' "$DRY_HOME_DIR" >&2
  exit 1
fi

"$DEPLOY_SCRIPT" --apply --home "$HOME_DIR" >/dev/null

assert_link() {
  local path="$1"
  local expected="$2"

  if [ ! -L "$path" ]; then
    printf 'expected symlink: %s\n' "$path" >&2
    exit 1
  fi

  if [ "$(readlink "$path")" != "$expected" ]; then
    printf 'unexpected target for %s: %s\n' "$path" "$(readlink "$path")" >&2
    printf 'expected: %s\n' "$expected" >&2
    exit 1
  fi
}

assert_file() {
  [ -f "$1" ] || {
    printf 'expected file: %s\n' "$1" >&2
    exit 1
  }
}

assert_link "$HOME_DIR/.codex/skills/codex-dynamic-workflows/SKILL.md" "$ROOT_DIR/codex/skills/codex-dynamic-workflows/SKILL.md"
assert_link "$HOME_DIR/.codex/workflow/dynamic-workflow-triggers.md" "$ROOT_DIR/codex/workflow/dynamic-workflow-triggers.md"
assert_link "$HOME_DIR/.codex/workflow/skills/linear-work.md" "$ROOT_DIR/workflow/skills/linear-work.md"

assert_link "$HOME_DIR/.claude/CLAUDE.md" "$ROOT_DIR/claude/CLAUDE.md"
assert_link "$HOME_DIR/.claude/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.claude/commands/plan.md" "$ROOT_DIR/claude/commands/plan-create.md"
assert_link "$HOME_DIR/.claude/hooks/workflow-router.mjs" "$ROOT_DIR/claude/hooks/workflow-router.mjs"
assert_link "$HOME_DIR/.claude/hooks/workflow-router-lib.mjs" "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs"
assert_link "$HOME_DIR/.claude/hooks/plan-ready-guard.mjs" "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
assert_link "$HOME_DIR/.claude/hooks/plan-commit-guard.mjs" "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
assert_link "$HOME_DIR/.claude/hooks/detect-adr-signal.mjs" "$ROOT_DIR/claude/hooks/detect-adr-signal.mjs"
assert_link "$HOME_DIR/.claude/settings.workflow-hooks.json" "$ROOT_DIR/claude/settings.workflow-hooks.json"
assert_link "$HOME_DIR/.claude/skills/adr" "$ROOT_DIR/claude/skills/adr"

assert_link "$HOME_DIR/.pi/agent/AGENTS.md" "$ROOT_DIR/pi/AGENTS.md"
assert_link "$HOME_DIR/.pi/agent/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.pi/agent/extensions" "$ROOT_DIR/pi/extensions"
assert_link "$HOME_DIR/.pi/agent/skills/plan-loop" "$ROOT_DIR/pi/skills/plan-loop"
assert_link "$HOME_DIR/.pi/settings.json" "$ROOT_DIR/pi/settings.json"
assert_link "$HOME_DIR/.agents/skills/pr-review" "$ROOT_DIR/pi/skills/pr-review"
assert_link "$HOME_DIR/.agents/skills/browser-full-page-capture" "$ROOT_DIR/codex/skills/browser-full-page-capture"
assert_link "$HOME_DIR/.agents/skills/frontend-motion-performance" "$ROOT_DIR/codex/skills/frontend-motion-performance"
assert_link "$HOME_DIR/.agents/skills/goal-prompt-rewriter" "$ROOT_DIR/codex/skills/goal-prompt-rewriter"
assert_link "$HOME_DIR/.agents/skills/ui-reference-capture" "$ROOT_DIR/codex/skills/ui-reference-capture"
assert_file "$HOME_DIR/.pi/agent/settings.json"

node - "$HOME_DIR/.pi/agent/settings.json" <<'NODE'
const fs = require("node:fs");
const settings = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const packages = Array.isArray(settings.packages) ? settings.packages : [];

function sourceOf(entry) {
  if (typeof entry === "string") return entry;
  if (entry && typeof entry === "object") return entry.source;
  return null;
}

function hasObjectSource(source) {
  return packages.some((entry) => entry && typeof entry === "object" && entry.source === source);
}

if (!hasObjectSource("npm:@tintinweb/pi-subagents")) {
  throw new Error("missing scoped Pi subagents package");
}

if (!hasObjectSource("npm:@tintinweb/pi-tasks")) {
  throw new Error("missing scoped Pi tasks package");
}

if (packages.some((entry) => sourceOf(entry) === "npm:pi-subagents")) {
  throw new Error("legacy unscoped pi-subagents package was kept");
}
NODE

"$ROOT_DIR/scripts/deploy-codex" --dry-run --prefer-links --codex-home "$HOME_DIR/.codex" >/dev/null

printf 'deploy agent workflow smoke test: ok\n'
