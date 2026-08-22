#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
FIXTURES="$ROOT_DIR/tests/fixtures/session-handoff"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT="$TMP_DIR/project"
mkdir -p "$PROJECT/.workflow/handoff-fixture" "$PROJECT/.workflow/handoff-unresolved" "$PROJECT/.workflow/handoff-program"
cp "$FIXTURES/handoff-plan.fixture" "$PROJECT/PLAN.md"
cp "$FIXTURES/active-run.json" "$PROJECT/.workflow/.active-run.json"
cp "$FIXTURES/events.jsonl" "$PROJECT/.workflow/handoff-fixture/events.jsonl"
cp "$FIXTURES/unresolved-events.jsonl" "$PROJECT/.workflow/handoff-unresolved/events.jsonl"

jq -n '{
  schema_version: 2,
  program_id: "handoff-program",
  goal: "resume a bounded program",
  coordinator_id: "parent",
  artifact_root: ".workflow/handoff-program/artifacts",
  authorization: {
    max_in_flight: 2,
    allowed_files: ["work"],
    allowed_tools: ["apply_patch", "exec_command"],
    forbidden_actions: ["external_write", "push", "pull_request", "deploy", "production", "billing", "secrets", "destructive_cleanup"],
    worktree_policy: "required",
    independent_verifier: {required: true, distinct_model_family: true},
    pilot_unit_id: "pilot"
  },
  units: [
    {
      id: "pilot", objective: "validate the pilot", dependencies: [],
      allowed_files: ["work/pilot"], allowed_tools: ["apply_patch", "exec_command"],
      verification: {command: ["verify", "pilot"], evidence: "pilot receipt"}, retry_limit: 1,
      context: ["bounded pilot context"], acceptance: ["pilot is independently verified"],
      timebox_minutes: 30, report_artifact_prefix: ".workflow/handoff-program/artifacts/pilot"
    },
    {
      id: "unit-b", objective: "validate the second unit", dependencies: [],
      allowed_files: ["work/unit-b"], allowed_tools: ["apply_patch", "exec_command"],
      verification: {command: ["verify", "unit-b"], evidence: "unit-b receipt"}, retry_limit: 1,
      context: ["bounded unit-b context"], acceptance: ["unit-b is independently verified"],
      timebox_minutes: 30, report_artifact_prefix: ".workflow/handoff-program/artifacts/unit-b"
    }
  ]
}' >"$PROJECT/.workflow/handoff-program/program.json"
program_manifest_sha="$(shasum -a 256 "$PROJECT/.workflow/handoff-program/program.json" | awk '{print $1}')"
jq -nc --arg manifest_sha "$program_manifest_sha" '{
  schema_version: 2,
  ts: "2026-08-20T12:00:00Z",
  event: "program_initialized",
  run: "handoff-program",
  detail: {
    event_id: ("0" * 64),
    program_id: "handoff-program",
    manifest_sha256: $manifest_sha,
    unit_id: "__program__",
    attempt_id: "__program__",
    emitter: {id: "parent", role: "coordinator"},
    manifest_path: ".workflow/handoff-program/program.json",
    runtime_capability: "proxy_supported"
  }
}' >"$PROJECT/.workflow/handoff-program/events.jsonl"
jq -nc '{
  schema_version: 2,
  ts: "2026-08-20T12:01:00Z",
  event: "handoff",
  run: "handoff-program",
  detail: {
    done: ["stale program projection"],
    pending: ["unit-b"],
    next_action: "start program unit unit-b",
    do_not_redo: []
  }
}' >>"$PROJECT/.workflow/handoff-program/events.jsonl"

"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --json >"$TMP_DIR/handoff.json"
jq -e '
  .schema_version == 1 and
  .run == "handoff-fixture" and
  (.objective | contains("cold resume")) and
  .state == "handoff event recorded" and
  .decisions == ["preserve the current validator","bound resume output"] and
  .done == ["session parser fixture","resume output fixture"] and
  .pending == ["runtime visibility fixture","full validation"] and
  .blocker == null and
  .next_action == "implement the runtime visibility fixture" and
  .do_not_redo == ["obsolete parser hypothesis"] and
  .program == null and
  .git.available == false and
  .projection_only == true
' "$TMP_DIR/handoff.json" >/dev/null

"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-program --json >"$TMP_DIR/program.json"
jq -e '
  .program.program_id == "handoff-program" and
  .program.replay_valid == true and
  .program.replay_complete == false and
  .program.execution == "proxy_supported" and
  .program.runtime_confirmed == false and
  .program.counts.units == 2 and
  .program.ready_units == ["pilot"] and
  .program.verified_units == [] and
  .program.frontier == [
    {unit_id: "pilot", status: "pending", head: null, result_head: null, verdict_head: null},
    {unit_id: "unit-b", status: "pending", head: null, result_head: null, verdict_head: null}
  ] and
  .next_action == "start program unit pilot"
' "$TMP_DIR/program.json" >/dev/null

node --input-type=module - "$ROOT_DIR" "$PROJECT" <<'NODE'
import { createHash } from "node:crypto"
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { pathToFileURL } from "node:url"

const root = process.argv[2]
const project = process.argv[3]
const { programNextAction } = await import(pathToFileURL(join(root, "scripts/lib/session-handoff.mjs")))
const action = programNextAction({
  error: null,
  ready_units: [],
  frontier: [
    { unit_id: "a-dependent", status: "stale" },
    { unit_id: "z-prerequisite", status: "running" },
  ],
})
if (action !== "continue program unit z-prerequisite from running") {
  throw new Error(`stale blocked unit won next action: ${action}`)
}

