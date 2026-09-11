#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/scripts/lib/hash.sh"
DEPLOY_SCRIPT="$ROOT_DIR/scripts/deploy-agent-workflow"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="$TMP_DIR/home"
DRY_HOME_DIR="$TMP_DIR/dry-home"
WORK_HOME_DIR="$TMP_DIR/work-home"
mkdir -p "$HOME_DIR/.pi/agent" "$HOME_DIR/.claude/agents" "$HOME_DIR/.claude/skills" \
  "$HOME_DIR/.claude/commands" "$HOME_DIR/.codex/skills" \
  "$HOME_DIR/.config/devin/skills" \
  "$TMP_DIR/personal-agents" "$TMP_DIR/external-skill"
printf 'personal agent\n' >"$TMP_DIR/personal-agents/personal.md"
printf 'unmanaged skill\n' >"$HOME_DIR/.codex/skills/unmanaged-local"
printf 'unmanaged skill\n' >"$HOME_DIR/.config/devin/skills/unmanaged-local"
printf 'personal command\n' >"$HOME_DIR/.claude/commands/recap.md"
printf 'external command\n' >"$TMP_DIR/external-command.md"
ln -s "$ROOT_DIR/claude/agents/playwright-generator.md" "$HOME_DIR/.claude/agents/playwright-generator.md"
ln -s "$TMP_DIR/personal-agents/personal.md" "$HOME_DIR/.claude/agents/personal.md"
ln -s "$TMP_DIR/external-command.md" "$HOME_DIR/.claude/commands/commit.md"
ln -s "$ROOT_DIR/claude/commands/plan.md" "$HOME_DIR/.claude/commands/plan.md"
ln -s "$ROOT_DIR/claude/scopes/shared/commands/front-quality.md" "$HOME_DIR/.claude/commands/front-quality.md"
ln -s "$ROOT_DIR/claude/handoff-template.md" "$HOME_DIR/.claude/handoff-template.md"
ln -s "$ROOT_DIR/pi/skills/suite-router" "$HOME_DIR/.claude/skills/suite-router"
ln -s "$ROOT_DIR/pi/skills/suite-router" "$HOME_DIR/.codex/skills/suite-router"
ln -s "$TMP_DIR/external-skill" "$HOME_DIR/.codex/skills/external-skill"
ln -s "$ROOT_DIR/pi/skills/suite-router" "$HOME_DIR/.config/devin/skills/suite-router"
ln -s "$TMP_DIR/external-skill" "$HOME_DIR/.config/devin/skills/external-skill"

printf '%s\n' '{
  "defaultProvider": "kimi-for-coding",
  "defaultModel": "kimi-k2.6",
  "defaultThinkingLevel": "high",
  "enabledModels": [
    "custom/provider-model",
    "openai-codex/gpt-5.6",
    "openai-codex/gpt-5.6-luna",
    "openai-codex/gpt-5.6-terra",
    "openai-codex/gpt-5.6-sol"
  ],
  "packages": [
    "npm:@agwab/pi-workflow",
    {
      "source": "npm:@agwab/pi-workflow@0.7.0"
    },
    {
      "source": "npm:@agwab/pi-workflow-helper"
    },
    {
      "source": "npm:pi-subagents"
    }
  ]
}' >"$HOME_DIR/.pi/agent/settings.json"

grep -Fq '. "$SCRIPT_DIR/lib/pi-paths.sh"' "$DEPLOY_SCRIPT" &&
  grep -Fq 'pi_agent_node_modules_dir "$HOME_DIR"' "$DEPLOY_SCRIPT" || {
  printf 'deploy script must use the shared Pi path helper\n' >&2
  exit 1
}

# The dry-run probe touches only DRY_HOME_DIR, so it overlaps the shared-home
# setup instead of blocking it.
"$DEPLOY_SCRIPT" --dry-run --home "$DRY_HOME_DIR" >/dev/null &
DRY_RUN_PID=$!

mkdir -p "$HOME_DIR/.agents/skills"
ln -s "$ROOT_DIR/pi/skills/suite-router" "$HOME_DIR/.agents/skills/suite-router"

