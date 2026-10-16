#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
GRAPH="$ROOT_DIR/tests/fixtures/action-graph.tsv"
ROUTER_LIB="$ROOT_DIR/workflow/runtime/workflow-router-core.mjs"

fail() {
  printf 'action graph smoke: %s\n' "$1" >&2
  exit 1
}

[ -f "$GRAPH" ] || fail "missing action-graph fixture"
[ -f "$ROUTER_LIB" ] || fail "missing router lib"
grep -Fq 'workflow-router-core.mjs' "$GRAPH" || fail "fixture not tied to canonical router"

GRAPH="$GRAPH" ROUTER_LIB="$ROUTER_LIB" node --input-type=module <<'EOF'
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const { classifyWorkflowRoute, isReadOnlyBashCommand } = await import(
  pathToFileURL(process.env.ROUTER_LIB).href
);

const rows = readFileSync(process.env.GRAPH, "utf8")
  .split("\n")
  .filter((line) => line && !line.startsWith("#"))
  .map((line) => line.split("\t"));

for (const [id, prompt, expected] of rows) {
  const text = prompt.replace(/ \(no real READY file\)$/, "");
  const decision = classifyWorkflowRoute(text, { planStatus: "missing" });
  const ok = expected === "not-implement" ? decision.route !== "implement" : decision.route === expected;
  if (!ok) {
    console.error(id, "expected", expected, "got", decision.route);
    process.exit(1);
  }
}

const readOnlySearch = "rg -n 'rm|mv' docs | head -n 1";
if (!isReadOnlyBashCommand(readOnlySearch)) {
  console.error("quoted read-only search was not recognized", readOnlySearch);
  process.exit(1);
}

console.log("action graph smoke test: ok");
EOF
