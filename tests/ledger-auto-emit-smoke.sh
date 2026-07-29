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
import { mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { join } from "node:path";

const mod = await import(pathToFileURL("$ROOT_DIR/scripts/lib/ledger-auto-emit.mjs").href);
const tmp = "$TMP";

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
  JSON.stringify({ schema_version: 2, event: "route_decided", detail: { route: "implement" } }) + "\\n",
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
  JSON.stringify({ schema_version: 2, event: "completed", detail: { summary: "done" } }) + "\\n",
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

console.log("ledger-auto-emit smoke test: ok");
EOF
