#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/scripts/lib/hash.sh"
FIXTURES="$ROOT_DIR/tests/fixtures/session-handoff"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT="$TMP_DIR/project"
mkdir -p "$PROJECT/.workflow/handoff-fixture" "$PROJECT/.workflow/handoff-unresolved" "$PROJECT/.workflow/handoff-program"
cp "$FIXTURES/handoff-plan.fixture" "$PROJECT/PLAN.md"
cp "$FIXTURES/active-run.json" "$PROJECT/.workflow/active-run.json"
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
program_manifest_sha="$(hash256 "$PROJECT/.workflow/handoff-program/program.json" | awk '{print $1}')"
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
jq -e '.program.replay_valid == false and (.program.error | test("removed"))' "$TMP_DIR/program.json" >/dev/null ||
  { printf 'program handoff must report the removed control plane\n' >&2; exit 1; }

if grep -Fiq -- 'transcript' "$TMP_DIR/handoff.json"; then
  printf 'handoff output should not reference transcript content\n' >&2
  exit 1
fi

before_hash="$(hash256 "$PROJECT/.workflow/handoff-fixture/events.jsonl" | awk '{print $1}')"
"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-fixture >/dev/null
after_hash="$(hash256 "$PROJECT/.workflow/handoff-fixture/events.jsonl" | awk '{print $1}')"
[ "$before_hash" = "$after_hash" ] || { printf 'session handoff must not mutate the ledger\n' >&2; exit 1; }

if "$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run missing >/dev/null 2>&1; then
  printf 'missing explicit run should fail closed\n' >&2
  exit 1
fi

printf 'session handoff smoke test: ok\n'
