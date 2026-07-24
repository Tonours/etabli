#!/usr/bin/env bash
# C8: honest dual-runtime matrix for READY guard + ops-stop + capability labels.
# Does not promote unknown/proxy_supported to confirmed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
MATRIX="$ROOT_DIR/workflow/runtime-capabilities.json"
CORE="$ROOT_DIR/workflow/runtime/workflow-router-core.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'dual-runtime guard matrix smoke: %s\n' "$1" >&2
  exit 1
}

[ -f "$MATRIX" ] || fail "missing capabilities matrix"
[ -f "$CORE" ] || fail "missing router core"

# Capability labels stay honest (no silent confirmed promotion)
bad="$(jq -r '
  .runtimes | to_entries[] as $r |
  $r.value | to_entries[] |
  select(.value.label != "confirmed" and .value.label != "proxy_supported" and .value.label != "blocked" and .value.label != "unknown") |
  "\($r.key).\(.key)=\(.value.label)"
' "$MATRIX")"
[ -z "$bad" ] || fail "invalid capability labels: $bad"

# Print matrix (inspectable)
printf 'runtime_capability_matrix:\n'
jq -r '
  .runtimes | to_entries[] as $r |
  $r.value | to_entries[] |
  "  \($r.key).\(.key)\t\(.value.label)"
' "$MATRIX"

# Shared planReadyGuardDecision works for Claude-style and Pi-style tool names
node --input-type=module <<EOF
import { pathToFileURL } from "node:url";
import { writeFileSync } from "node:fs";
import { join } from "node:path";

const mod = await import(pathToFileURL("$CORE").href);
const tmp = "$TMP";
writeFileSync(join(tmp, "PLAN.md"), "# PLAN\\n\\n## Meta\\n- Status: DRAFT\\n");

const claudeDeny = mod.planReadyGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "x.ts"), content: "x" },
});
if (claudeDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Claude Write under DRAFT must deny");
  process.exit(1);
}

const piDeny = mod.planReadyGuardDecision({
  cwd: tmp,
  toolName: "write",
  input: { path: join(tmp, "y.ts"), content: "y" },
});
if (piDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Pi write under DRAFT must deny via normalizeToolName");
  process.exit(1);
}

writeFileSync(join(tmp, "PLAN.md"), "# PLAN\\n\\n## Meta\\n- Status: READY\\n");
const readyAllow = mod.planReadyGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "z.ts"), content: "z" },
});
if (readyAllow != null) {
  console.error("READY must allow Write");
  process.exit(1);
}

const ops = mod.classifyWorkflowRoute("supprime ce dossier et force-push la branche", {
  planStatus: "missing",
});
if (ops.route !== "ops-stop") {
  console.error("ops-stop expected, got", ops.route);
  process.exit(1);
}

// Honest: codex.supports_hooks is proxy_supported not confirmed
const labels = JSON.parse(
  await import("node:fs").then((fs) =>
    fs.readFileSync("$MATRIX", "utf8"),
  ),
);
if (labels.runtimes.codex.supports_hooks.label === "confirmed") {
  // Allowed only if truly confirmed — do not fail, but record
  console.log("note: codex.supports_hooks is confirmed");
} else if (labels.runtimes.codex.supports_hooks.label !== "proxy_supported" &&
           labels.runtimes.codex.supports_hooks.label !== "unknown" &&
           labels.runtimes.codex.supports_hooks.label !== "blocked") {
  console.error("unexpected codex.supports_hooks label");
  process.exit(1);
}

console.log("dual-runtime guard matrix smoke test: ok");
console.log("claude.plan_ready_guard: deny_on_draft confirmed");
console.log("pi.plan_ready_guard: deny_on_draft confirmed (shared helper)");
console.log("ops_stop.route: confirmed via classifier");
EOF
