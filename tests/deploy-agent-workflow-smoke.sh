#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DEPLOY_SCRIPT="$ROOT_DIR/scripts/deploy-agent-workflow"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="$TMP_DIR/home"
DRY_HOME_DIR="$TMP_DIR/dry-home"
mkdir -p "$HOME_DIR/.pi/agent"

node - "$HOME_DIR/.pi/agent/settings.json" <<'NODE'
const fs = require("node:fs");
const path = process.argv[2];
fs.writeFileSync(path, `${JSON.stringify({
  defaultProvider: "kimi-for-coding",
  defaultModel: "kimi-k2.6",
  defaultThinkingLevel: "high",
  enabledModels: [
    "custom/provider-model",
    "openai-codex/gpt-5.6",
    "openai-codex/gpt-5.6-luna",
    "openai-codex/gpt-5.6-terra",
    "openai-codex/gpt-5.6-sol",
  ],
  packages: [
    "npm:@agwab/pi-workflow",
    { source: "npm:@agwab/pi-workflow@0.7.0" },
    { source: "npm:@agwab/pi-workflow-helper" },
    { source: "npm:pi-subagents" },
  ],
}, null, 2)}\n`);
NODE

grep -Fq '. "$SCRIPT_DIR/lib/pi-paths.sh"' "$DEPLOY_SCRIPT" &&
  grep -Fq 'pi_agent_node_modules_dir "$HOME_DIR"' "$DEPLOY_SCRIPT" || {
  printf 'deploy script must use the shared Pi path helper\n' >&2
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

assert_link "$HOME_DIR/.claude/CLAUDE.md" "$ROOT_DIR/claude/CLAUDE.md"
assert_link "$HOME_DIR/.claude/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.claude/PLAN_TEMPLATE.md" "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_link "$HOME_DIR/.claude/PLAN_TEMPLATE_FULL.md" "$ROOT_DIR/PLAN_TEMPLATE_FULL.md"
assert_link "$HOME_DIR/.claude/commands/plan.md" "$ROOT_DIR/claude/commands/plan-create.md"
assert_link "$HOME_DIR/.claude/hooks/workflow-router.mjs" "$ROOT_DIR/claude/hooks/workflow-router.mjs"
assert_link "$HOME_DIR/.claude/hooks/workflow-router-lib.mjs" "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs"
assert_link "$HOME_DIR/.claude/hooks/plan-ready-guard.mjs" "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
assert_link "$HOME_DIR/.claude/hooks/plan-commit-guard.mjs" "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
assert_link "$HOME_DIR/.claude/hooks/detect-adr-signal.mjs" "$ROOT_DIR/claude/hooks/detect-adr-signal.mjs"
assert_link "$HOME_DIR/.claude/hooks/ledger-auto-emit.mjs" "$ROOT_DIR/claude/hooks/ledger-auto-emit.mjs"
assert_link "$HOME_DIR/.claude/hooks/outcome-metric-emit.mjs" "$ROOT_DIR/claude/hooks/outcome-metric-emit.mjs"
assert_link "$HOME_DIR/.claude/settings.workflow-hooks.json" "$ROOT_DIR/claude/settings.workflow-hooks.json"
assert_link "$HOME_DIR/.claude/skills/adr" "$ROOT_DIR/claude/skills/adr"

assert_link "$HOME_DIR/.pi/agent/AGENTS.md" "$ROOT_DIR/pi/AGENTS.md"
assert_link "$HOME_DIR/.pi/agent/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.pi/agent/PLAN_TEMPLATE.md" "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_link "$HOME_DIR/.pi/agent/PLAN_TEMPLATE_FULL.md" "$ROOT_DIR/PLAN_TEMPLATE_FULL.md"
assert_link "$HOME_DIR/.pi/agent/extensions" "$ROOT_DIR/pi/extensions"
assert_link "$HOME_DIR/.pi/agent/subagents.json" "$ROOT_DIR/pi/agent/subagents.json"
assert_link "$HOME_DIR/.pi/agent/agents/etabli-scout.md" "$ROOT_DIR/pi/agents/etabli-scout.md"
assert_link "$HOME_DIR/.pi/agent/agents/etabli-analyst.md" "$ROOT_DIR/pi/agents/etabli-analyst.md"
assert_link "$HOME_DIR/.pi/agent/agents/etabli-challenger.md" "$ROOT_DIR/pi/agents/etabli-challenger.md"
assert_link "$HOME_DIR/.pi/agent/agents/etabli-judge.md" "$ROOT_DIR/pi/agents/etabli-judge.md"
assert_link "$HOME_DIR/.pi/agent/agents/etabli-fallback.md" "$ROOT_DIR/pi/agents/etabli-fallback.md"
assert_link "$HOME_DIR/.pi/agent/agents/Explore.md" "$ROOT_DIR/pi/agents/Explore.md"
assert_link "$HOME_DIR/.pi/agent/skills/plan-loop" "$ROOT_DIR/pi/skills/plan-loop"
assert_link "$HOME_DIR/.pi/settings.json" "$ROOT_DIR/pi/settings.json"
assert_link "$HOME_DIR/.agents/PLAN_TEMPLATE.md" "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_link "$HOME_DIR/.agents/PLAN_TEMPLATE_FULL.md" "$ROOT_DIR/PLAN_TEMPLATE_FULL.md"
assert_link "$HOME_DIR/.agents/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.agents/skills/pr-review" "$ROOT_DIR/pi/skills/pr-review"
assert_link "$HOME_DIR/.agents/skills/browser-full-page-capture" "$ROOT_DIR/pi/skills/browser-full-page-capture"
assert_link "$HOME_DIR/.agents/skills/frontend-motion-performance" "$ROOT_DIR/pi/skills/frontend-motion-performance"
assert_link "$HOME_DIR/.agents/skills/goal-prompt-rewriter" "$ROOT_DIR/pi/skills/goal-prompt-rewriter"
assert_link "$HOME_DIR/.agents/skills/ui-reference-capture" "$ROOT_DIR/pi/skills/ui-reference-capture"
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

if (!hasObjectSource("npm:@tintinweb/pi-subagents@0.13.0")) {
  throw new Error("missing scoped Pi subagents package");
}

if (!hasObjectSource("npm:@tintinweb/pi-tasks@0.7.1")) {
  throw new Error("missing scoped Pi tasks package");
}

const piWorkflow = packageBySource("npm:@agwab/pi-workflow@0.8.1");
if (!piWorkflow) {
  throw new Error("missing pinned pi-workflow package");
}
if (JSON.stringify(piWorkflow.extensions) !== JSON.stringify(["src/extension.ts"]) ||
    JSON.stringify(piWorkflow.skills) !== JSON.stringify(["workflow-guide", "execution-router"])) {
  throw new Error("pi-workflow package resources are not curated");
}

if (packages.some((entry) => sourceOf(entry) === "npm:pi-subagents")) {
  throw new Error("legacy unscoped pi-subagents package was kept");
}

if (packages.some((entry) => ["npm:@tintinweb/pi-subagents", "npm:@tintinweb/pi-tasks"].includes(sourceOf(entry)))) {
  throw new Error("unpinned Pi subagent package was kept");
}

if (packages.some((entry) => {
  const source = sourceOf(entry);
  return typeof source === "string" &&
    (source === "npm:@agwab/pi-workflow" || source.startsWith("npm:@agwab/pi-workflow@")) &&
    source !== "npm:@agwab/pi-workflow@0.8.1";
})) {
  throw new Error("legacy pi-workflow package source was kept");
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
  "zai/glm-5.1",
  "zai/glm-5-turbo",
  "xai/grok-4.5",
  "kimi-coding/k3",
]) {
  if (!enabledModels.includes(model)) throw new Error(`missing preserved or managed model: ${model}`);
}
for (const model of [
  "openai-codex/gpt-5.6",
  "openai-codex/gpt-5.6-luna",
  "openai-codex/gpt-5.6-terra",
  "openai-codex/gpt-5.6-sol",
]) {
  if (enabledModels.includes(model)) throw new Error(`legacy model was kept: ${model}`);
}
NODE

settings_before="$(shasum -a 256 "$HOME_DIR/.pi/agent/settings.json" | awk '{print $1}')"
"$DEPLOY_SCRIPT" --apply --home "$HOME_DIR" >/dev/null
settings_after="$(shasum -a 256 "$HOME_DIR/.pi/agent/settings.json" | awk '{print $1}')"
if [ "$settings_before" != "$settings_after" ]; then
  printf 'second deploy changed Pi settings; sync is not idempotent\n' >&2
  exit 1
fi

printf 'deploy agent workflow smoke test: ok\n'
