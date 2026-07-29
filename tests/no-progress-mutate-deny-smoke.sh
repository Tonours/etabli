#!/usr/bin/env bash
# Ledger-backed no_progress mutation deny (shared planMutationGuardDecision).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CORE="$ROOT_DIR/workflow/runtime/workflow-router-core.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'no-progress-mutate-deny smoke: %s\n' "$1" >&2
  exit 1
}

[ -f "$CORE" ] || fail "missing router core"
[ -f "$ROOT_DIR/scripts/lib/no-progress-guard.mjs" ] || fail "missing no-progress-guard.mjs"

node --input-type=module <<EOF
import { pathToFileURL } from "node:url";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const mod = await import(pathToFileURL("$CORE").href);
const tmp = "$TMP";

function writePlan(status) {
  writeFileSync(
    join(tmp, "PLAN.md"),
    [
      "# PLAN",
      "",
      "## Meta",
      \`- Status: \${status}\`,
      "",
      "## Checks",
      "- command: bash tests/a.sh",
      "",
      "## Decision Log",
      "- baseline",
      "",
    ].join("\\n"),
  );
}

function writeLedger(slug, lines) {
  const dir = join(tmp, ".workflow", slug);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "events.jsonl"), lines.map((o) => JSON.stringify(o)).join("\\n") + "\\n");
}

function assertDeny(label, decision) {
  if (decision?.hookSpecificOutput?.permissionDecision !== "deny") {
    console.error(label, "expected deny, got", decision);
    process.exit(1);
  }
  const reason = decision.hookSpecificOutput.permissionDecisionReason || "";
  if (!/no_progress/i.test(reason)) {
    console.error(label, "expected no_progress in reason:", reason);
    process.exit(1);
  }
}

function assertAllow(label, decision) {
  if (decision != null) {
    console.error(label, "expected allow (null), got", decision);
    process.exit(1);
  }
}

// --- no ledger → READY write allowed
writePlan("READY");
assertAllow(
  "no-ledger READY Write",
  mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Write",
    tool_input: { file_path: join(tmp, "src/x.ts"), content: "x" },
  }),
);

// --- terminal ledger only → allow
writeLedger("done-run", [
  { schema_version: 2, event: "route_decided", detail: { route: "implement" } },
  { schema_version: 2, event: "completed", detail: { summary: "done" } },
]);
assertAllow(
  "terminal ledger READY Write",
  mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Write",
    tool_input: { file_path: join(tmp, "src/y.ts"), content: "y" },
  }),
);

// --- explicit no_progress → code Write deny
writeLedger("active-np", [
  { schema_version: 2, event: "route_decided", detail: { route: "implement" } },
  {
    schema_version: 2,
    event: "no_progress",
    detail: {
      check_or_hypothesis: "tests fail",
      command: "bash tests/a.sh",
      attempts: 2,
      eliminated: ["tests fail"],
    },
  },
]);
assertDeny(
  "explicit no_progress Write",
  mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Write",
    tool_input: { file_path: join(tmp, "src/z.ts"), content: "z" },
  }),
);
assertDeny(
  "explicit no_progress pi write",
  mod.planMutationGuardDecision({
    cwd: tmp,
    toolName: "write",
    input: { path: join(tmp, "src/z2.ts"), content: "z2" },
  }),
);
assertDeny(
  "explicit no_progress mutating bash",
  mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Bash",
    tool_input: { command: "echo hi > out.txt" },
  }),
);

// escape hatch: PLAN.md write allowed under stop
assertAllow(
  "escape PLAN.md Write under no_progress",
  mod.planMutationGuardDecision({
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
        "- check-freeze demote: no_progress stop recorded",
        "",
      ].join("\\n"),
    },
  }),
);

// escape hatch: workflow-event bash allowed
assertAllow(
  "escape workflow-event bash",
  mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Bash",
    tool_input: { command: "scripts/workflow-event append --event blocked --run active-np" },
  }),
);
assertAllow(
  "escape node scripts/workflow-event",
  mod.planMutationGuardDecision({
    cwd: tmp,
    toolName: "bash",
    input: { command: "node scripts/workflow-event validate --profile autonomous-completed" },
  }),
);

// non-mutating bash still allowed
assertAllow(
  "read-only bash under no_progress",
  mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Bash",
    tool_input: { command: "ls -la" },
  }),
);

// --- derived: 3x same validation_failed without file_changed → deny
// clear active-np by rewriting as terminal, use fresh slug
writeLedger("active-np", [
  { schema_version: 2, event: "completed", detail: { summary: "closed for derived test" } },
]);
const failEvt = {
  schema_version: 2,
  event: "validation_failed",
  detail: { command: "bash tests/a.sh", exit: 1, failure: "suite red" },
};
writeLedger("derived-red", [
  { schema_version: 2, event: "route_decided", detail: { route: "implement" } },
  failEvt,
  failEvt,
  failEvt,
]);
assertDeny(
  "derived 3-red Write",
  mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Write",
    tool_input: { file_path: join(tmp, "src/d.ts"), content: "d" },
  }),
);

// --- file_changed resets counters → 1 failure after → allow
writeLedger("derived-reset", [
  { schema_version: 2, event: "route_decided", detail: { route: "implement" } },
  failEvt,
  failEvt,
  failEvt,
  { schema_version: 2, event: "file_changed", detail: { path: "src/d.ts", change: "edit" } },
  failEvt,
]);
// derived-red still active and would deny — terminalize it
writeLedger("derived-red", [
  { schema_version: 2, event: "completed", detail: { summary: "done" } },
]);
assertAllow(
  "after file_changed reset + single fail",
  mod.planMutationGuardDecision({
    cwd: tmp,
    tool_name: "Write",
    tool_input: { file_path: join(tmp, "src/e.ts"), content: "e" },
  }),
);

// pure helper unit-ish via core re-export path not required; import lib directly
const guard = await import(pathToFileURL("$ROOT_DIR/scripts/lib/no-progress-guard.mjs").href);
const twoHyp = guard.evaluateNoProgressStop([
  {
    event: "validation_failed",
    detail: { command: "t", exit: 1, failure: "h1" },
  },
  {
    event: "validation_failed",
    detail: { command: "t", exit: 1, failure: "h1" },
  },
]);
if (!twoHyp || twoHyp.reason !== "same_hypothesis_failure_limit") {
  console.error("expected same_hypothesis_failure_limit", twoHyp);
  process.exit(1);
}

console.log("no-progress-mutate-deny smoke test: ok");
EOF
