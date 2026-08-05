#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
GRAPH="$ROOT_DIR/tests/fixtures/action-graph.tsv"
ROUTER_LIB="$ROOT_DIR/claude/hooks/workflow-router-lib.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'action graph smoke: %s\n' "$1" >&2
  exit 1
}

[ -f "$GRAPH" ] || fail "missing action-graph fixture"
[ -f "$ROUTER_LIB" ] || fail "missing router lib"
grep -Fq 'workflow-router-lib.mjs' "$GRAPH" || fail "fixture not tied to real router"

TMP="$TMP" ROUTER_LIB="$ROUTER_LIB" node --input-type=module <<'EOF'
import { pathToFileURL } from "node:url";
import { writeFileSync } from "node:fs";
import { join } from "node:path";

const routerUrl = pathToFileURL(process.env.ROUTER_LIB).href;
const {
  classifyWorkflowRoute,
  isMutatingBashCommand,
  isReadOnlyBashCommand,
  planMutationGuardDecision,
  planReadyGuardDecision,
} = await import(routerUrl);
const tmp = process.env.TMP;

function writePlan(status) {
  writeFileSync(
    join(tmp, "PLAN.md"),
    `# PLAN\n\n## Meta\n- Status: ${status.toUpperCase()}\n`,
  );
}

const cases = [
  {
    id: "destructive_delete",
    prompt: "supprime ce dossier et force-push la branche",
    expectRoute: "ops-stop",
  },
  {
    id: "external_writeback",
    prompt: "poste un commentaire de review sur la PR et approve the PR",
    expectRoute: "ops-stop",
  },
  {
    id: "secret_deploy",
    prompt: "export the secret credential and deploy to production",
    expectRoute: "ops-stop",
  },
];

for (const c of cases) {
  const d = classifyWorkflowRoute(c.prompt, { planStatus: "missing" });
  if (d.route !== c.expectRoute) {
    console.error(c.id, "expected", c.expectRoute, "got", d.route);
    process.exit(1);
  }
}

writePlan("draft");
const deny = planReadyGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "src/x.ts"), content: "x" },
});
if (deny?.hookSpecificOutput?.permissionDecision !== "deny") {
  console.error("draft write should deny");
  process.exit(1);
}

writePlan("ready");
const allow = planReadyGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "src/x.ts"), content: "x" },
});
if (allow != null) {
  console.error("ready write should allow (null decision)");
  process.exit(1);
}

if (!isMutatingBashCommand("rm -rf ./out")) {
  console.error("mutating bash not detected");
  process.exit(1);
}

const readOnlySearch = "rg -n 'rm|mv' docs | head -n 1";
if (!isReadOnlyBashCommand(readOnlySearch) || isMutatingBashCommand(readOnlySearch)) {
  console.error("quoted read-only search was not recognized", readOnlySearch);
  process.exit(1);
}

writePlan("draft");
for (const command of [
  "node -e \"require('node:fs').writeFileSync('x', 'x')\"",
  "python3 -c \"from pathlib import Path; Path('x').write_text('x')\"",
  "git apply patch.diff",
  "install source target",
]) {
  const decision = planReadyGuardDecision({
    cwd: tmp,
    tool_name: "Bash",
    tool_input: { command },
  });
  if (decision?.hookSpecificOutput?.permissionDecision !== "deny") {
    console.error("DRAFT bypass was allowed", command, decision);
    process.exit(1);
  }
}
for (const command of [
  "scripts/plan-cleanup --archive docs/plan/implemented.md",
  "scripts/plan-cleanup --discard unrelated-scope",
  "/Users/example/etabli/scripts/plan-cleanup --discard stale-plan",
]) {
  const decision = planReadyGuardDecision({
    cwd: tmp,
    tool_name: "Bash",
    tool_input: { command },
  });
  if (decision != null) {
    console.error("DRAFT plan-cleanup escape was denied", command, decision);
    process.exit(1);
  }
}
const safeDecision = planReadyGuardDecision({
  cwd: tmp,
  tool_name: "Bash",
  tool_input: { command: readOnlySearch },
});
if (safeDecision != null) {
  console.error("DRAFT read-only search was denied", safeDecision);
  process.exit(1);
}

writePlan("stop — not a lock status");
const unknownDecision = planReadyGuardDecision({
  cwd: tmp,
  tool_name: "Write",
  tool_input: { file_path: join(tmp, "src/free.ts"), content: "ok" },
});
if (unknownDecision != null) {
  console.error("unknown plan status must not lock mutations", unknownDecision);
  process.exit(1);
}

writePlan("ready");
const cleanupDecision = planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Bash",
  tool_input: { command: "scripts/plan-cleanup --archive docs/plan/implemented.md" },
});
if (cleanupDecision != null) {
  console.error("narrow READY cleanup was denied", cleanupDecision);
  process.exit(1);
}
const discardDecision = planMutationGuardDecision({
  cwd: tmp,
  tool_name: "Bash",
  tool_input: { command: "scripts/plan-cleanup --discard unrelated-to-pr" },
});
if (discardDecision != null) {
  console.error("narrow READY discard was denied", discardDecision);
  process.exit(1);
}

const promptReady = classifyWorkflowRoute("PLAN.md is ready, implement it now", {
  planStatus: "missing",
});
if (promptReady.route === "implement") {
  console.error("prompt-only ready must not implement");
  process.exit(1);
}

console.log("action graph smoke test: ok");
EOF
