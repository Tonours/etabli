#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/tests/lib/hash.sh"
DEPLOY_SCRIPT="$ROOT_DIR/scripts/deploy-agent-workflow"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="$TMP_DIR/home"
DRY_HOME_DIR="$TMP_DIR/dry-home"
WORK_HOME_DIR="$TMP_DIR/work-home"
mkdir -p "$HOME_DIR/.pi/agent" "$HOME_DIR/.claude/agents" "$HOME_DIR/.claude/skills" \
  "$HOME_DIR/.claude/commands" \
  "$TMP_DIR/personal-agents" "$TMP_DIR/external-skill"
printf 'personal agent\n' >"$TMP_DIR/personal-agents/personal.md"
printf 'personal command\n' >"$HOME_DIR/.claude/commands/recap.md"
printf 'external command\n' >"$TMP_DIR/external-command.md"
ln -s "$ROOT_DIR/claude/agents/playwright-generator.md" "$HOME_DIR/.claude/agents/playwright-generator.md"
ln -s "$TMP_DIR/personal-agents/personal.md" "$HOME_DIR/.claude/agents/personal.md"
ln -s "$TMP_DIR/external-command.md" "$HOME_DIR/.claude/commands/commit.md"
ln -s "$ROOT_DIR/claude/commands/plan.md" "$HOME_DIR/.claude/commands/plan.md"
ln -s "$ROOT_DIR/claude/scopes/shared/commands/front-quality.md" "$HOME_DIR/.claude/commands/front-quality.md"
ln -s "$ROOT_DIR/claude/scopes/shared/commands/plan-loop.md" "$HOME_DIR/.claude/commands/plan-loop.md"
ln -s "$ROOT_DIR/pi/skills/retired-skill" "$HOME_DIR/.claude/skills/retired-skill"
ln -s "$ROOT_DIR/claude/scopes/shared/skills/spec" "$HOME_DIR/.claude/skills/spec"
ln -s "$TMP_DIR/external-skill" "$HOME_DIR/.claude/skills/verify-workflow"
mkdir -p "$HOME_DIR/.pi/agent/skills"
ln -s "$ROOT_DIR/pi/skills/verify" "$HOME_DIR/.pi/agent/skills/verify"

printf '%s\n' '{
  "defaultProvider": "kimi-for-coding",
  "defaultModel": "kimi-k2.6",
  "defaultThinkingLevel": "high",
  "enabledModels": [
    "custom/provider-model",
    "cursor/custom-personal-model",
    "cursor/claude-fable-5-1@300k",
    "cursor/claude-sonnet-5@300k",
    "github-copilot/claude-sonnet-5",
    "opencode-go/grok-4.7",
    "xai/grok-4.7",
    "openai-codex/gpt-6-astra",
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
    },
    {
      "source": "npm:@zenspc/pi-pstack"
    },
    {
      "source": "local:etabli-workflow",
      "skills": ["plan-loop"]
    }
  ]
}' >"$HOME_DIR/.pi/agent/settings.json"

# The dry-run probe touches only DRY_HOME_DIR, so it overlaps the shared-home
# setup instead of blocking it.
"$DEPLOY_SCRIPT" --dry-run --home "$DRY_HOME_DIR" >/dev/null &
DRY_RUN_PID=$!

