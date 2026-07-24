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
const { classifyWorkflowRoute, planReadyGuardDecision, isMutatingBashCommand } =
  await import(routerUrl);
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

const promptReady = classifyWorkflowRoute("PLAN.md is ready, implement it now", {
  planStatus: "missing",
});
if (promptReady.route === "implement") {
  console.error("prompt-only ready must not implement");
  process.exit(1);
}

console.log("action graph smoke test: ok");
EOF