# Scope validation fails before any home inspection, so the bogus-scope probe
# can run concurrently with the shared-home apply below.
(
  if ETABLI_SCOPE=bogus "$ROOT_DIR/scripts/deploy-agent-workflow" --dry-run --home "$DRY_HOME_DIR" >/dev/null 2>&1; then
    printf 'deploy accepted an invalid ETABLI_SCOPE instead of failing\n' >&2
    exit 1
  fi
) &
BOGUS_SCOPE_PID=$!

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

assert_absent() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    printf 'expected path to be absent: %s\n' "$1" >&2
    exit 1
  fi
}

assert_link "$HOME_DIR/.claude/CLAUDE.md" "$ROOT_DIR/claude/CLAUDE.md"
assert_link "$HOME_DIR/.claude/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.claude/PLAN_TEMPLATE.md" "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_link "$HOME_DIR/.claude/PLAN_TEMPLATE_FULL.md" "$ROOT_DIR/PLAN_TEMPLATE_FULL.md"
assert_link "$HOME_DIR/.claude/commands/plan-loop.md" "$ROOT_DIR/claude/scopes/shared/commands/plan-loop.md"
assert_absent "$HOME_DIR/.claude/commands/plan.md"
assert_absent "$HOME_DIR/.claude/commands/front-quality.md"
assert_absent "$HOME_DIR/.claude/handoff-template.md"
assert_file "$HOME_DIR/.claude/commands/recap.md"
grep -Fxq 'personal command' "$HOME_DIR/.claude/commands/recap.md"
assert_link "$HOME_DIR/.claude/commands/commit.md" "$TMP_DIR/external-command.md"
assert_link "$HOME_DIR/.claude/hooks/workflow-router-lib.mjs" "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs"
assert_link "$HOME_DIR/.claude/hooks/plan-ready-guard.mjs" "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
assert_link "$HOME_DIR/.claude/hooks/plan-commit-guard.mjs" "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
assert_link "$HOME_DIR/.claude/hooks/detect-adr-signal.mjs" "$ROOT_DIR/claude/hooks/detect-adr-signal.mjs"
assert_link "$HOME_DIR/.claude/hooks/ledger-auto-emit.mjs" "$ROOT_DIR/claude/hooks/ledger-auto-emit.mjs"
assert_link "$HOME_DIR/.claude/hooks/outcome-metric-emit.mjs" "$ROOT_DIR/claude/hooks/outcome-metric-emit.mjs"
assert_link "$HOME_DIR/.claude/hooks/read-only-agent-guard.mjs" "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs"
assert_link "$HOME_DIR/.claude/settings.workflow-hooks.json" "$ROOT_DIR/claude/settings.workflow-hooks.json"
assert_link "$HOME_DIR/.claude/skills/adr" "$ROOT_DIR/claude/scopes/shared/skills/adr"
assert_link "$HOME_DIR/.claude/skills/frontend-css-ui-ux" "$ROOT_DIR/claude/scopes/shared/skills/frontend-css-ui-ux"
assert_link "$HOME_DIR/.claude/skills/css-layout-primitives" "$ROOT_DIR/claude/scopes/shared/skills/css-layout-primitives"
assert_link "$HOME_DIR/.claude/skills/css-only-components" "$ROOT_DIR/claude/scopes/shared/skills/css-only-components"
assert_link "$HOME_DIR/.claude/skills/css-debugging" "$ROOT_DIR/claude/scopes/shared/skills/css-debugging"
assert_absent "$HOME_DIR/.claude/skills/react-doctor-100"
assert_absent "$HOME_DIR/.claude/skills/suite-router"
assert_absent "$HOME_DIR/.claude/skills/vercel-react-best-practices"
assert_absent "$HOME_DIR/.claude/skills/vercel-composition-patterns"
assert_link "$HOME_DIR/.claude/agents/scout.md" "$ROOT_DIR/claude/scopes/shared/agents/scout.md"
assert_link "$HOME_DIR/.claude/agents/worker.md" "$ROOT_DIR/claude/scopes/shared/agents/worker.md"
assert_link "$HOME_DIR/.claude/agents/reviewer.md" "$ROOT_DIR/claude/scopes/shared/agents/reviewer.md"
assert_absent "$HOME_DIR/.claude/agents/playwright-generator.md"
assert_link "$HOME_DIR/.claude/agents/personal.md" "$TMP_DIR/personal-agents/personal.md"
assert_absent "$HOME_DIR/.claude/scripts/claude-bin.sh"
assert_absent "$HOME_DIR/.claude/skills/ember-employer-suite"
assert_absent "$HOME_DIR/.claude/skills/adonisjs-suite"