seed_stale_hooks() {
  mkdir -p "$1/.claude/hooks"
  ln -s "$ROOT_DIR/claude/hooks/outcome-metric-emit.mjs" "$1/.claude/hooks/outcome-metric-emit.mjs"
  ln -s "$ROOT_DIR/claude/hooks/proof-shadow.mjs" "$1/.claude/hooks/proof-shadow.mjs"
  ln -s "$ROOT_DIR/claude/hooks/../../private/offline-hook.mjs" "$1/.claude/hooks/offline-hook.mjs"
  ln -s "$ROOT_DIR/claude/hooks/renamed-hook.mjs" "$1/.claude/hooks/personal-alias.mjs"
  printf 'personal hook\n' >"$1/.claude/hooks/personal-hook.mjs"
}
seed_stale_hooks "$HOME_DIR"

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
assert_absent "$HOME_DIR/.claude/commands/plan-loop.md"
assert_absent "$HOME_DIR/.claude/commands/plan.md"
assert_absent "$HOME_DIR/.claude/commands/front-quality.md"
assert_link "$HOME_DIR/.claude/skills/plan-loop" "$ROOT_DIR/skills/shared/plan-loop"
assert_link "$HOME_DIR/.claude/skills/spec" "$ROOT_DIR/skills/shared/spec"
assert_absent "$HOME_DIR/.pi/agent/skills/spec"
assert_absent "$HOME_DIR/.claude/skills/linear-work"
assert_absent "$HOME_DIR/.pi/agent/skills/linear-work"
# A foreign link on a managed name moves outside the discovery root.
assert_link "$HOME_DIR/.claude/skills/verify-workflow" "$ROOT_DIR/skills/shared/verify-workflow"
if find "$HOME_DIR/.claude/skills" -maxdepth 1 -name '*.bak.*' | grep -q .; then
  printf 'deploy left a skill backup inside the discovery root\n' >&2
  exit 1
fi
collision_backups=( "$HOME_DIR/.claude/skills.bak"/verify-workflow.bak.* )
[ "$(readlink "${collision_backups[0]}")" = "$TMP_DIR/external-skill" ] || {
  printf 'deploy did not keep the foreign skill link in skills.bak\n' >&2
  exit 1
}
assert_file "$HOME_DIR/.claude/commands/recap.md"
grep -Fxq 'personal command' "$HOME_DIR/.claude/commands/recap.md"
assert_link "$HOME_DIR/.claude/commands/commit.md" "$TMP_DIR/external-command.md"
assert_link "$HOME_DIR/.claude/hooks/read-only-agent-guard.mjs" "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs"
assert_absent "$HOME_DIR/.claude/hooks/outcome-metric-emit.mjs"
assert_absent "$HOME_DIR/.claude/hooks/proof-shadow.mjs"
assert_link "$HOME_DIR/.claude/hooks/offline-hook.mjs" "$ROOT_DIR/claude/hooks/../../private/offline-hook.mjs"
assert_link "$HOME_DIR/.claude/hooks/personal-alias.mjs" "$ROOT_DIR/claude/hooks/renamed-hook.mjs"
grep -Fxq 'personal hook' "$HOME_DIR/.claude/hooks/personal-hook.mjs"
HOOK_DRY_HOME_DIR="$TMP_DIR/hook-dry-home"
seed_stale_hooks "$HOOK_DRY_HOME_DIR"
"$DEPLOY_SCRIPT" --dry-run --home "$HOOK_DRY_HOME_DIR" >"$TMP_DIR/hook-dry.txt"
grep -Fq 'stale Claude hook proof-shadow.mjs' "$TMP_DIR/hook-dry.txt"
assert_link "$HOOK_DRY_HOME_DIR/.claude/hooks/proof-shadow.mjs" "$ROOT_DIR/claude/hooks/proof-shadow.mjs"
RELOCATED_HOME_DIR="$TMP_DIR/relocated-home"
RELOCATED_CLAUDE_DIR="$RELOCATED_HOME_DIR/relocated-claude"
mkdir -p "$RELOCATED_CLAUDE_DIR/hooks"
ln -s "$ROOT_DIR/claude/hooks/proof-shadow.mjs" "$RELOCATED_CLAUDE_DIR/hooks/proof-shadow.mjs"
mkdir -p "$RELOCATED_CLAUDE_DIR/commands"
ln -s "$ROOT_DIR/claude/commands/plan-loop.md" "$RELOCATED_CLAUDE_DIR/commands/plan-loop.md"
ln -s "$TMP_DIR/unmounted-volume/personal-claude.md" "$RELOCATED_CLAUDE_DIR/CLAUDE.md"
ln -s "$ROOT_DIR/../personal/review-rubric.md" "$RELOCATED_CLAUDE_DIR/review-rubric.md"
node -e '
const f = require(process.argv[1]);
require("fs").writeFileSync(process.argv[2], JSON.stringify({ hooks: f.hooks }));
' "$ROOT_DIR/claude/settings.workflow-hooks.json" "$RELOCATED_CLAUDE_DIR/settings.json"
RELOCATED_NODE_DIR="$(dirname "$(node -e 'process.stdout.write(process.execPath)')")"
HOME="$RELOCATED_HOME_DIR" CLAUDE_CONFIG_DIR="$RELOCATED_CLAUDE_DIR" PATH="$RELOCATED_NODE_DIR:$PATH" \
  ETABLI_SKIP_LIVE_CHECKS=1 "$DEPLOY_SCRIPT" --apply --home "$RELOCATED_HOME_DIR" >/dev/null
