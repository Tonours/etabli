#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'ledger selection performance smoke: %s\n' "$1" >&2
  exit 1
}

export ROOT_DIR TMP_DIR

node --input-type=module <<'EOF'
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const { selectActiveLedger } = await import(
  pathToFileURL(join(process.env.ROOT_DIR, "scripts/lib/ledger-integrity.mjs")).href,
);

const root = process.env.TMP_DIR;
const workflow = join(root, ".workflow");

function event(run, name, detail) {
  return JSON.stringify({
    schema_version: 2,
    ts: "2026-08-01T00:00:00Z",
    run,
    event: name,
    detail,
  });
}

function writeLedger(run, lines) {
  const dir = join(workflow, run);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "events.jsonl"), lines.join("\n") + "\n");
}

for (let index = 0; index < 50; index += 1) {
  const run = `history-${index}`;
  writeLedger(run, [event(run, "completed", { summary: "done" })]);
}

// This mirrors the Mac mini ledger that was invalid only because compatibility
// events followed a terminal event.
writeLedger("etabli--proved", [
  event("etabli--proved", "completed", { summary: "historical done" }),
  event("etabli--proved", "validation_run", { command: "post-terminal", exit: 0 }),
]);

writeLedger("pointer-live", [event("pointer-live", "route_decided", { route: "implement" })]);
writeFileSync(join(workflow, "active-run.json"), JSON.stringify({ schema_version: 1, run: "pointer-live" }));

const pointerSamples = [];
for (let index = 0; index < 20; index += 1) {
  const start = process.hrtime.bigint();
  const selection = selectActiveLedger(root);
  pointerSamples.push(Number(process.hrtime.bigint() - start) / 1e6);
  if (selection.reason || selection.inspection.records.length !== 1 || selection.ledger.run !== "pointer-live") {
    throw new Error("pointer selection was not bounded to the selected ledger");
  }
}

rmSync(join(workflow, "active-run.json"));
writeLedger("pointer-live", [event("pointer-live", "completed", { summary: "closed" })]);
writeLedger("legacy-live", [event("legacy-live", "route_decided", { route: "implement" })]);
const legacySelection = selectActiveLedger(root);
if (legacySelection.reason || legacySelection.ledger.run !== "legacy-live") {
  throw new Error("legacy fallback failed to select the only valid active ledger");
}

pointerSamples.shift();
console.log(JSON.stringify({
  pointer_records_inspected: 1,
  pointer_mean_ms: pointerSamples.reduce((sum, value) => sum + value, 0) / pointerSamples.length,
  legacy_records_inspected: legacySelection.inspection.records.length,
  historical_invalid_ignored: true,
}));
EOF

printf 'ledger selection performance smoke test: ok\n'
