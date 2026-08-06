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

if (mod.isMutationRelevantTool("TaskList") !== false || mod.isMutationRelevantTool("read") !== false) {
  console.error("non-mutating tools must be rejected before filesystem guard work");
  process.exit(1);
}
if (mod.isMutationRelevantTool("Write") !== true || mod.isMutationRelevantTool("Bash") !== true) {
  console.error("mutation-relevant tools must remain guarded");
  process.exit(1);
}

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

const relativePlanEditAllowed = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Edit",
  tool_input: { file_path: "PLAN.md", old_string: "DRAFT", new_string: "READY" },
});
if (relativePlanEditAllowed != null) {
  console.error("relative root PLAN.md edit under DRAFT must resolve against event cwd");
  process.exit(1);
}

for (const command of [
  "cd " + tmp + " && ls -la",
  "test -f PLAN.md",
  "git -C . status --short",
  "git branch --show-current",
  "git remote -v",
  "git tag --list",
  "git worktree list",
]) {
  const readOnlyAllowed = mod.planMutationGuardDecision({
    cwd: tmp,
    toolName: "bash",
    input: { command },
  });
  if (readOnlyAllowed != null) {
    console.error("proven read-only Bash must be allowed under DRAFT: " + command);
    process.exit(1);
  }
}

for (const command of [
  "cd " + tmp + " && touch escaped",
  "git branch stale-branch",
  "git branch -D stale-branch",
  "git remote remove origin",
  "git tag -d v0",
  "git worktree remove ../stale",
  "node -p \"require('node:fs').writeFileSync('escaped', 'x')\"",
  "sort -o escaped input.txt",
  "sort -ro escaped input.txt",
  "sort --compress-program=sh input.txt",
  "diff --output=escaped a b",
  "sed -ni '' 's/x/y/' input.txt",
  "sed -n 'w escaped' input.txt",
  "find . -fprintf escaped x",
  "find . '-exec' touch escaped ';'",
  "find . -fprint0 escaped",
]) {
  const mutationDeny = mod.planMutationGuardDecision({
    cwd: tmp,
    toolName: "bash",
    input: { command },
  });
  if (mutationDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
    console.error("write-capable command must be denied under DRAFT: " + command);
    process.exit(1);
  }
}

const quotedSubstitution = "rg \"" + String.fromCharCode(36) + "(touch escaped)\" docs";
const quotedSubstitutionDeny = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "bash",
  input: { command: quotedSubstitution },
});
if (quotedSubstitutionDeny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("quoted command substitution must be denied under DRAFT");
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

// Restore full READY baseline on disk for Edit/MultiEdit/AC cases
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
  "## Acceptance Criteria",
  "- Given x, when y, then z",
  "- Given a, when b, then c",
  "",
].join("\\n"));

const piSchemaNeutralEdit = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "edit",
  input: {
    path: join(tmp, "PLAN.md"),
    edits: [{ oldText: "# PLAN\n", newText: "# PLAN updated\n" }],
  },
});
if (piSchemaNeutralEdit != null) {
  console.error("Pi edits[].oldText/newText schema must reconstruct a neutral READY edit");
  process.exit(1);
}

const piSchemaWeaken = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "edit",
  input: {
    path: join(tmp, "PLAN.md"),
    edits: [{ oldText: "- command: bash tests/b.sh\n", newText: "" }],
  },
});
if (piSchemaWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Pi edits[].oldText/newText weaken must remain denied");
  process.exit(1);
}

const relativePiSchemaWeaken = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "edit",
  input: {
    path: "PLAN.md",
    edits: [{ oldText: "- command: bash tests/b.sh\n", newText: "" }],
  },
});
if (relativePiSchemaWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("relative Pi PLAN.md weaken must remain guarded");
  process.exit(1);
}

const piSchemaUnmatched = mod.planMutationGuardDecision({
  cwd: tmp,
  toolName: "edit",
  input: {
    path: join(tmp, "PLAN.md"),
    edits: [{ oldText: "not present in plan", newText: "replacement" }],
  },
});
if (piSchemaUnmatched?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("Pi unmatched edit schema must fail closed");
  process.exit(1);
}

const editWeaken = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Edit",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    old_string: "- command: bash tests/b.sh\\n",
    new_string: "",
  },
});
if (editWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY Edit weaken must deny");
  process.exit(1);
}

const multiEditWeaken = mod.planMutationGuardDecision({
  cwd: tmp,
  tool_name: "MultiEdit",
  tool_input: {
    file_path: join(tmp, "PLAN.md"),
    edits: [{ old_string: "- command: bash tests/b.sh\\n", new_string: "" }],
  },
});
if (multiEditWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY MultiEdit weaken must deny");
  process.exit(1);
}

const acWeaken = mod.planMutationGuardDecision({
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
      "",
      "## Acceptance Criteria",
      "- Given x, when y, then z",
      "",
    ].join("\\n"),
  },
});
if (acWeaken?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("READY Acceptance Criteria weaken must deny");
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
console.log("check_freeze: edit_multiedit_ac_weaken deny confirmed");
console.log("ops_stop.route: confirmed via classifier");
EOF