assert_absent "$RELOCATED_CLAUDE_DIR/hooks/proof-shadow.mjs"
assert_absent "$RELOCATED_CLAUDE_DIR/commands/plan-loop.md"
if ls "$RELOCATED_CLAUDE_DIR/commands"/plan-loop.md.bak.* >/dev/null 2>&1; then
  printf 'deploy backed up a dangling managed link\n' >&2
  exit 1
fi
assert_link "$RELOCATED_CLAUDE_DIR/CLAUDE.md" "$ROOT_DIR/claude/CLAUDE.md"
assert_link "$RELOCATED_CLAUDE_DIR/skills/adr" "$ROOT_DIR/skills/shared/adr"
CLAUDE_CONFIG_DIR="$RELOCATED_CLAUDE_DIR" "$ROOT_DIR/scripts/claude-hooks-check" >/dev/null
backups=( "$RELOCATED_CLAUDE_DIR"/CLAUDE.md.bak.* )
[ -L "${backups[0]}" ] || {
  printf 'deploy dropped a dangling unmanaged link without a backup\n' >&2
  exit 1
}
rubric_backups=( "$RELOCATED_CLAUDE_DIR"/review-rubric.md.bak.* )
[ -L "${rubric_backups[0]}" ] || {
  printf 'deploy dropped a dotdot dangling link without a backup\n' >&2
  exit 1
}
ISOLATED_HOME_DIR="$TMP_DIR/isolated-home"
OUTSIDE_CLAUDE_DIR="$TMP_DIR/outside-claude"
mkdir -p "$ISOLATED_HOME_DIR" "$OUTSIDE_CLAUDE_DIR"
ln -s "$OUTSIDE_CLAUDE_DIR" "$ISOLATED_HOME_DIR/claude-alias"
for outside_config in "$OUTSIDE_CLAUDE_DIR" "$ISOLATED_HOME_DIR/../outside-claude" "$ISOLATED_HOME_DIR/claude-alias"; do
  HOME="$ISOLATED_HOME_DIR" CLAUDE_CONFIG_DIR="$outside_config" PATH="$RELOCATED_NODE_DIR:$PATH" \
    ETABLI_SKIP_LIVE_CHECKS=1 "$DEPLOY_SCRIPT" --apply --home "$ISOLATED_HOME_DIR" >/dev/null
done
if [ -n "$(ls -A "$OUTSIDE_CLAUDE_DIR")" ]; then
  printf 'deploy under a disposable HOME wrote into an outside CLAUDE_CONFIG_DIR\n' >&2
  exit 1
fi
assert_link "$ISOLATED_HOME_DIR/.claude/CLAUDE.md" "$ROOT_DIR/claude/CLAUDE.md"
assert_link "$HOME_DIR/.claude/hooks/read-only-agent-guard.mjs" "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs"
assert_link "$HOME_DIR/.claude/settings.workflow-hooks.json" "$ROOT_DIR/claude/settings.workflow-hooks.json"
assert_link "$HOME_DIR/.claude/statusline-command.sh" "$ROOT_DIR/claude/statusline-command.sh"
assert_link "$HOME_DIR/.claude/skills/adr" "$ROOT_DIR/skills/shared/adr"
assert_absent "$HOME_DIR/.claude/skills/frontend-css-ui-ux"
assert_absent "$HOME_DIR/.claude/skills/css-layout-primitives"
assert_absent "$HOME_DIR/.claude/skills/css-only-components"
assert_absent "$HOME_DIR/.claude/skills/css-debugging"
assert_absent "$HOME_DIR/.claude/skills/react-doctor-100"
assert_absent "$HOME_DIR/.claude/skills/retired-skill"
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

