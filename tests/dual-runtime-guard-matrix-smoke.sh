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

# Shared planMutationGuardDecision works for Claude-style and Pi-style tool names
node --input-type=module <<EOF
import { pathToFileURL } from "node:url";
import { writeFileSync } from "node:fs";
import { join } from "node:path";

const mod = await import(pathToFileURL("$CORE").href);
const tmp = "$TMP";
writeFileSync(join(tmp, "PLAN.md"), "# PLAN\\n\\n## Meta\\n- Status: DRAFT\\n");

const claudeDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "x.ts"), content: "x" },
});
if (claudeDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Claude Write under DRAFT must deny");
  process.exit(1);
}

const piDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "write",
  input: { path: join(tmp, "y.ts"), content: "y" },
});
if (piDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Pi write under DRAFT must deny via normalizeToolName");
  process.exit(1);
}

const planEditAllowed = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Edit",
  tool_input: { file_path: join(tmp, "PLAN.md"), old_string: "DRAFT", new_string: "READY" },
});
if (planEditAllowed != null) {
  console.error("PLAN.md edit under DRAFT must be allowed");
  process.exit(1);
}

const bashDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: "echo hi > out.txt" },
});
if (bashDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("mutating bash under DRAFT must deny");
  process.exit(1);
}

writeFileSync(join(tmp, "PLAN.md"), [
  "# PLAN",
  "",
  "## Meta",
  "- Status: READY",
  "",
  "## Checks",
  "- command: bash tests/a.sh",
  "- command: bash tests/b.sh",
  "",
].join("\\n"));

const readyAllow = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "z.ts"), content: "z" },
});
if (readyAllow != null) {
  console.error("READY must allow Write to non-plan files");
  process.exit(1);
}

const weakenDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "write",
  input: {
    path: join(tmp, "PLAN.md"),
    content: [
      "# PLAN",
      "",
      "## Meta",
      "- Status: READY",
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "",
    ].join("\\n"),
  },
});
if (weakenDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY check-freeze weaken must deny");
  process.exit(1);
}
if (!String(weakenDeny?.hookSpecificOutput?.permissionDecisionReason || "").includes("check-freeze")) {
  console.error("weaken deny reason must mention check-freeze");
  process.exit(1);
}

const strengthenOk = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    content: [
      "# PLAN",
      "",
      "## Meta",
      "- Status: READY",
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "- command: bash tests/b.sh",
      "- command: bash tests/c.sh",
      "",
    ].join("\\n"),
  },
});
if (strengthenOk != null) {
  console.error("READY strengthen must allow");
  process.exit(1);
}

const challengedOk = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    content: [
      "# PLAN",
      "",
      "## Meta",
      "- Status: CHALLENGED",
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "",
      "## Decision Log",
      "- check-freeze demote: removed b",
      "",
    ].join("\\n"),
  },
});
if (challengedOk != null) {
  console.error("CHALLENGED weaken with rationale must allow");
  process.exit(1);
}

const demoteNoRationale = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    content: [
      "# PLAN",
      "",
      "## Meta",
      "- Status: CHALLENGED",
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "",
      "## Decision Log",
      "- scope discussion only",
      "",
    ].join("\\n"),
  },
});
if (demoteNoRationale?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("CHALLENGED weaken without freeze rationale must deny");
  process.exit(1);
}

const bashPlanDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: "sed -i '' '/agent-scenarios/d' PLAN.md" },
});
if (bashPlanDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY mutating bash targeting PLAN.md must deny");
  process.exit(1);
}

const ops = mod.classifyWorkflowRoute("supprime ce dossier et force-push la branche", {
  planStatus: "missing",
});
if (ops.route !== "ops-stop") {
  console.error("ops-stop expected, got", ops.route);
  process.exit(1);
}

console.log("dual-runtime guard matrix smoke test: ok");
console.log("claude.plan_ready_guard: deny_on_draft confirmed");
console.log("pi.plan_ready_guard: deny_on_draft confirmed (shared helper)");
console.log("check_freeze: deny_weaken_allow_strengthen confirmed");
console.log("ops_stop.route: confirmed via classifier");
EOF