assert_absent "$HOME_DIR/.codex/skills/react-doctor-100"
assert_absent "$HOME_DIR/.codex/skills/suite-router"
assert_absent "$HOME_DIR/.codex/skills/vercel-react-best-practices"
assert_absent "$HOME_DIR/.codex/skills/vercel-composition-patterns"
assert_file "$HOME_DIR/.codex/skills/unmanaged-local"
assert_link "$HOME_DIR/.codex/skills/external-skill" "$TMP_DIR/external-skill"
assert_absent "$HOME_DIR/.codex/skills/ember-employer-suite"
assert_absent "$HOME_DIR/.codex/skills/adonisjs-suite"

assert_absent "$HOME_DIR/.config/devin/skills/react-doctor-100"
assert_absent "$HOME_DIR/.config/devin/skills/suite-router"
assert_absent "$HOME_DIR/.config/devin/skills/vercel-react-best-practices"
assert_file "$HOME_DIR/.config/devin/skills/unmanaged-local"
assert_link "$HOME_DIR/.config/devin/skills/external-skill" "$TMP_DIR/external-skill"
assert_link "$HOME_DIR/.config/devin/skills/ask-matt" "$ROOT_DIR/vendor/mattpocock/skills/engineering/ask-matt"
assert_absent "$HOME_DIR/.config/devin/skills/ember-employer-suite"
assert_absent "$HOME_DIR/.config/devin/skills/adonisjs-suite"

if [ -e "$HOME_DIR/.claude/skills/ember-employer-suite" ]; then
  printf 'work-scope skill deployed without a declared scope: %s\n' \
    "$HOME_DIR/.claude/skills/ember-employer-suite" >&2
  exit 1
fi