for retired_surface in .codex .config/devin .agents; do
  assert_absent "$ISOLATED_HOME_DIR/$retired_surface"
done

if [ -e "$HOME_DIR/.claude/skills/employer-backend-suite" ]; then
  printf 'work-scope skill deployed without a declared scope: %s\n' \
    "$HOME_DIR/.claude/skills/employer-backend-suite" >&2
  exit 1
fi

# The work-scope deploy only touches WORK_HOME_DIR, so it runs concurrently
# with the shared-home assertions; its failures propagate through wait.
(
  mkdir -p \
    "$WORK_HOME_DIR/.pi/agent/skills" \
    "$WORK_HOME_DIR/.claude/skills" \
    "$WORK_HOME_DIR/.claude/scripts" \
    "$WORK_HOME_DIR/external-skill"
  ln -s "$ROOT_DIR/claude/scopes/work/scripts/retired-routine" "$WORK_HOME_DIR/.claude/scripts/retired-routine"
  ln -s "$TMP_DIR/personal-missing-script" "$WORK_HOME_DIR/.claude/scripts/personal-missing-script"
  ln -s "$ROOT_DIR/vendor/adonisjs-skills/skills/adonisjs-suite" "$WORK_HOME_DIR/.pi/agent/skills/adonisjs-suite"
  ln -s "$ROOT_DIR/vendor/adonisjs-skills/skills/adonisjs-suite" "$WORK_HOME_DIR/.claude/skills/adonisjs-suite"

  ETABLI_SCOPE=work "$DEPLOY_SCRIPT" --apply --home "$WORK_HOME_DIR" >/dev/null
  assert_link "$WORK_HOME_DIR/.claude/scripts/claude-bin.sh" "$ROOT_DIR/claude/scopes/work/scripts/claude-bin.sh"
  assert_absent "$WORK_HOME_DIR/.claude/scripts/retired-routine"
  assert_link "$WORK_HOME_DIR/.claude/scripts/personal-missing-script" "$TMP_DIR/personal-missing-script"
  assert_link "$WORK_HOME_DIR/.claude/scripts/pr-autoreview" "$ROOT_DIR/claude/scopes/work/scripts/pr-autoreview"
  assert_link "$WORK_HOME_DIR/.claude/scripts/pr-review-watch" "$ROOT_DIR/claude/scopes/work/scripts/pr-review-watch"
  assert_link "$WORK_HOME_DIR/.claude/skills/employer-backend-suite" "$ROOT_DIR/skills/work/employer-backend-suite"
  assert_absent "$WORK_HOME_DIR/.pi/agent/skills/employer-backend-suite"
  assert_link "$WORK_HOME_DIR/.claude/skills/linear-work" "$ROOT_DIR/skills/work/linear-work"
  assert_link "$WORK_HOME_DIR/.pi/agent/skills/linear-work" "$ROOT_DIR/skills/work/linear-work"
  assert_link "$WORK_HOME_DIR/.claude/skills/pr-council-review" "$ROOT_DIR/skills/work/pr-council-review"
  assert_absent "$WORK_HOME_DIR/.pi/agent/skills/pr-council-review"
  assert_absent "$WORK_HOME_DIR/.claude/skills/adr"
  assert_absent "$WORK_HOME_DIR/.pi/agent/skills/adonisjs-suite"
  assert_absent "$WORK_HOME_DIR/.claude/skills/adonisjs-suite"
  assert_absent "$WORK_HOME_DIR/.grok"
  for retired_surface in .codex .config/devin .agents; do
    assert_absent "$WORK_HOME_DIR/$retired_surface"
  done
) &
WORK_SCOPE_PID=$!