const sha = (value) => createHash("sha256").update(value).digest("hex")
const manifestPath = join(project, ".workflow/handoff-program/program.json")
const eventsPath = join(project, ".workflow/handoff-program/events.jsonl")
const manifestBytes = readFileSync(manifestPath)
const manifest = JSON.parse(manifestBytes)
const manifestSha = sha(manifestBytes)
const envelopes = []
let counter = 0
for (const unit of manifest.units) {
  const attemptId = `${unit.id}-a1`
  const head = sha(`handoff:${unit.id}:head`)
  const artifactDirectory = join(project, unit.report_artifact_prefix)
  mkdirSync(artifactDirectory, { recursive: true })
  const reportPath = join(artifactDirectory, "result.json")
  const report = {
    schema_version: 1,
    unit_id: unit.id,
    attempt_id: attemptId,
    head,
    status: "passed",
    summary: `completed ${unit.id}`,
    changed_files: unit.allowed_files,
    validation: [{ command: unit.verification.command, exit: 0, evidence: unit.verification.evidence }],
    blockers: [],
  }
  writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`)
  const verdictPath = join(artifactDirectory, "verdict.txt")
  writeFileSync(verdictPath, `verified ${unit.id}\n`)
  const common = (event) => ({
    event_id: sha(`handoff:${event}:${unit.id}:${counter++}`),
    program_id: manifest.program_id,
    manifest_sha256: manifestSha,
    unit_id: unit.id,
    attempt_id: attemptId,
    emitter: { id: "parent", role: "coordinator" },
  })
  const wrap = (event, detail) => ({ schema_version: 2, ts: "2026-08-20T12:02:00Z", event, run: "handoff-program", detail })
  envelopes.push(
    wrap("program_unit_started", {
      ...common("start"),
      worker: { id: `worker-${unit.id}`, model_family: "family-a", worktree: `/tmp/handoff-${unit.id}`, branch: `work/${unit.id}`, head },
      files: unit.allowed_files,
      tools: unit.allowed_tools,
    }),
    wrap("program_unit_result", {
      ...common("result"),
      worker_id: `worker-${unit.id}`,
      head,
      status: "passed",
      artifact: { path: `${unit.report_artifact_prefix}/result.json`, sha256: sha(readFileSync(reportPath)) },
    }),
    wrap("program_unit_verdict", {
      ...common("verdict"),
      verifier: { id: `verifier-${unit.id}`, model_family: "family-b" },
      head,
      verdict: "passed",
      evidence: { path: `${unit.report_artifact_prefix}/verdict.txt`, sha256: sha(readFileSync(verdictPath)) },
    }),
  )
}
appendFileSync(eventsPath, `${envelopes.map((event) => JSON.stringify(event)).join("\n")}\n`)
NODE

"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-program --json >"$TMP_DIR/program-complete.json"
jq -e '
  .program.replay_complete == true and
  .program.ready_units == [] and
  .program.frontier == [] and
  .next_action == "program replay complete; continue with planned validation"
' "$TMP_DIR/program-complete.json" >/dev/null

"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-unresolved --json >"$TMP_DIR/unresolved.json"
jq -e '.blocker == "privacy boundary remains open" and .validations[-1].command == "bash tests/unrelated-green.sh"' "$TMP_DIR/unresolved.json" >/dev/null

LONG_ARG="$(printf '%0500d' 0)"
jq -nc --arg command "bash tests/long-$LONG_ARG.sh" '{schema_version:2,ts:"2026-08-10T09:03:00Z",event:"validation_run",run:"handoff-unresolved",detail:{command:$command,exit:0}}' \
  >>"$PROJECT/.workflow/handoff-unresolved/events.jsonl"
"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-unresolved --json >"$TMP_DIR/bounded.json"
jq -e '.blocker == "privacy boundary remains open" and (.validations[-1].command | length) <= 240' "$TMP_DIR/bounded.json" >/dev/null

"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" >"$TMP_DIR/handoff.md"
for needle in '# Session handoff' '## Done' '## Validations' '## Blocker' '## Next action' '## Do not redo' 'implement the runtime visibility fixture' 'obsolete parser hypothesis'; do
  grep -Fq -- "$needle" "$TMP_DIR/handoff.md" || { printf 'handoff markdown misses: %s\n' "$needle" >&2; exit 1; }
done

"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-program >"$TMP_DIR/program.md"
grep -Fq -- '## Program frontier' "$TMP_DIR/program.md" || { printf 'program handoff markdown misses program frontier\n' >&2; exit 1; }
grep -Fq -- 'Replay: complete' "$TMP_DIR/program.md" || { printf 'program handoff markdown misses completed replay\n' >&2; exit 1; }
grep -Fq -- 'Ready: none' "$TMP_DIR/program.md" || { printf 'program handoff markdown misses empty completed frontier\n' >&2; exit 1; }
grep -Fq -- 'program replay complete; continue with planned validation' "$TMP_DIR/program.md" || { printf 'program handoff markdown misses terminal next action\n' >&2; exit 1; }

if grep -Fiq -- 'transcript' "$TMP_DIR/handoff.json"; then
  printf 'handoff output should not reference transcript content\n' >&2
  exit 1
fi

before_hash="$(shasum -a 256 "$PROJECT/.workflow/handoff-fixture/events.jsonl" | awk '{print $1}')"
"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-fixture >/dev/null
after_hash="$(shasum -a 256 "$PROJECT/.workflow/handoff-fixture/events.jsonl" | awk '{print $1}')"
[ "$before_hash" = "$after_hash" ] || { printf 'session handoff must not mutate the ledger\n' >&2; exit 1; }

if "$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run missing >/dev/null 2>&1; then
  printf 'missing explicit run should fail closed\n' >&2
  exit 1
fi

printf 'session handoff smoke test: ok\n'