# The work-scope deploy only touches WORK_HOME_DIR, so it runs concurrently
# with the shared-home assertions; its failures propagate through wait.
(
  mkdir -p \
    "$WORK_HOME_DIR/.pi/agent/skills" \
    "$WORK_HOME_DIR/.claude/skills" \
    "$WORK_HOME_DIR/.codex/skills" \
    "$WORK_HOME_DIR/.config/devin/skills" \
    "$WORK_HOME_DIR/.agents/skills" \
    "$WORK_HOME_DIR/external-skill"
  ln -s "$ROOT_DIR/vendor/adonisjs-skills/skills/adonisjs-suite" "$WORK_HOME_DIR/.pi/agent/skills/adonisjs-suite"
  ln -s "$ROOT_DIR/vendor/adonisjs-skills/skills/adonisjs-suite" "$WORK_HOME_DIR/.claude/skills/adonisjs-suite"
  ln -s "$ROOT_DIR/vendor/adonisjs-skills/skills/adonisjs-suite" "$WORK_HOME_DIR/.codex/skills/adonisjs-suite"
  ln -s "$ROOT_DIR/vendor/adonisjs-skills/skills/adonisjs-suite" "$WORK_HOME_DIR/.config/devin/skills/adonisjs-suite"
  ln -s "$ROOT_DIR/vendor/adonisjs-skills/skills/adonisjs-suite" "$WORK_HOME_DIR/.agents/skills/adonisjs-suite"
  ln -s "$WORK_HOME_DIR/external-skill" "$WORK_HOME_DIR/.codex/skills/adonisjs-review"

  ETABLI_SCOPE=work "$DEPLOY_SCRIPT" --apply --home "$WORK_HOME_DIR" >/dev/null
  assert_link "$WORK_HOME_DIR/.claude/scripts/claude-bin.sh" "$ROOT_DIR/claude/scopes/work/scripts/claude-bin.sh"
  assert_link "$WORK_HOME_DIR/.claude/scripts/pr-autoreview" "$ROOT_DIR/claude/scopes/work/scripts/pr-autoreview"
  assert_link "$WORK_HOME_DIR/.claude/scripts/routines" "$ROOT_DIR/claude/scopes/work/scripts/routines"
  assert_link "$WORK_HOME_DIR/.claude/scripts/sessions-report-inner.sh" "$ROOT_DIR/claude/scopes/work/scripts/sessions-report-inner.sh"
  assert_link "$WORK_HOME_DIR/.claude/scripts/sessions-report-prompt.md" "$ROOT_DIR/claude/scopes/work/scripts/sessions-report-prompt.md"
  assert_link "$WORK_HOME_DIR/.claude/scripts/sessions-report.sh" "$ROOT_DIR/claude/scopes/work/scripts/sessions-report.sh"
  assert_link "$WORK_HOME_DIR/.claude/skills/ember-employer-suite" "$ROOT_DIR/vendor/ember-skills/skills/ember-employer-suite"
  assert_link "$WORK_HOME_DIR/.codex/skills/ember-employer-suite" "$ROOT_DIR/vendor/ember-skills/skills/ember-employer-suite"
  assert_link "$WORK_HOME_DIR/.config/devin/skills/ember-employer-suite" "$ROOT_DIR/vendor/ember-skills/skills/ember-employer-suite"
  assert_absent "$WORK_HOME_DIR/.pi/agent/skills/ember-employer-suite"
  assert_absent "$WORK_HOME_DIR/.pi/agent/skills/adonisjs-suite"
  assert_absent "$WORK_HOME_DIR/.claude/skills/adonisjs-suite"
  assert_absent "$WORK_HOME_DIR/.codex/skills/adonisjs-suite"
  assert_absent "$WORK_HOME_DIR/.config/devin/skills/adonisjs-suite"
  assert_absent "$WORK_HOME_DIR/.agents/skills/adonisjs-suite"
  assert_link "$WORK_HOME_DIR/.codex/skills/adonisjs-review" "$WORK_HOME_DIR/external-skill"
  assert_absent "$WORK_HOME_DIR/.grok"

  if find "$WORK_HOME_DIR/.codex" -mindepth 1 -maxdepth 1 ! -name skills | grep -q .; then
    printf 'deploy created a Codex harness surface beyond skills\n' >&2
    exit 1
  fi

  if find "$WORK_HOME_DIR/.config/devin" -mindepth 1 -maxdepth 1 ! -name skills | grep -q .; then
    printf 'deploy created a Devin harness surface beyond skills\n' >&2
    exit 1
  fi
) &
WORK_SCOPE_PID=$!

assert_link "$HOME_DIR/.pi/agent/AGENTS.md" "$ROOT_DIR/pi/AGENTS.md"
assert_link "$HOME_DIR/.pi/agent/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.pi/agent/PLAN_TEMPLATE.md" "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_link "$HOME_DIR/.pi/agent/PLAN_TEMPLATE_FULL.md" "$ROOT_DIR/PLAN_TEMPLATE_FULL.md"
assert_link "$HOME_DIR/.pi/agent/extensions" "$ROOT_DIR/pi/extensions"
assert_link "$HOME_DIR/.pi/agent/subagents.json" "$ROOT_DIR/pi/agent/subagents.json"
assert_link "$HOME_DIR/.pi/agent/agents/Explore.md" "$ROOT_DIR/pi/agents/Explore.md"
assert_link "$HOME_DIR/.pi/agent/skills/plan-loop" "$ROOT_DIR/pi/skills/plan-loop"
assert_absent "$HOME_DIR/.pi/agent/skills/vercel-react-best-practices"
assert_link "$HOME_DIR/.pi/settings.json" "$ROOT_DIR/pi/settings.json"
assert_link "$HOME_DIR/.agents/PLAN_TEMPLATE.md" "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_link "$HOME_DIR/.agents/PLAN_TEMPLATE_FULL.md" "$ROOT_DIR/PLAN_TEMPLATE_FULL.md"
assert_link "$HOME_DIR/.agents/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.agents/skills/pr-review" "$ROOT_DIR/pi/skills/pr-review"
assert_link "$HOME_DIR/.agents/skills/review" "$ROOT_DIR/pi/skills/review"
assert_absent "$HOME_DIR/.agents/skills/browser-full-page-capture"
assert_absent "$HOME_DIR/.agents/skills/goal-prompt-rewriter"
assert_absent "$HOME_DIR/.agents/skills/github-pr-review"
assert_absent "$HOME_DIR/.agents/skills/suite-router"
assert_absent "$HOME_DIR/.agents/skills/linear-project-setup"
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

