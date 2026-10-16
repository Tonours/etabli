#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

# One process (bun when available, else node) classifies every scenario through
# the Claude router lib and the Pi runtime wrapper and asserts everything
# in-memory. Only the PLAN.md fixtures need a real temp cwd.
if command -v bun >/dev/null 2>&1; then
  HAS_BUN=1
else
  HAS_BUN=0
  printf 'SKIP pi parity (bun missing)\n'
fi

if [ "$HAS_BUN" -eq 1 ]; then
  RUNNER=(bun --silent -e)
else
  RUNNER=(node --input-type=module -e)
fi

"${RUNNER[@]}" '
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const root = process.argv[1];
const tmp = process.argv[2];
const hasBun = process.argv[3] === "1";

const lib = await import(pathToFileURL(`${root}/claude/hooks/workflow-router-lib.mjs`));
const runtime = hasBun
  ? await import(pathToFileURL(`${root}/pi/extensions/lib/workflow-router-runtime.ts`))
  : null;

const planTemplate = (status) => `# PLAN.md

## Meta
- Subject: agent scenario smoke
- Status: ${status}
- Last revised: 2026-07-03
- Archive: pending until implemented and validated

## Goal
Exercise one routing scenario.

## Workflow Contract
- Router decision: plan-implement
- Role: implementer
- Stop condition: scenario assertion passes
- Required evidence: route result

## Acceptance Criteria
- [ ] Scenario matches its expected route.

## Scope
- This scenario only.

## Facts And Assumptions
- The fixture is synthetic.

## Requirement Trace
- Request -> synthetic fixture -> no material gap -> route result.

## Steps
1. Evaluate the route.

## Checks
- command: bash tests/agent-scenarios-smoke.sh

## Risks
- None.

## Open Questions
- None.
`;

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function assertContains(text, needle) {
  if (!text.includes(needle)) {
    fail(`expected output to contain: ${needle}\noutput was:\n${text}`);
  }
}

function assertNotContains(text, needle) {
  if (text.includes(needle)) {
    fail(`did not expect output to contain: ${needle}\noutput was:\n${text}`);
  }
}

const scenariosRoot = `${root}/tests/agent-scenarios`;
const names = readdirSync(scenariosRoot, { withFileTypes: true })
  .filter((ent) => ent.isDirectory())
  .map((ent) => ent.name)
  .sort();

for (const name of names) {
  const dir = `${scenariosRoot}/${name}`;
  const input = JSON.parse(readFileSync(`${dir}/input.json`, "utf8"));
  const expected = JSON.parse(readFileSync(`${dir}/expected.json`, "utf8"));
  const cwd = `${tmp}/${name}.cwd`;
  mkdirSync(cwd, { recursive: true });
  if (input.plan_status !== "missing") {
    writeFileSync(`${cwd}/PLAN.md`, planTemplate(String(input.plan_status).toUpperCase()));
  }

  const d = lib.classifyWorkflowRoute(input.prompt, { planStatus: lib.readPlanStatus(cwd) });
  const output = [
    `Route: ${d.route}`,
    `Reason: ${d.reason}`,
    `Command: ${d.command || "none"}`,
    `Artifact: ${d.artifact}`,
    `Stop: ${d.stopCondition}`,
    `Evidence: ${d.requiredEvidence}`,
  ].join("\n");

  assertContains(output, `Route: ${expected.claude_route}`);
  for (const needle of (expected.context_contains ?? []).filter(Boolean)) {
    assertContains(output, needle);
  }
  for (const needle of (expected.context_not_contains ?? []).filter(Boolean)) {
    assertNotContains(output, needle);
  }

  if (hasBun) {
    const pi = runtime.classifyWorkflowRoute(input.prompt, { planStatus: input.plan_status });
    if (pi.route !== expected.pi_route) {
      fail(`${name} expected pi route ${expected.pi_route}, got ${pi.route}`);
    }
    if (String(pi.writeAllowed) !== String(expected.write_allowed)) {
      fail(`${name} expected writeAllowed ${expected.write_allowed}, got ${pi.writeAllowed}`);
    }
  }

  console.log(`PASS: ${name}`);
}
' "$ROOT_DIR" "$TMP_ROOT" "$HAS_BUN"
