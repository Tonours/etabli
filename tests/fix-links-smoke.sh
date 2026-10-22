#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
# asdf shims resolve node from HOME, which the fixtures replace.
PATH="$(dirname "$(node -e 'process.stdout.write(process.execPath)')"):$PATH"
TMP_HOME="$(cd -P "$(mktemp -d)" && pwd)"
CHECKOUT_LINK="$ROOT_DIR/pi/extensions/node_modules"

link_state() {
  node -e 'const fs = require("fs"); try { const s = fs.lstatSync(process.argv[1]); process.stdout.write(`${s.ino} ${s.mtimeMs} ${s.isSymbolicLink() ? fs.readlinkSync(process.argv[1]) : "not-a-link"}`); } catch { process.stdout.write("absent"); }' "$1"
}

CHECKOUT_LINK_BEFORE="$(link_state "$CHECKOUT_LINK")"
trap 'rm -rf "$TMP_HOME"' EXIT

# --fix links pi/extensions/node_modules inside the repo, so the positive cases
# run against a copy of the checkout's files, never the checkout itself.
REPO="$TMP_HOME/repo"
mkdir -p "$REPO"
git -C "$ROOT_DIR" ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' file; do
    if [ -e "$ROOT_DIR/$file" ] || [ -L "$ROOT_DIR/$file" ]; then printf '%s\0' "$file"; fi
  done |
  tar -C "$ROOT_DIR" --null -T - -cf - | tar -C "$REPO" -xf -
SCRIPT="$REPO/scripts/check-fix-symlinks.sh"

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
ln -s "$REPO/claude/agents/playwright-generator.md" "$TMP_HOME/.claude/agents/playwright-generator.md"
ln -s "$TMP_HOME/personal-agents/personal.md" "$TMP_HOME/.claude/agents/personal.md"
ln -s "$REPO/pi/skills/retired-skill" "$TMP_HOME/.claude/skills/retired-skill"
ln -s "$REPO/pi/skills/retired-skill" "$TMP_HOME/.pi/agent/skills/retired-skill"
ln -s "$REPO/pi/skills/github-pr-review" "$TMP_HOME/.pi/agent/skills/github-pr-review"
ln -s "$REPO/pi/skills/design" "$TMP_HOME/.pi/agent/skills/design"
ln -s "$REPO/pi/skills/verify" "$TMP_HOME/.pi/agent/skills/verify"
ln -s "$TMP_HOME/external-skill" "$TMP_HOME/.claude/skills/plan-loop"
mkdir -p "$TMP_HOME/.claude/commands"
ln -s "$REPO/claude/scopes/shared/commands/review.md" "$TMP_HOME/.claude/commands/review.md"
ln -s "$TMP_HOME/external-skill" "$TMP_HOME/.claude/commands/personal.md"

HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null
SECOND_CHECK_OUTPUT="$TMP_HOME/second-check.out"
if ! HOME="$TMP_HOME" "$SCRIPT" --verbose >"$SECOND_CHECK_OUTPUT"; then
  cat "$SECOND_CHECK_OUTPUT" >&2
  exit 1
fi