function packageBySource(source) {
  return packages.find((entry) => entry && typeof entry === "object" && entry.source === source);
}

if (!hasObjectSource("npm:@tintinweb/pi-tasks@0.7.1")) {
  throw new Error("missing scoped Pi tasks package");
}

if (packages.some((entry) => typeof entry === "string" && entry === "npm:pi-subagents") ||
    packages.some((entry) => {
      const source = sourceOf(entry);
      return typeof source === "string" && source.startsWith("npm:@tintinweb/pi-subagents");
    })) {
  throw new Error("pi-subagents must converge to the tracked object entry, tintinweb variants dropped");
}

const piSubagents = packageBySource("npm:pi-subagents");
if (!piSubagents || JSON.stringify(piSubagents.skills) !== "[]") {
  throw new Error("tracked npm:pi-subagents entry missing or not skill-silenced");
}

if (!hasObjectSource("npm:@zenspc/pi-pstack")) {
  throw new Error("tracked npm:@zenspc/pi-pstack entry missing");
}

if (!Array.isArray(settings.skills) || !settings.skills.every((pattern) => pattern.startsWith("!"))) {
  throw new Error("top-level skills deny-list missing or not deny-only");
}

if (packages.some((entry) => sourceOf(entry) === "npm:@tintinweb/pi-tasks")) {
  throw new Error("unpinned Pi tasks package was kept");
}

if (packages.some((entry) => {
  const source = sourceOf(entry);
  return typeof source === "string" &&
    (source === "npm:@agwab/pi-workflow" || source.startsWith("npm:@agwab/pi-workflow@"));
})) {
  throw new Error("removed pi-workflow package source was kept");
}

if (!hasObjectSource("npm:@agwab/pi-workflow-helper")) {
  throw new Error("unrelated package with a similar prefix was removed");
}

if (settings.defaultProvider !== "kimi-for-coding" ||
    settings.defaultModel !== "kimi-k2.6" ||
    settings.defaultThinkingLevel !== "high") {
  throw new Error("local Pi defaults were overwritten");
}

const enabledModels = Array.isArray(settings.enabledModels) ? settings.enabledModels : [];
for (const model of [
  "custom/provider-model",
  "zai/glm-5.2",
]) {
  if (!enabledModels.includes(model)) throw new Error(`missing preserved or managed model: ${model}`);
}
// Bare gpt-5.6 alias remains retired.
if (enabledModels.includes("openai-codex/gpt-5.6")) {
  throw new Error("legacy bare openai-codex/gpt-5.6 alias was kept");
}
NODE

settings_before="$(hash256 "$HOME_DIR/.pi/agent/settings.json" | awk '{print $1}')"
"$DEPLOY_SCRIPT" --apply --home "$HOME_DIR" >/dev/null
settings_after="$(hash256 "$HOME_DIR/.pi/agent/settings.json" | awk '{print $1}')"
if [ "$settings_before" != "$settings_after" ]; then
  printf 'second deploy changed Pi settings; sync is not idempotent\n' >&2
  exit 1
fi

SECOND_DRY_RUN_OUTPUT="$TMP_DIR/second-dry-run.out"
"$DEPLOY_SCRIPT" --dry-run --home "$HOME_DIR" >"$SECOND_DRY_RUN_OUTPUT"
if grep -q '^WOULD_' "$SECOND_DRY_RUN_OUTPUT"; then
  printf 'second deploy dry run still reports drift\n' >&2
  cat "$SECOND_DRY_RUN_OUTPUT" >&2
  exit 1
fi

wait "$DRY_RUN_PID"
if [ -e "$DRY_HOME_DIR" ]; then
  printf 'dry-run created target home: %s\n' "$DRY_HOME_DIR" >&2
  exit 1
fi

wait "$BOGUS_SCOPE_PID"
wait "$WORK_SCOPE_PID"

printf 'deploy agent workflow smoke test: ok\n'
