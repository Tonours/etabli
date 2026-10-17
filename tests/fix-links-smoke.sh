#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/check-fix-symlinks.sh"
TMP_HOME="$(mktemp -d)"
ORIGINAL_NODE_MODULES_TARGET=""
ORIGINAL_NODE_MODULES_EXISTS=0

if [ -L "$ROOT_DIR/pi/extensions/node_modules" ]; then
  ORIGINAL_NODE_MODULES_EXISTS=1
  ORIGINAL_NODE_MODULES_TARGET="$(readlink "$ROOT_DIR/pi/extensions/node_modules")"
fi

cleanup() {
  if [ "$ORIGINAL_NODE_MODULES_EXISTS" -eq 1 ]; then
    ln -sfn "$ORIGINAL_NODE_MODULES_TARGET" "$ROOT_DIR/pi/extensions/node_modules"
  else
    rm -f "$ROOT_DIR/pi/extensions/node_modules"
  fi
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

assert_link() {
  local link_path="$1"
  local target_path="$2"

  if [ ! -L "$link_path" ]; then
    printf 'expected symlink: %s\n' "$link_path" >&2
    exit 1
  fi

  if [ "$(readlink "$link_path")" != "$target_path" ]; then
    printf 'expected %s -> %s, got %s\n' "$link_path" "$target_path" "$(readlink "$link_path")" >&2
    exit 1
  fi
}

assert_not_exists() {
  { [ ! -e "$1" ] && [ ! -L "$1" ]; } || {
    printf 'expected path not to exist: %s\n' "$1" >&2
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

backup_count() {
  find "$(dirname "$1")" -maxdepth 1 -name "$(basename "$1").bak.*" | wc -l | tr -d ' '
}

mkdir -p "$TMP_HOME/.pi/agent/npm/node_modules" "$TMP_HOME/.pi/agent/skills"
mkdir -p "$TMP_HOME/.claude/agents" "$TMP_HOME/.claude/skills" \
  "$TMP_HOME/personal-agents" "$TMP_HOME/external-skill"
printf 'personal agent\n' >"$TMP_HOME/personal-agents/personal.md"
ln -s "$ROOT_DIR/claude/agents/playwright-generator.md" "$TMP_HOME/.claude/agents/playwright-generator.md"
ln -s "$TMP_HOME/personal-agents/personal.md" "$TMP_HOME/.claude/agents/personal.md"
ln -s "$ROOT_DIR/pi/skills/retired-skill" "$TMP_HOME/.claude/skills/retired-skill"
ln -s "$ROOT_DIR/pi/skills/retired-skill" "$TMP_HOME/.pi/agent/skills/retired-skill"
ln -s "$ROOT_DIR/pi/skills/github-pr-review" "$TMP_HOME/.pi/agent/skills/github-pr-review"
ln -s "$ROOT_DIR/pi/skills/design" "$TMP_HOME/.pi/agent/skills/design"
ln -s "$ROOT_DIR/pi/skills/verify" "$TMP_HOME/.pi/agent/skills/verify"
ln -s "$TMP_HOME/external-skill" "$TMP_HOME/.claude/skills/plan-loop"
mkdir -p "$TMP_HOME/.claude/commands"
ln -s "$ROOT_DIR/claude/scopes/shared/commands/review.md" "$TMP_HOME/.claude/commands/review.md"
ln -s "$TMP_HOME/external-skill" "$TMP_HOME/.claude/commands/personal.md"

HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null
SECOND_CHECK_OUTPUT="$TMP_HOME/second-check.out"
if ! HOME="$TMP_HOME" "$SCRIPT" --verbose >"$SECOND_CHECK_OUTPUT"; then
  cat "$SECOND_CHECK_OUTPUT" >&2
  exit 1
fi

assert_link "$TMP_HOME/.pi/agent/skills/review" "$ROOT_DIR/skills/shared/review"
assert_link "$TMP_HOME/.pi/agent/skills/plan-loop" "$ROOT_DIR/skills/shared/plan-loop"
assert_link "$TMP_HOME/.pi/agent/skills/adversary" "$ROOT_DIR/skills/shared/adversary"
assert_link "$TMP_HOME/.pi/agent/skills/implement" "$ROOT_DIR/skills/shared/implement"
assert_link "$TMP_HOME/.pi/agent/skills/code-quality" "$ROOT_DIR/skills/shared/code-quality"
assert_link "$TMP_HOME/.pi/agent/skills/verify-workflow" "$ROOT_DIR/skills/shared/verify-workflow"
assert_not_exists "$TMP_HOME/.pi/agent/skills/verify"
assert_not_exists "$TMP_HOME/.pi/agent/skills/bug-check"
assert_not_exists "$TMP_HOME/.pi/agent/skills/linear-work"
assert_link "$TMP_HOME/.claude/skills/plan-loop" "$ROOT_DIR/skills/shared/plan-loop"
assert_link "$TMP_HOME/.claude/skills/write-direct" "$ROOT_DIR/skills/shared/write-direct"
assert_not_exists "$TMP_HOME/.claude/skills/linear-work"
# --fix moves a foreign link aside, outside the discovery root, never deletes it.
foreign_backups=( "$TMP_HOME/.claude/skills.bak"/plan-loop.bak.* )
[ "$(readlink "${foreign_backups[0]}")" = "$TMP_HOME/external-skill" ] || {
  printf 'expected --fix to keep the foreign plan-loop link in skills.bak\n' >&2
  exit 1
}
if find "$TMP_HOME/.claude/skills" -maxdepth 1 -name '*.bak.*' | grep -q .; then
  printf 'expected no backup inside the Claude skill discovery root\n' >&2
  exit 1
fi
assert_not_exists "$TMP_HOME/.pi/agent/skills/vercel-react-best-practices"
assert_not_exists "$TMP_HOME/.pi/agent/skills/github-pr-review"
assert_not_exists "$TMP_HOME/.pi/agent/skills/retired-skill"
assert_not_exists "$TMP_HOME/.pi/agent/skills/design"
assert_not_exists "$TMP_HOME/.claude/skills/frontend-css-ui-ux"
assert_not_exists "$TMP_HOME/.claude/skills/css-layout-primitives"
assert_not_exists "$TMP_HOME/.claude/skills/css-only-components"
assert_not_exists "$TMP_HOME/.claude/skills/css-debugging"
assert_not_exists "$TMP_HOME/.claude/skills/react-doctor-100"
assert_not_exists "$TMP_HOME/.claude/skills/retired-skill"
assert_not_exists "$TMP_HOME/.claude/skills/vercel-react-best-practices"
assert_not_exists "$TMP_HOME/.grok"
assert_link "$TMP_HOME/.pi/agent/workflow" "$ROOT_DIR/workflow"
assert_link "$TMP_HOME/.pi/agent/PLAN_TEMPLATE.md" "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_link "$TMP_HOME/.pi/agent/PLAN_TEMPLATE_FULL.md" "$ROOT_DIR/PLAN_TEMPLATE_FULL.md"
assert_link "$ROOT_DIR/pi/extensions/node_modules" "$TMP_HOME/.pi/agent/npm/node_modules"
assert_not_exists "$TMP_HOME/.claude/commands/review.md"
assert_link "$TMP_HOME/.claude/commands/personal.md" "$TMP_HOME/external-skill"
assert_link "$TMP_HOME/.claude/agents/scout.md" "$ROOT_DIR/claude/scopes/shared/agents/scout.md"
assert_link "$TMP_HOME/.claude/agents/worker.md" "$ROOT_DIR/claude/scopes/shared/agents/worker.md"
assert_link "$TMP_HOME/.claude/agents/reviewer.md" "$ROOT_DIR/claude/scopes/shared/agents/reviewer.md"
assert_not_exists "$TMP_HOME/.claude/agents/playwright-generator.md"
assert_link "$TMP_HOME/.claude/agents/personal.md" "$TMP_HOME/personal-agents/personal.md"
assert_link "$TMP_HOME/.claude/hooks/read-only-agent-guard.mjs" "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs"
assert_link "$TMP_HOME/.claude/workflow" "$ROOT_DIR/workflow"
assert_link "$TMP_HOME/.claude/PLAN_TEMPLATE.md" "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_link "$TMP_HOME/.claude/PLAN_TEMPLATE_FULL.md" "$ROOT_DIR/PLAN_TEMPLATE_FULL.md"
assert_not_exists "$TMP_HOME/.claude/skills/coolify"
assert_not_exists "$TMP_HOME/.claude/scripts/claude-bin.sh"

mkdir -p "$TMP_HOME/.claude/scripts"
ln -s "$TMP_HOME/personal-agents/personal.md" "$TMP_HOME/.claude/scripts/claude-bin.sh"
ln -s "$ROOT_DIR/vendor/adonisjs-skills/skills/adonisjs-suite" "$TMP_HOME/.pi/agent/skills/adonisjs-suite"
ln -s "$ROOT_DIR/vendor/adonisjs-skills/skills/adonisjs-suite" "$TMP_HOME/.claude/skills/adonisjs-suite"
ETABLI_SCOPE=work HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null
assert_not_exists "$TMP_HOME/.claude/skills/adr"
assert_link "$TMP_HOME/.claude/scripts/claude-bin.sh" "$ROOT_DIR/claude/scopes/work/scripts/claude-bin.sh"
assert_link "$TMP_HOME/.claude/scripts/pr-review-watch" "$ROOT_DIR/claude/scopes/work/scripts/pr-review-watch"
assert_link "$TMP_HOME/.claude/skills/linear-work" "$ROOT_DIR/skills/work/linear-work"
assert_link "$TMP_HOME/.pi/agent/skills/linear-work" "$ROOT_DIR/skills/work/linear-work"
assert_link "$TMP_HOME/.claude/skills/pr-council-review" "$ROOT_DIR/skills/work/pr-council-review"
assert_not_exists "$TMP_HOME/.pi/agent/skills/pr-council-review"
assert_not_exists "$TMP_HOME/.pi/agent/skills/employer-backend-suite"
assert_link "$TMP_HOME/.claude/skills/employer-backend-suite" "$ROOT_DIR/skills/work/employer-backend-suite"
assert_not_exists "$TMP_HOME/.pi/agent/skills/adonisjs-suite"
assert_not_exists "$TMP_HOME/.claude/skills/adonisjs-suite"

mkdir -p "$TMP_HOME/.grok/bin"
printf 'grok-bin\n' >"$TMP_HOME/.grok/bin/grok-macos"
ln -s grok-macos "$TMP_HOME/.grok/bin/grok"
ln -s grok-macos "$TMP_HOME/.grok/bin/agent"
HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null
assert_not_exists "$TMP_HOME/.grok/bin/agent"
if [ ! -L "$TMP_HOME/.grok/bin/grok" ]; then
  printf 'expected ~/.grok/bin/grok to remain after removing colliding agent\n' >&2
  exit 1
fi

mkdir -p "$TMP_HOME/.pi/extensions"
printf 'legacy extension\n' >"$TMP_HOME/.pi/extensions/legacy.txt"
HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null
assert_not_exists "$TMP_HOME/.pi/extensions"

if [ "$(backup_count "$TMP_HOME/.pi/extensions")" -lt 1 ]; then
  printf 'expected legacy ~/.pi/extensions to be backed up before removal\n' >&2
  exit 1
fi

rm "$TMP_HOME/.pi/settings.json"
printf 'custom one\n' >"$TMP_HOME/.pi/settings.json"
HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null

rm "$TMP_HOME/.pi/settings.json"
printf 'custom two\n' >"$TMP_HOME/.pi/settings.json"
HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null

if [ "$(backup_count "$TMP_HOME/.pi/settings.json")" -lt 2 ]; then
  printf 'expected repeated fixes to keep distinct settings.json backups\n' >&2
  exit 1
fi

FAKE_REPO="$TMP_HOME/fake-repo"
FAKE_HOME="$TMP_HOME/fake-home"
MISSING_SOURCE_OUTPUT="$TMP_HOME/missing-source.out"
mkdir -p "$FAKE_REPO/scripts/lib" "$FAKE_HOME/.claude/skills"
cp "$SCRIPT" "$FAKE_REPO/scripts/check-fix-symlinks.sh"
cp "$ROOT_DIR/scripts/lib/pi-paths.sh" "$FAKE_REPO/scripts/lib/pi-paths.sh"
cp "$ROOT_DIR/scripts/lib/claude-config-dir.sh" "$FAKE_REPO/scripts/lib/claude-config-dir.sh"
cp "$ROOT_DIR/scripts/lib/etabli-scope.sh" "$FAKE_REPO/scripts/lib/etabli-scope.sh"
cp "$ROOT_DIR/scripts/lib/prefer-cursor-agent.sh" "$FAKE_REPO/scripts/lib/prefer-cursor-agent.sh"
cp "$ROOT_DIR/scripts/lib/managed-surfaces.sh" "$FAKE_REPO/scripts/lib/managed-surfaces.sh"
chmod +x "$FAKE_REPO/scripts/check-fix-symlinks.sh"
ln -s "$FAKE_REPO/pi/skills/ghost" "$FAKE_HOME/.claude/skills/ghost"

if HOME="$FAKE_HOME" "$FAKE_REPO/scripts/check-fix-symlinks.sh" --fix --verbose >"$MISSING_SOURCE_OUTPUT" 2>&1; then
  printf 'expected --fix to fail when repo sources are missing\n' >&2
  exit 1
fi

assert_contains "$MISSING_SOURCE_OUTPUT" "source missing"
assert_contains "$MISSING_SOURCE_OUTPUT" "script deploy-workflow source missing"
assert_contains "$MISSING_SOURCE_OUTPUT" "unresolved"
assert_not_exists "$FAKE_HOME/.config/nvim"
assert_not_exists "$FAKE_HOME/.claude/skills/ghost"

# A failed backup aborts the repair: the user's entry is never replaced.
BLOCKED_HOME="$TMP_HOME/blocked-backup"
mkdir -p "$BLOCKED_HOME/skills"
printf 'mine\n' >"$BLOCKED_HOME/skills/plan-loop"
printf 'not a directory\n' >"$BLOCKED_HOME/skills.bak"
if (
  FIX=1 TIMESTAMP=smoke ISSUES=0 FIXED=0 REPO_DIR="$ROOT_DIR"
  . "$ROOT_DIR/scripts/lib/managed-surfaces.sh"
  managed_surface_reconcile_link check "$ROOT_DIR/skills/shared/plan-loop" "$BLOCKED_HOME/skills/plan-loop" "blocked plan-loop"
) >/dev/null 2>&1; then
  printf 'expected --fix to fail when the backup cannot be written\n' >&2
  exit 1
fi
[ -f "$BLOCKED_HOME/skills/plan-loop" ] && [ ! -L "$BLOCKED_HOME/skills/plan-loop" ] || {
  printf 'failed backup still replaced the user entry\n' >&2
  exit 1
}

# A target that only looks like the checkout (`$REPO_DIR/../x`) is foreign:
# --fix moves it aside instead of deleting it.
ESCAPE_HOME="$TMP_HOME/escape-link"
mkdir -p "$ESCAPE_HOME/skills"
ln -s "$ROOT_DIR/../personal-skill" "$ESCAPE_HOME/skills/plan-loop"
(
  FIX=1 TIMESTAMP=smoke ISSUES=0 FIXED=0 REPO_DIR="$ROOT_DIR"
  . "$ROOT_DIR/scripts/lib/managed-surfaces.sh"
  managed_surface_reconcile_link check "$ROOT_DIR/skills/shared/plan-loop" "$ESCAPE_HOME/skills/plan-loop" "escape plan-loop"
) >/dev/null
[ "$(readlink "$ESCAPE_HOME/skills.bak/plan-loop.bak.smoke")" = "$ROOT_DIR/../personal-skill" ] || {
  printf 'expected --fix to move a ..-escaping link aside\n' >&2
  exit 1
}
ln -s "$ROOT_DIR/skills/../../personal-skill" "$ESCAPE_HOME/skills/personal"
mkdir -p "$ESCAPE_HOME/.claude"
ln -s "$ESCAPE_HOME/skills" "$ESCAPE_HOME/.claude/skills"
(
  FIX=1 ISSUES=0 FIXED=0 REPO_DIR="$ROOT_DIR" MANAGED_CLAUDE_ROOT="$ESCAPE_HOME/.claude"
  . "$ROOT_DIR/scripts/lib/skill-catalog.sh"
  . "$ROOT_DIR/scripts/lib/managed-surfaces.sh"
  managed_surface_prune_skill_links check "$ROOT_DIR" "$ESCAPE_HOME" "$ROOT_DIR/workflow/runtime/skill-surface.tsv" "shared"
) >/dev/null
[ -L "$ESCAPE_HOME/skills/personal" ] || {
  printf 'orphan prune deleted a ..-escaping foreign link\n' >&2
  exit 1
}

printf 'fix-links smoke test: ok\n'