assert_link "$TMP_HOME/.pi/agent/skills/review" "$REPO/skills/shared/review"
assert_link "$TMP_HOME/.pi/agent/skills/plan-loop" "$REPO/skills/shared/plan-loop"
assert_link "$TMP_HOME/.pi/agent/skills/adversary" "$REPO/skills/shared/adversary"
assert_link "$TMP_HOME/.pi/agent/skills/implement" "$REPO/skills/shared/implement"
assert_link "$TMP_HOME/.pi/agent/skills/code-quality" "$REPO/skills/shared/code-quality"
assert_link "$TMP_HOME/.pi/agent/skills/verify-workflow" "$REPO/skills/shared/verify-workflow"
assert_not_exists "$TMP_HOME/.pi/agent/skills/verify"
assert_not_exists "$TMP_HOME/.pi/agent/skills/bug-check"
assert_not_exists "$TMP_HOME/.pi/agent/skills/linear-work"
assert_link "$TMP_HOME/.claude/skills/plan-loop" "$REPO/skills/shared/plan-loop"
assert_link "$TMP_HOME/.claude/skills/write-direct" "$REPO/skills/shared/write-direct"
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
assert_link "$TMP_HOME/.pi/agent/workflow" "$REPO/workflow"
assert_link "$TMP_HOME/.pi/agent/PLAN_TEMPLATE.md" "$REPO/PLAN_TEMPLATE.md"
assert_link "$TMP_HOME/.pi/agent/PLAN_TEMPLATE_FULL.md" "$REPO/PLAN_TEMPLATE_FULL.md"
assert_link "$REPO/pi/extensions/node_modules" "$TMP_HOME/.pi/agent/npm/node_modules"
assert_not_exists "$TMP_HOME/.claude/commands/review.md"
assert_link "$TMP_HOME/.claude/commands/personal.md" "$TMP_HOME/external-skill"
assert_link "$TMP_HOME/.claude/agents/scout.md" "$REPO/claude/scopes/shared/agents/scout.md"
assert_link "$TMP_HOME/.claude/agents/worker.md" "$REPO/claude/scopes/shared/agents/worker.md"
assert_link "$TMP_HOME/.claude/agents/reviewer.md" "$REPO/claude/scopes/shared/agents/reviewer.md"
assert_not_exists "$TMP_HOME/.claude/agents/playwright-generator.md"
assert_link "$TMP_HOME/.claude/agents/personal.md" "$TMP_HOME/personal-agents/personal.md"
assert_link "$TMP_HOME/.claude/hooks/read-only-agent-guard.mjs" "$REPO/claude/hooks/read-only-agent-guard.mjs"
assert_link "$TMP_HOME/.claude/workflow" "$REPO/workflow"
assert_link "$TMP_HOME/.claude/PLAN_TEMPLATE.md" "$REPO/PLAN_TEMPLATE.md"
assert_link "$TMP_HOME/.claude/PLAN_TEMPLATE_FULL.md" "$REPO/PLAN_TEMPLATE_FULL.md"
assert_not_exists "$TMP_HOME/.claude/skills/coolify"
assert_not_exists "$TMP_HOME/.claude/scripts/claude-bin.sh"

mkdir -p "$TMP_HOME/.claude/scripts"
ln -s "$TMP_HOME/personal-agents/personal.md" "$TMP_HOME/.claude/scripts/claude-bin.sh"
ln -s "$REPO/vendor/adonisjs-skills/skills/adonisjs-suite" "$TMP_HOME/.pi/agent/skills/adonisjs-suite"
ln -s "$REPO/vendor/adonisjs-skills/skills/adonisjs-suite" "$TMP_HOME/.claude/skills/adonisjs-suite"
ETABLI_SCOPE=work HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null
assert_not_exists "$TMP_HOME/.claude/skills/adr"
assert_link "$TMP_HOME/.claude/scripts/claude-bin.sh" "$REPO/claude/scopes/work/scripts/claude-bin.sh"
assert_link "$TMP_HOME/.claude/scripts/pr-review-watch" "$REPO/claude/scopes/work/scripts/pr-review-watch"
assert_link "$TMP_HOME/.claude/skills/linear-work" "$REPO/skills/work/linear-work"
assert_link "$TMP_HOME/.pi/agent/skills/linear-work" "$REPO/skills/work/linear-work"
assert_link "$TMP_HOME/.claude/skills/pr-council-review" "$REPO/skills/work/pr-council-review"
assert_not_exists "$TMP_HOME/.pi/agent/skills/pr-council-review"
assert_not_exists "$TMP_HOME/.pi/agent/skills/employer-backend-suite"
assert_link "$TMP_HOME/.claude/skills/employer-backend-suite" "$REPO/skills/work/employer-backend-suite"
assert_not_exists "$TMP_HOME/.pi/agent/skills/adonisjs-suite"
assert_not_exists "$TMP_HOME/.claude/skills/adonisjs-suite"

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
cp "$SCRIPT" "$ROOT_DIR/scripts/deploy-agent-workflow" "$FAKE_REPO/scripts/"
cp "$ROOT_DIR/scripts/lib/surfaces.mjs" "$FAKE_REPO/scripts/lib/surfaces.mjs"
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

if [ "$(link_state "$CHECKOUT_LINK")" != "$CHECKOUT_LINK_BEFORE" ]; then
  printf 'expected the checkout pi/extensions/node_modules to stay untouched: before %s, after %s\n' "$CHECKOUT_LINK_BEFORE" "$(link_state "$CHECKOUT_LINK")" >&2
  exit 1
fi

printf 'fix-links smoke test: ok\n'
