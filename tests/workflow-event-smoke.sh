#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_contains() {
  local text="$1"
  local needle="$2"

  case "$text" in
    *"$needle"*) ;;
    *)
      printf 'expected output to contain: %s\noutput was:\n%s\n' "$needle" "$text" >&2
      exit 1
      ;;
  esac
}

expect_status() {
  local expected="$1"
  shift
  set +e
  output="$("$@" 2>&1)"
  status="$?"
  set -e
  if [ "$status" -ne "$expected" ]; then
    printf 'expected status %s, got %s\ncommand: %s\noutput:\n%s\n' "$expected" "$status" "$*" "$output" >&2
    exit 1
  fi
  printf '%s' "$output"
}

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a route_decided '{"route":"plan-loop","reason":"test"}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a validation_run '{"command":"true","exit":0}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a completed '{"summary":"done"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-a)"
assert_contains "$out" "3 events, ok"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-dogfood dogfood_matrix_created '{"path":"docs/dogfood.md","flows":1,"scenarios":2}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-dogfood dogfood_scenario_run '{"scenario":"reply-email-link","surface":"browser","status":"fail","artifacts":["trace.zip"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-dogfood dogfood_fix_applied '{"scenario":"reply-email-link","fix":"correct reply anchor","evidence":"rerun passed"}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-dogfood dogfood_blocked '{"scenario":"real-inbox-click","reason":"blocked-human-verify","needed_input":"human inbox verification"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-dogfood)"
assert_contains "$out" "4 events, ok"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning self_improvement_candidate '{"source":"events.jsonl","category":"router_miss","outcome":"router_fixture","confidence":"confirmed","evidence":["fixture"],"held_in":["misrouted prompt fixture"],"held_out":["read-only explanation fixture"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning harness_failure_pattern '{"terminal_cause":"router miss","causal_status":"confirmed","mechanism":"review pattern shadowed self-improvement route","verifier":"router eval","traces":["tests/router-evals/core.json"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning harness_proposal '{"candidate":"split explicit review guard","editable_surfaces":["pi/extensions/lib/workflow-router-runtime.ts","claude/hooks/workflow-router-lib.mjs"],"preserve":["read-only explanations stay answer"],"held_in":["self-improvement prompt routes plan-implement"],"held_out":["explicit self-improvement review stays review"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning harness_candidate_rejected '{"candidate":"auto-apply workflow-retrospect patches","reason":"bypasses reviewed PLAN.md gate","regressions":["external write-back risk","permission boundary weakened"],"evidence":["workflow/skills/self-improvement-loop.md"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning project_slice_planned '{"slice":"spec","owner":"planner","validation":"review","dependencies":[]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning project_slice_completed '{"slice":"spec","validation":"passed","evidence":["docs/spec.md"],"remaining":[]}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-learning)"
assert_contains "$out" "6 events, ok"
jq -e 'select(.event == "harness_proposal") | .detail.held_in[0] and .detail.held_out[0]' "$EVENT_DIR/run-learning/events.jsonl" >/dev/null
jq -e 'select(.event == "harness_candidate_rejected") | .detail.regressions[0] and .detail.evidence[0]' "$EVENT_DIR/run-learning/events.jsonl" >/dev/null

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-runtime runtime_run_attached '{"adapter":"pi-workflow","run_id":"workflow_mq224pi8_775e71","workflow":"spec-review","state_path":".pi/workflows/workflow_mq224pi8_775e71","status":"running","usage_measured":false}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-runtime)"
assert_contains "$out" "1 events, ok"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-runtime-bad runtime_run_attached '{"adapter":"pi-workflow","run_id":"workflow_bad","workflow":"spec-review","state_path":".pi/workflows/another-run","status":"running","usage_measured":false}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-runtime-bad runtime_run_attached '{"adapter":"pi-workflow","run_id":"workflow_bad","workflow":"spec-review","state_path":".pi/workflows/workflow_bad","status":"pending","usage_measured":false}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-b nope '{}')"
assert_contains "$out" "Allowed events"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-b route_decided '{bad')"
assert_contains "$out" "invalid json detail"

out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate missing-run)"
assert_contains "$out" "missing ledger"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate missing-run --allow-missing)"
assert_contains "$out" "legacy allow-missing"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-b route_decided '{"route":"plan-loop"}')"
assert_contains "$out" "required fields"

mkdir -p "$EVENT_DIR/run-terminal"
printf '%s\n' \
  '{"schema_version":1,"ts":"2026-07-09T10:00:00Z","event":"completed","run":"run-terminal","detail":{"summary":"done"}}' \
  '{"schema_version":1,"ts":"2026-07-09T10:00:01Z","event":"validation_run","run":"run-terminal","detail":{"command":"true","exit":0}}' \
  > "$EVENT_DIR/run-terminal/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-terminal)"
assert_contains "$out" "follows terminal"

for event_detail in \
  'route_decided {"route":"plan-implement","reason":"implementation"}' \
  'plan_created {"path":"PLAN.md","status":"READY"}' \
  'adversary_completed {"mode":"plan","verdict":"READY","accepted_findings":[],"rejected_findings":[]}' \
  'file_changed {"path":"src/example.ts","change":"updated"}' \
  'validation_run {"command":"true","exit":0}' \
  'simplification_completed {"status":"passed","evidence":"diff inspected"}' \
  'review_completed {"status":"GO","evidence":"review"}' \
  'adversary_completed {"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[]}' \
  'archive_written {"path":"docs/plan/test.md"}' \
  'outcome_metric {"outcome":"success","success":true,"measured":false}' \
  'plan_removed {"path":"PLAN.md"}' \
  'completed {"summary":"done"}'; do
  event="${event_detail%% *}"
  detail="${event_detail#* }"
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-complete "$event" "$detail"
done
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-complete --profile autonomous-completed)"
assert_contains "$out" "12 events, ok"

printf '{bad\n' >> "$EVENT_DIR/run-a/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-a)"
assert_contains "$out" "line 4"

script_types="$(
  awk '
    /^ALLOWED_EVENTS=\(/ { inside=1; next }
    inside && /^\)/ { inside=0; next }
    inside { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); if ($0 != "") print $0 }
  ' "$ROOT_DIR/scripts/workflow-event" | sort
)"
doc_types="$(
  awk -F'|' '/^\| `[^`]+` / { gsub(/[`[:space:]]/, "", $2); print $2 }' "$ROOT_DIR/workflow/events.md" | sort
)"
if ! diff -u <(printf '%s\n' "$script_types") <(printf '%s\n' "$doc_types"); then
  printf 'workflow event type list drifted between docs and script\n' >&2
  exit 1
fi

if [ -d "$ROOT_DIR/.workflow/plan012-selftest" ]; then
  printf 'smoke test should not write to the repo .workflow directory\n' >&2
  exit 1
fi

printf 'workflow event smoke test: ok\n'
