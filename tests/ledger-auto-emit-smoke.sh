#!/usr/bin/env bash
# Ledger-scoped auto-emit of validation_failed / no_progress.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'ledger-auto-emit smoke: %s\n' "$1" >&2
  exit 1
}

node --input-type=module <<EOF
import { pathToFileURL } from "node:url";
import { mkdirSync, writeFileSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const mod = await import(pathToFileURL("$ROOT_DIR/scripts/lib/ledger-auto-emit.mjs").href);
const tmp = "$TMP";

if (mod.isLikelyValidationCommand("npm install test")) {
  console.error("mutating npm install lookalike must not count as validation");
  process.exit(1);
}
if (mod.isLikelyValidationCommand("node tools/build-cache.js")) {
  console.error("mutating build helper must not count as validation");
  process.exit(1);
}
if (!mod.isLikelyValidationCommand("npm test")) {
  console.error("npm test must count as validation");
  process.exit(1);
}
for (const command of [
  "npm test && rm -rf out",
  "bash tests/a.sh | tee out",
  "scripts/verify-agentic-infra core; touch out",
  "npm test\nrm -rf out",
  "bash scripts/check-fix-symlinks.sh --fix",
  "bash tests/../scripts/check-fix-symlinks.sh --fix",
  "node test",
  "cd ../outside && npm test",
]) {
  if (mod.isLikelyValidationCommand(command)) {
    console.error("shell suffix must invalidate validation command: " + command);
    process.exit(1);
  }
}

// No ledger → no emit
const none = mod.recordBashValidationFailure(tmp, {
  command: "bash tests/a.sh",
  exit: 1,
  failure: "red",
});
if (none.emitted) {
  console.error("expected no emit without ledger", none);
  process.exit(1);
}

// Active ledger → validation_failed
mkdirSync(join(tmp, ".workflow", "run-a"), { recursive: true });
writeFileSync(
  join(tmp, ".workflow", "run-a", "events.jsonl"),
  JSON.stringify({ schema_version: 2, ts: "2026-08-01T00:00:00Z", run: "run-a", event: "route_decided", detail: { route: "implement" } }) + "\\n",
);

const one = mod.recordBashValidationFailure(tmp, {
  command: "bash tests/a.sh",
  exit: 1,
  failure: "suite red",
  head_sha: "abc1234",
});
if (!one.emitted || !one.events.includes("validation_failed")) {
  console.error("expected validation_failed", one);
  process.exit(1);
}

// 2x same hypothesis failure (threshold=2) → no_progress on second emit
const two = mod.recordBashValidationFailure(tmp, {
  command: "bash tests/a.sh",
  exit: 1,
  failure: "suite red",
  head_sha: "abc1234",
});
if (!two.emitted || !two.events.includes("no_progress")) {
  console.error(
    "expected no_progress after 2 identical validation failures",
    two,
    readFileSync(join(tmp, ".workflow", "run-a", "events.jsonl"), "utf8"),
  );
  process.exit(1);
}

const text = readFileSync(join(tmp, ".workflow", "run-a", "events.jsonl"), "utf8");
if (!text.includes('"event":"no_progress"')) {
  console.error("ledger missing no_progress event");
  process.exit(1);
}

// Terminal ledger → no emit
writeFileSync(
  join(tmp, ".workflow", "run-a", "events.jsonl"),
  JSON.stringify({ schema_version: 2, ts: "2026-08-01T00:00:00Z", run: "run-a", event: "completed", detail: { summary: "done" } }) + "\\n",
);
const term = mod.recordBashValidationFailure(tmp, {
  command: "bash tests/a.sh",
  exit: 1,
  failure: "suite red",
});
if (term.emitted) {
  console.error("expected no emit on terminal ledger", term);
  process.exit(1);
}

const realWriter = (ledgerPath, run, detail) => {
  try {
    mod.appendLedgerEvent(ledgerPath, "correction", detail, run);
    return true;
  } catch {
    return false;
  }
};

const first = mod.registerUserPrompt(tmp, "sess-1", "pi", "initial instruction", realWriter);
if (first.emitted || first.reason !== "session_start") {
  console.error("first prompt of a session must be silent", first);
  process.exit(1);
}

mkdirSync(join(tmp, ".workflow", "run-b"), { recursive: true });
writeFileSync(
  join(tmp, ".workflow", "run-b", "events.jsonl"),
  JSON.stringify({ schema_version: 2, ts: "2026-08-01T00:00:00Z", run: "run-b", event: "route_decided", detail: { route: "implement", reason: "smoke" } }) + "\\n",
);

const second = mod.registerUserPrompt(tmp, "sess-1", "pi", "non, fais plutot X", realWriter);
if (!second.emitted || second.run !== "run-b") {
  console.error("second prompt during an active run must emit a correction", second);
  process.exit(1);
}

const other = mod.registerUserPrompt(tmp, "sess-2", "claude", "premier message d une autre session", realWriter);
if (other.emitted || other.reason !== "session_start") {
  console.error("session counts must be independent", other);
  process.exit(1);
}

const failed = mod.registerUserPrompt(tmp, "sess-1", "pi", "troisieme", () => false);
if (failed.emitted || failed.reason !== "append_failed") {
  console.error("writer failure must surface append_failed", failed);
  process.exit(1);
}

const third = mod.registerUserPrompt(tmp, "sess-1", "pi", "encore une correction", realWriter);
if (!third.emitted || third.count !== 4) {
  console.error("prompt count must survive a failed append", third);
  process.exit(1);
}

writeFileSync(
  join(tmp, ".workflow", "run-b", "events.jsonl"),
  readFileSync(join(tmp, ".workflow", "run-b", "events.jsonl"), "utf8") +
    JSON.stringify({ schema_version: 2, ts: "2026-12-31T00:05:00Z", run: "run-b", event: "completed", detail: { summary: "done" } }) + "\\n",
);
const afterTerminal = mod.registerUserPrompt(tmp, "sess-1", "pi", "prompt post-terminal", realWriter);
if (afterTerminal.emitted) {
  console.error("no correction may follow a terminal event", afterTerminal);
  process.exit(1);
}
const terminalText = readFileSync(join(tmp, ".workflow", "run-b", "events.jsonl"), "utf8");
const terminalLines = terminalText.trim().split("\\n");
if (JSON.parse(terminalLines.at(-1)).event !== "completed") {
  console.error("terminal event must remain the final line");
  process.exit(1);
}

const ledgerText = readFileSync(join(tmp, ".workflow", "run-b", "events.jsonl"), "utf8");
if (!ledgerText.includes('"event":"correction"')) {
  console.error("correction event missing from ledger");
  process.exit(1);
}
for (const secret of ["fais plutot", "encore une correction", "troisieme"]) {
  if (ledgerText.includes(secret)) {
    console.error("ledger must never contain prompt text: " + secret);
    process.exit(1);
  }
}
const stateDir = join(tmp, ".workflow", "correction-state");
const stateFiles = readdirSync(stateDir).filter((f) => f.endsWith(".json"));
if (stateFiles.length < 1) {
  console.error("per-session state files expected");
  process.exit(1);
}
const stateText = stateFiles.map((f) => readFileSync(join(stateDir, f), "utf8")).join("");
if (stateText.includes("fais plutot")) {
  console.error("state file must never contain prompt text");
  process.exit(1);
}

console.log("ledger-auto-emit smoke test: ok");
EOF

if ! "$ROOT_DIR/scripts/workflow-event" --dir "$TMP/.workflow" validate run-b >/dev/null 2>&1; then
  fail "run-b ledger with correction events must validate"
fi

ROOT_DIR="$ROOT_DIR" node --input-type=module <<'NODE'
const { inferBashFailureFromToolResult: infer } = await import(`${process.env.ROOT_DIR}/scripts/lib/ledger-auto-emit.mjs`);
const cases = [
  ["successful output that prints exit 1", "checking\nexit 1 is expected here", false, { failed: false }],
  ["Pi bash failure", "boom\n\nCommand exited with code 2", true, { failed: true, exit: 2 }],
  ["Claude PostToolUseFailure error", "Exit code 1\nError: Cannot find module", true, { failed: true, exit: 1 }],
  ["error without an exit code", "spawn failed", true, { failed: true, exit: 1 }],
];
for (const [label, text, isError, expected] of cases) {
  const actual = infer([{ type: "text", text }], isError);
  if (actual.failed !== expected.failed || (expected.exit && actual.exit !== expected.exit)) {
    console.error(`infer ${label}: ${JSON.stringify(actual)}`);
    process.exit(1);
  }
}
NODE

hook_root="$TMP/claude-hook"
mkdir -p "$hook_root/.workflow/run-c"
printf '%s\n' '{"schema_version":2,"ts":"2026-08-01T00:00:00Z","run":"run-c","event":"route_decided","detail":{"route":"implement"}}' >"$hook_root/.workflow/run-c/events.jsonl"
printf '{"cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"bash tests/a.sh"},"tool_response":{"stdout":"exit 1 printed by a passing test","stderr":"","interrupted":false}}\n' "$hook_root" |
  node "$ROOT_DIR/claude/hooks/ledger-auto-emit.mjs"
if grep -q validation_failed "$hook_root/.workflow/run-c/events.jsonl"; then
  fail "a passing Bash call must not record validation_failed"
fi
printf '{"cwd":"%s","hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"bash tests/a.sh"},"error":"Exit code 3\\nsuite red","is_interrupt":false}\n' "$hook_root" |
  node "$ROOT_DIR/claude/hooks/ledger-auto-emit.mjs"
grep -q '"event":"validation_failed"' "$hook_root/.workflow/run-c/events.jsonl" ||
  fail "PostToolUseFailure must record validation_failed"
grep -q '"exit":3' "$hook_root/.workflow/run-c/events.jsonl" ||
  fail "PostToolUseFailure must keep the exit code"