assert_link "$HOME_DIR/.pi/agent/AGENTS.md" "$ROOT_DIR/workflow/agent-rules.md"
assert_link "$HOME_DIR/.pi/agent/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.pi/agent/PLAN_TEMPLATE.md" "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_link "$HOME_DIR/.pi/agent/PLAN_TEMPLATE_FULL.md" "$ROOT_DIR/PLAN_TEMPLATE_FULL.md"
assert_link "$HOME_DIR/.pi/scripts" "$ROOT_DIR/scripts"
assert_link "$HOME_DIR/.pi/workflow" "$ROOT_DIR/workflow"
assert_link "$HOME_DIR/.pi/agent/extensions" "$ROOT_DIR/pi/extensions"
assert_absent "$HOME_DIR/.pi/agent/subagents.json"
assert_link "$HOME_DIR/.pi/agent/agents/Explore.md" "$ROOT_DIR/pi/agents/Explore.md"
assert_link "$HOME_DIR/.pi/agent/skills/plan-loop" "$ROOT_DIR/skills/shared/plan-loop"
assert_link "$HOME_DIR/.pi/agent/skills/verify-workflow" "$ROOT_DIR/skills/shared/verify-workflow"
assert_absent "$HOME_DIR/.pi/agent/skills/verify"
assert_absent "$HOME_DIR/.pi/agent/skills/vercel-react-best-practices"
assert_link "$HOME_DIR/.pi/settings.json" "$ROOT_DIR/pi/settings.json"
assert_file "$HOME_DIR/.pi/agent/settings.json"

DANGLING_HOME_DIR="$TMP_DIR/dangling-home"
mkdir -p "$DANGLING_HOME_DIR/.pi/agent"
ln -s "$TMP_DIR/missing-pi-settings.json" "$DANGLING_HOME_DIR/.pi/agent/settings.json"
"$DEPLOY_SCRIPT" --apply --home "$DANGLING_HOME_DIR" >/dev/null
assert_file "$DANGLING_HOME_DIR/.pi/agent/settings.json"
if [ -L "$DANGLING_HOME_DIR/.pi/agent/settings.json" ]; then
  printf 'deploy did not replace dangling Pi settings symlink with a local file\n' >&2
  exit 1
fi

INSTALL_HOME_DIR="$TMP_DIR/install-home"
mkdir -p "$INSTALL_HOME_DIR/.pi/agent"
printf 'unmanaged target\n' >"$TMP_DIR/wrong-agent-source"
ln -s "$TMP_DIR/wrong-agent-source" "$INSTALL_HOME_DIR/.pi/agent/AGENTS.md"
printf '%s\n' '{"defaultProvider":"custom","defaultModel":"personal-model","enabledModels":[],"packages":[]}' \
  >"$INSTALL_HOME_DIR/.pi/agent/settings.json"
ETABLI_DEPLOY_CALLER=install "$DEPLOY_SCRIPT" --apply --home "$INSTALL_HOME_DIR" >/dev/null
assert_link "$INSTALL_HOME_DIR/.pi/agent/AGENTS.md" "$ROOT_DIR/workflow/agent-rules.md"
if find "$INSTALL_HOME_DIR/.pi/agent" -maxdepth 1 -name 'AGENTS.md.bak.*' | grep -q .; then
  printf 'installer convergence backed up a managed symlink instead of replacing it\n' >&2
  exit 1
fi
node - "$INSTALL_HOME_DIR/.pi/agent/settings.json" <<'NODE'
const fs = require("node:fs");
const settings = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (!settings.enabledModels.includes("custom/personal-model")) {
  throw new Error("installer convergence did not preserve the custom default model");
}
NODE

grep -Fq 'for (const suffix of [".mjs", ".sh"])' "$ROOT_DIR/scripts/lib/surfaces.mjs" || {
  printf 'deploy must reconcile both JavaScript and shell Claude hooks\n' >&2
  exit 1
}

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

const piSubagents = packageBySource("npm:pi-subagents@0.77.0");
if (!piSubagents || JSON.stringify(piSubagents.skills) !== "[]") {
  throw new Error("tracked npm:pi-subagents entry missing or not skill-silenced");
}

if (hasObjectSource("local:etabli-workflow")) {
  throw new Error("retired local:etabli-workflow keeper list was kept");
}

if (hasObjectSource("npm:@zenspc/pi-pstack")) {
  throw new Error("npm:@zenspc/pi-pstack must stay removed");
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
  "cursor/custom-personal-model",
  "zai/glm-5.3",
  "zai/glm-5.3-flash",
]) {
  if (!enabledModels.includes(model)) throw new Error(`missing preserved or managed model: ${model}`);
}
for (const model of ["openai-codex/gpt-5.6-luna", "openai-codex/gpt-5.6-sol", "cursor/claude-fable-5-1@300k", "cursor/claude-sonnet-5@300k", "github-copilot/claude-sonnet-5", "opencode-go/grok-4.7", "xai/grok-4.7", "openai-codex/gpt-6-astra"]) {
  if (enabledModels.includes(model)) throw new Error(`retired model kept after deploy: ${model}`);
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

# The sync resets an exact retired managed default, keeps custom models and honors dry-run.
local_settings="$TMP_DIR/retired-default.json"
printf '%s\n' '{"defaultProvider":"cursor","defaultModel":"claude-sonnet-5@300k","enabledModels":["cursor/claude-sonnet-5@300k","custom/provider-model"],"packages":[]}' >"$local_settings"
before="$(hash256 "$local_settings" | awk '{print $1}')"
node "$ROOT_DIR/scripts/lib/pi-agent-settings-sync.mjs" "$local_settings" "$ROOT_DIR/pi/agent/settings.json" 1 smoke >/dev/null
[ "$before" = "$(hash256 "$local_settings" | awk '{print $1}')" ] || { printf 'dry-run changed retired default\n' >&2; exit 1; }
node "$ROOT_DIR/scripts/lib/pi-agent-settings-sync.mjs" "$local_settings" "$ROOT_DIR/pi/agent/settings.json" 0 smoke >/dev/null
jq -e '.defaultProvider == "zai" and .defaultModel == "glm-5.3" and (.enabledModels | index("custom/provider-model")) != null and (.enabledModels | index("zai/glm-5.3-flash")) != null and (.enabledModels | index("cursor/claude-sonnet-5@300k")) == null' "$local_settings" >/dev/null

local_settings="$TMP_DIR/custom-default.json"
printf '%s\n' '{"packages":["npm:mitsupi",{"source":"npm:pi-lens","skills":["lens"]},{"source":"npm:pi-lens@4.0.0"},{"source":"git:github.com/badlogic/pi-skills@feature/topic","skills":["danger"]},"https://github.com/badlogic/pi-skills.git@main","npm:@zhushanwen/pi-ask-user"]}' >"$local_settings"
node "$ROOT_DIR/scripts/lib/pi-agent-settings-sync.mjs" "$local_settings" "$ROOT_DIR/pi/agent/settings.json" 0 smoke >/dev/null
node - "$local_settings" "$ROOT_DIR/pi/agent/settings.json" <<'NODE'
const fs = require("node:fs");
const [local, tracked] = process.argv.slice(2).map((path) => JSON.parse(fs.readFileSync(path, "utf8")));
const sources = local.packages.map((entry) => (typeof entry === "string" ? entry : entry.source));
const identity = (source) => /^(npm:(?:@[^/]+\/)?[^@]+)@/.exec(source)?.[1] ?? source.replace(/@[^/@]*$/, "");
const identities = sources.map(identity);
if (new Set(identities).size !== identities.length) throw new Error(`pinned sync duplicated a package: ${sources.join(", ")}`);
for (const entry of tracked.packages) {
  if (!sources.includes(entry.source)) throw new Error(`pinned sync did not install the tracked ${entry.source}`);
}
if (!sources.includes("npm:@zhushanwen/pi-ask-user")) throw new Error("pinned sync dropped a local-only package");
if (sources.length !== tracked.packages.length + 1) throw new Error(`pinned sync kept ${sources.length} entries for ${tracked.packages.length} tracked plus 1 local`);
NODE

# An unrelated local default is kept.
printf '%s\n' '{"defaultProvider":"local-mlx","defaultModel":"personal-model","enabledModels":["custom/provider-model"],"packages":[]}' >"$local_settings"
node "$ROOT_DIR/scripts/lib/pi-agent-settings-sync.mjs" "$local_settings" "$ROOT_DIR/pi/agent/settings.json" 0 smoke >/dev/null
jq -e '.defaultProvider == "local-mlx" and .defaultModel == "personal-model" and (.enabledModels | index("local-mlx/personal-model")) != null' "$local_settings" >/dev/null

# Deploy and installer runs keep personal local-mlx models and drop retired ones.
retired_model="$(jq -r '.retired_pi_models[0]' "$ROOT_DIR/workflow/runtime/model-routing.json")"
for caller in deploy install; do
  mlx_home="$TMP_DIR/mlx-$caller-home"
  mkdir -p "$mlx_home/.pi/agent"
  jq -n --arg retired "$retired_model" '{packages: [], enabledModels: ([range(1; 6) | "local-mlx/model-\(.)"] + [$retired])}' >"$mlx_home/.pi/agent/settings.json"
  ETABLI_SKIP_LIVE_CHECKS=1 ETABLI_DEPLOY_CALLER="$caller" "$DEPLOY_SCRIPT" --apply --home "$mlx_home" >"$TMP_DIR/mlx-$caller.out" 2>&1 || {
    cat "$TMP_DIR/mlx-$caller.out" >&2
    exit 1
  }
  jq -e --arg retired "$retired_model" '([.enabledModels[] | select(startswith("local-mlx/"))] | length) == 5 and (.enabledModels | index($retired)) == null' "$mlx_home/.pi/agent/settings.json" >/dev/null || {
    printf '%s run lost a local-mlx model or kept %s:\n' "$caller" "$retired_model" >&2
    jq -c .enabledModels "$mlx_home/.pi/agent/settings.json" >&2
    exit 1
  }
done

# A failing Pi settings sync still runs the Claude sync and fails the deploy.
BAD_PI_HOME_DIR="$TMP_DIR/bad-pi-home"
mkdir -p "$BAD_PI_HOME_DIR/.pi/agent" "$BAD_PI_HOME_DIR/.claude"
printf '{bad' >"$BAD_PI_HOME_DIR/.pi/agent/settings.json"
if "$DEPLOY_SCRIPT" --dry-run --home "$BAD_PI_HOME_DIR" >"$TMP_DIR/bad-pi.out" 2>&1; then
  printf 'deploy with invalid Pi settings exited 0\n' >&2
  exit 1
fi
grep -q 'pi-agent-settings-sync: cannot read local settings' "$TMP_DIR/bad-pi.out" || { cat "$TMP_DIR/bad-pi.out" >&2; exit 1; }
grep -q 'Claude tracked settings' "$TMP_DIR/bad-pi.out" || { printf 'invalid Pi settings hid the Claude sync:\n' >&2; cat "$TMP_DIR/bad-pi.out" >&2; exit 1; }

# A pi earlier on PATH than the managed one is reported as shadowing it.
mkdir -p "$HOME_DIR/.local/bin" "$TMP_DIR/shadow-bin" "$TMP_DIR/dir-bin/pi"
printf '#!/bin/sh\n' >"$HOME_DIR/.local/bin/pi"
printf '#!/bin/sh\n' >"$TMP_DIR/shadow-bin/pi"
chmod +x "$HOME_DIR/.local/bin/pi" "$TMP_DIR/shadow-bin/pi"
if ! PATH="$TMP_DIR/dir-bin:$HOME_DIR/.local/bin:$TMP_DIR/shadow-bin:$PATH" "$DEPLOY_SCRIPT" --check --home "$HOME_DIR" >"$TMP_DIR/pi-first.out" 2>&1; then
  printf 'check failed with the managed pi first on PATH:\n' >&2
  cat "$TMP_DIR/pi-first.out" >&2
  exit 1
fi
if PATH="$TMP_DIR/shadow-bin:$HOME_DIR/.local/bin:$PATH" "$DEPLOY_SCRIPT" --check --fix --home "$HOME_DIR" >"$TMP_DIR/pi-shadow.out" 2>&1; then
  printf 'check passed with a shadowing pi on PATH\n' >&2
  exit 1
fi
grep -Fq "SHADOWED       pi $TMP_DIR/shadow-bin/pi runs before $(cd "$HOME_DIR" && pwd -P)/.local/bin/pi;" "$TMP_DIR/pi-shadow.out" &&
  grep -Fq 'remove it or put $HOME/.local/bin first on PATH' "$TMP_DIR/pi-shadow.out" || {
  cat "$TMP_DIR/pi-shadow.out" >&2
  exit 1
}

printf 'deploy agent workflow smoke test: ok\n'
