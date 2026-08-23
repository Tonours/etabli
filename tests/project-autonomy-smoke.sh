#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CONTROLLER="$ROOT_DIR/scripts/project-autonomy"
EVENT_TOOL="$ROOT_DIR/scripts/workflow-event"
ENVELOPE="$ROOT_DIR/tests/fixtures/project-autonomy/envelope.json"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"
RUN="fixture-autonomy"
EVENTS="$EVENT_DIR/$RUN/events.jsonl"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'project autonomy smoke: %s\n' "$1" >&2
  exit 1
}

decision() {
  "$CONTROLLER" --envelope "$ENVELOPE" --events "$EVENTS" --now 2026-07-24T10:05:00Z
}

envelope_for_run() {
  local run="$1"
  local path="$TMP_DIR/$run-envelope.json"
  jq --arg run "$run" '.run_id = $run' "$ENVELOPE" >"$path"
  printf '%s\n' "$path"
}

assert_decision() {
  local expected="$1"
  local reason="$2"
  local output
  output="$(decision)"
  printf '%s\n' "$output" | jq -e --arg expected "$expected" --arg reason "$reason" \
    '.decision == $expected and .reason == $reason' >/dev/null ||
    fail "expected $expected/$reason, got $output"
}

[ -x "$CONTROLLER" ] || fail "scripts/project-autonomy is not executable"
node --check "$ROOT_DIR/scripts/lib/project-autonomy.mjs"
jq -e '.schema_version == 1 and .evaluation.sealed_held_out == true' "$ENVELOPE" >/dev/null ||
  fail "fixture does not bind sealed held-out evaluation"
jq -e '
  ((.required | index("run_id")) != null) and
  .properties.budget.properties.max_candidates.maximum == 8 and
  .properties.stop_conditions.properties.same_hypothesis_failures.const == 2 and
  .properties.stop_conditions.properties.red_checks_without_diff.const == 3 and
  .properties.evaluation.properties.sealed_held_out.const == true
' "$ROOT_DIR/workflow/project-autonomy-envelope.schema.json" >/dev/null ||
  fail "schema does not preserve autonomy and held-out bounds"
jq -e '
  .authorization.forbidden_actions | index("external_write") and index("obvault_write")
' "$ROOT_DIR/workflow/templates/project-autonomy-envelope.json" >/dev/null ||
  fail "template does not declare required forbidden actions"

mkdir -p "$EVENT_DIR/$RUN"
: >"$EVENTS"

assert_decision plan_slice next_verifiable_slice

"$EVENT_TOOL" --dir "$EVENT_DIR" append "$RUN" project_slice_planned '{"slice":"contract","owner":"implementer","validation":"node --check scripts/lib/project-autonomy.mjs","dependencies":[]}'
assert_decision execute_slice planned_slice_needs_evidence
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$RUN" project_slice_completed '{"slice":"contract","validation":"passed","evidence":["node --check scripts/lib/project-autonomy.mjs"],"remaining":["verification"]}'
assert_decision await_checkpoint checkpoint_required

"$EVENT_TOOL" --dir "$EVENT_DIR" append "$RUN" human_checkpoint '{"category":"fresh_context_review","decision":"authorized","target":"fixture-autonomy:verification"}'
assert_decision plan_slice next_verifiable_slice
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$RUN" project_slice_planned '{"slice":"verification","owner":"verifier","validation":"scripts/verify-agentic-infra full","dependencies":["contract"]}'
assert_decision execute_slice planned_slice_needs_evidence
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$RUN" project_slice_completed '{"slice":"verification","validation":"passed","evidence":["fresh review authorized"],"remaining":[]}'
assert_decision await_verification evaluation_runner_missing

"$EVENT_TOOL" --dir "$EVENT_DIR" append "$RUN" validation_run '{"command":"scripts/verify-agentic-infra full","exit":0}'
assert_decision await_verification final_state_grader_missing
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$RUN" outcome_metric '{"outcome":"fixture-final-state-grader","success":true,"measured":false,"reason":"deterministic fixture"}'
assert_decision completion_ready all_slices_and_final_state_evidence_passed
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$RUN" completed '{"summary":"fixture autonomy completed"}'
assert_decision stop terminal_completed
"$EVENT_TOOL" --dir "$EVENT_DIR" validate "$RUN" >/dev/null

NO_PROGRESS_RUN="fixture-no-progress"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$NO_PROGRESS_RUN" no_progress '{"check_or_hypothesis":"missing final-state evidence","command":"scripts/verify-agentic-infra full","attempts":2,"head_sha":"deadbeef","eliminated":["claim driver completion is enough"]}'
no_progress_envelope="$(envelope_for_run "$NO_PROGRESS_RUN")"
no_progress_output="$("$CONTROLLER" --envelope "$no_progress_envelope" --events "$EVENT_DIR/$NO_PROGRESS_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$no_progress_output" | jq -e '.decision == "stop" and .reason == "no_progress"' >/dev/null ||
  fail "no-progress did not stop: $no_progress_output"

HYPOTHESIS_RUN="fixture-hypothesis-limit"
for _ in $(seq 1 2); do
  "$EVENT_TOOL" --dir "$EVENT_DIR" append "$HYPOTHESIS_RUN" validation_failed '{"command":"bash tests/project-autonomy-smoke.sh","exit":1,"failure":"missing final-state outcome evidence"}'
done
hypothesis_envelope="$(envelope_for_run "$HYPOTHESIS_RUN")"
hypothesis_output="$("$CONTROLLER" --envelope "$hypothesis_envelope" --events "$EVENT_DIR/$HYPOTHESIS_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$hypothesis_output" | jq -e '
  .decision == "stop" and .reason == "same_hypothesis_failure_limit" and
  .required_event == "no_progress" and .no_progress.attempts == 2
' >/dev/null || fail "same-hypothesis limit did not stop: $hypothesis_output"

DISTINCT_COMMAND_RUN="fixture-distinct-commands"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$DISTINCT_COMMAND_RUN" validation_failed '{"command":"check-one","exit":1,"failure":"shared text"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$DISTINCT_COMMAND_RUN" validation_failed '{"command":"check-two","exit":1,"failure":"shared text"}'
distinct_command_envelope="$(envelope_for_run "$DISTINCT_COMMAND_RUN")"
distinct_command_output="$("$CONTROLLER" --envelope "$distinct_command_envelope" --events "$EVENT_DIR/$DISTINCT_COMMAND_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$distinct_command_output" | jq -e '.decision == "plan_slice" and .reason == "next_verifiable_slice"' >/dev/null ||
  fail "different commands were misclassified as one failed hypothesis: $distinct_command_output"

RED_CHECK_RUN="fixture-red-check-limit"
for attempt in 1 2 3; do
  "$EVENT_TOOL" --dir "$EVENT_DIR" append "$RED_CHECK_RUN" validation_failed "{\"command\":\"bash tests/project-autonomy-smoke.sh\",\"exit\":1,\"failure\":\"red check attempt $attempt\"}"
done
red_check_envelope="$(envelope_for_run "$RED_CHECK_RUN")"
red_check_output="$("$CONTROLLER" --envelope "$red_check_envelope" --events "$EVENT_DIR/$RED_CHECK_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$red_check_output" | jq -e '
  .decision == "stop" and .reason == "red_check_without_diff_limit" and
  .required_event == "no_progress" and .no_progress.attempts == 3
' >/dev/null || fail "red-check limit did not stop: $red_check_output"

CANDIDATE_RUN="fixture-candidates"
for _ in $(seq 1 8); do
  "$EVENT_TOOL" --dir "$EVENT_DIR" append "$CANDIDATE_RUN" self_improvement_candidate '{"source":"events.jsonl","category":"router_miss","outcome":"router_fixture","confidence":"confirmed","evidence":["fixture"]}'
done
candidate_envelope="$(envelope_for_run "$CANDIDATE_RUN")"
candidate_output="$("$CONTROLLER" --envelope "$candidate_envelope" --events "$EVENT_DIR/$CANDIDATE_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$candidate_output" | jq -e '.decision == "stop" and .reason == "candidate_budget_exhausted" and .max_candidates == 8' >/dev/null ||
  fail "candidate cap did not stop: $candidate_output"

duration_output="$("$CONTROLLER" --envelope "$no_progress_envelope" --events "$EVENT_DIR/$NO_PROGRESS_RUN/events.jsonl" --now 2026-07-24T10:31:00Z)"
printf '%s\n' "$duration_output" | jq -e '.decision == "stop" and .reason == "no_progress"' >/dev/null ||
  fail "no-progress must outrank duration: $duration_output"

EMPTY_RUN="fixture-empty"
EMPTY_EVENTS="$EVENT_DIR/$EMPTY_RUN/events.jsonl"
mkdir -p "$EVENT_DIR/$EMPTY_RUN"
: >"$EMPTY_EVENTS"
empty_envelope="$(envelope_for_run "$EMPTY_RUN")"
duration_output="$("$CONTROLLER" --envelope "$empty_envelope" --events "$EMPTY_EVENTS" --now 2026-07-24T10:31:00Z)"
printf '%s\n' "$duration_output" | jq -e '.decision == "stop" and .reason == "duration_budget_exhausted"' >/dev/null ||
  fail "duration cap did not stop: $duration_output"

invalid_envelope="$TMP_DIR/invalid-envelope.json"
jq 'del(.evaluation.sealed_held_out)' "$ENVELOPE" >"$invalid_envelope"
invalid_output="$("$CONTROLLER" --envelope "$invalid_envelope" --events "$EMPTY_EVENTS" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$invalid_output" | jq -e '.decision == "stop" and .reason == "invalid_envelope" and (.errors | length) > 0' >/dev/null ||
  fail "invalid envelope was accepted: $invalid_output"

misbound_envelope="$TMP_DIR/misbound-envelope.json"
jq '.slices[0].checkpoint_id = "fresh-review"' "$ENVELOPE" >"$misbound_envelope"
misbound_output="$("$CONTROLLER" --envelope "$misbound_envelope" --events "$EMPTY_EVENTS" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$misbound_output" | jq -e '.decision == "stop" and .reason == "invalid_envelope"' >/dev/null ||
  fail "misbound checkpoint was accepted: $misbound_output"

null_checkpoint_envelope="$TMP_DIR/null-checkpoint-envelope.json"
jq '.checkpoints = [null]' "$ENVELOPE" >"$null_checkpoint_envelope"
null_checkpoint_output="$("$CONTROLLER" --envelope "$null_checkpoint_envelope" --events "$EMPTY_EVENTS" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$null_checkpoint_output" | jq -e '.decision == "stop" and .reason == "invalid_envelope"' >/dev/null ||
  fail "null checkpoint crashed or passed: $null_checkpoint_output"

bad_authorization_envelope="$TMP_DIR/bad-authorization-envelope.json"
jq '.authorization.allowed_files = "workflow/**"' "$ENVELOPE" >"$bad_authorization_envelope"
bad_authorization_output="$("$CONTROLLER" --envelope "$bad_authorization_envelope" --events "$EMPTY_EVENTS" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$bad_authorization_output" | jq -e '.decision == "stop" and .reason == "invalid_envelope"' >/dev/null ||
  fail "bad authorization crashed or passed: $bad_authorization_output"

unbounded_authorization_envelope="$TMP_DIR/unbounded-authorization-envelope.json"
jq '.authorization.allowed_files = ["**"]' "$empty_envelope" >"$unbounded_authorization_envelope"
unbounded_authorization_output="$("$CONTROLLER" --envelope "$unbounded_authorization_envelope" --events "$EMPTY_EVENTS" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$unbounded_authorization_output" | jq -e '.decision == "stop" and .reason == "invalid_envelope"' >/dev/null ||
  fail "unbounded authorization scope was accepted: $unbounded_authorization_output"

unbounded_slice_envelope="$TMP_DIR/unbounded-slice-envelope.json"
jq '.slices[0].allowed_files = ["**"]' "$empty_envelope" >"$unbounded_slice_envelope"
unbounded_slice_output="$("$CONTROLLER" --envelope "$unbounded_slice_envelope" --events "$EMPTY_EVENTS" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$unbounded_slice_output" | jq -e '.decision == "stop" and .reason == "invalid_envelope"' >/dev/null ||
  fail "unbounded slice scope was accepted: $unbounded_slice_output"

UNKNOWN_RUN="fixture-unknown-slice"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$UNKNOWN_RUN" project_slice_planned '{"slice":"not-authorized","owner":"implementer","validation":"fixture","dependencies":[]}'
unknown_envelope="$(envelope_for_run "$UNKNOWN_RUN")"
unknown_output="$("$CONTROLLER" --envelope "$unknown_envelope" --events "$EVENT_DIR/$UNKNOWN_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$unknown_output" | jq -e '.decision == "stop" and .reason == "unknown_slice"' >/dev/null ||
  fail "unknown slice was accepted: $unknown_output"

STALE_RUN="fixture-stale-evaluation"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$STALE_RUN" validation_run '{"command":"scripts/verify-agentic-infra full","exit":0}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$STALE_RUN" outcome_metric '{"outcome":"fixture-final-state-grader","success":true,"measured":false,"reason":"stale fixture"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$STALE_RUN" project_slice_planned '{"slice":"contract","owner":"implementer","validation":"node --check scripts/lib/project-autonomy.mjs","dependencies":[]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$STALE_RUN" project_slice_completed '{"slice":"contract","validation":"passed","evidence":["fixture"],"remaining":["verification"]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$STALE_RUN" human_checkpoint '{"category":"fresh_context_review","decision":"authorized","target":"fixture-autonomy:verification"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$STALE_RUN" project_slice_planned '{"slice":"verification","owner":"verifier","validation":"scripts/verify-agentic-infra full","dependencies":["contract"]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$STALE_RUN" project_slice_completed '{"slice":"verification","validation":"passed","evidence":["fixture"],"remaining":[]}'
stale_envelope="$(envelope_for_run "$STALE_RUN")"
stale_output="$("$CONTROLLER" --envelope "$stale_envelope" --events "$EVENT_DIR/$STALE_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$stale_output" | jq -e '.decision == "await_verification" and .reason == "evaluation_runner_missing"' >/dev/null ||
  fail "stale final-state evidence was accepted: $stale_output"

CHECKPOINT_BYPASS_RUN="fixture-checkpoint-bypass"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$CHECKPOINT_BYPASS_RUN" project_slice_planned '{"slice":"contract","owner":"implementer","validation":"node --check scripts/lib/project-autonomy.mjs","dependencies":[]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$CHECKPOINT_BYPASS_RUN" project_slice_completed '{"slice":"contract","validation":"passed","evidence":["fixture"],"remaining":["verification"]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$CHECKPOINT_BYPASS_RUN" project_slice_planned '{"slice":"verification","owner":"verifier","validation":"scripts/verify-agentic-infra full","dependencies":["contract"]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$CHECKPOINT_BYPASS_RUN" project_slice_completed '{"slice":"verification","validation":"passed","evidence":["fixture"],"remaining":[]}'
checkpoint_bypass_envelope="$(envelope_for_run "$CHECKPOINT_BYPASS_RUN")"
checkpoint_bypass_output="$("$CONTROLLER" --envelope "$checkpoint_bypass_envelope" --events "$EVENT_DIR/$CHECKPOINT_BYPASS_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$checkpoint_bypass_output" | jq -e '.decision == "stop" and .reason == "checkpoint_bypassed"' >/dev/null ||
  fail "checkpoint bypass was accepted: $checkpoint_bypass_output"

OUT_OF_ORDER_RUN="fixture-out-of-order"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$OUT_OF_ORDER_RUN" project_slice_planned '{"slice":"verification","owner":"verifier","validation":"scripts/verify-agentic-infra full","dependencies":[]}'
out_of_order_envelope="$(envelope_for_run "$OUT_OF_ORDER_RUN")"
out_of_order_output="$("$CONTROLLER" --envelope "$out_of_order_envelope" --events "$EVENT_DIR/$OUT_OF_ORDER_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$out_of_order_output" | jq -e '.decision == "stop" and .reason == "slice_lifecycle_out_of_order"' >/dev/null ||
  fail "out-of-order slice was accepted: $out_of_order_output"

MUTATION_AFTER_PROOF_RUN="fixture-mutation-after-proof"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$MUTATION_AFTER_PROOF_RUN" project_slice_planned '{"slice":"contract","owner":"implementer","validation":"node --check scripts/lib/project-autonomy.mjs","dependencies":[]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$MUTATION_AFTER_PROOF_RUN" project_slice_completed '{"slice":"contract","validation":"passed","evidence":["fixture"],"remaining":["verification"]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$MUTATION_AFTER_PROOF_RUN" human_checkpoint '{"category":"fresh_context_review","decision":"authorized","target":"fixture-autonomy:verification"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$MUTATION_AFTER_PROOF_RUN" project_slice_planned '{"slice":"verification","owner":"verifier","validation":"scripts/verify-agentic-infra full","dependencies":["contract"]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$MUTATION_AFTER_PROOF_RUN" project_slice_completed '{"slice":"verification","validation":"passed","evidence":["fixture"],"remaining":[]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$MUTATION_AFTER_PROOF_RUN" validation_run '{"command":"scripts/verify-agentic-infra full","exit":0}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$MUTATION_AFTER_PROOF_RUN" outcome_metric '{"outcome":"fixture-final-state-grader","success":true,"measured":false,"reason":"fixture"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$MUTATION_AFTER_PROOF_RUN" file_changed '{"path":"workflow/project-autonomy-envelope.md","change":"post-proof mutation"}'
mutation_after_proof_envelope="$(envelope_for_run "$MUTATION_AFTER_PROOF_RUN")"
mutation_after_proof_output="$("$CONTROLLER" --envelope "$mutation_after_proof_envelope" --events "$EVENT_DIR/$MUTATION_AFTER_PROOF_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$mutation_after_proof_output" | jq -e '.decision == "stop" and .reason == "file_changed_without_active_slice"' >/dev/null ||
  fail "post-proof mutation was accepted without an active slice: $mutation_after_proof_output"

CROSS_RUN="fixture-cross-run"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$CROSS_RUN" validation_run '{"command":"scripts/verify-agentic-infra full","exit":0}'
cross_run_output="$("$CONTROLLER" --envelope "$ENVELOPE" --events "$EVENT_DIR/$CROSS_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$cross_run_output" | jq -e '.decision == "stop" and .reason == "invalid_ledger"' >/dev/null ||
  fail "cross-run ledger was accepted: $cross_run_output"

LATEST_CHECKPOINT_RUN="fixture-latest-checkpoint"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$LATEST_CHECKPOINT_RUN" project_slice_planned '{"slice":"contract","owner":"implementer","validation":"node --check scripts/lib/project-autonomy.mjs","dependencies":[]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$LATEST_CHECKPOINT_RUN" project_slice_completed '{"slice":"contract","validation":"passed","evidence":["fixture"],"remaining":["verification"]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$LATEST_CHECKPOINT_RUN" human_checkpoint '{"category":"fresh_context_review","decision":"authorized","target":"fixture-autonomy:verification"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$LATEST_CHECKPOINT_RUN" human_checkpoint '{"category":"fresh_context_review","decision":"denied","target":"fixture-autonomy:verification"}'
latest_checkpoint_envelope="$(envelope_for_run "$LATEST_CHECKPOINT_RUN")"
latest_checkpoint_output="$("$CONTROLLER" --envelope "$latest_checkpoint_envelope" --events "$EVENT_DIR/$LATEST_CHECKPOINT_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$latest_checkpoint_output" | jq -e '.decision == "stop" and .reason == "checkpoint_denied"' >/dev/null ||
  fail "latest checkpoint denial was ignored: $latest_checkpoint_output"

VALIDATION_MISMATCH_RUN="fixture-validation-mismatch"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$VALIDATION_MISMATCH_RUN" project_slice_planned '{"slice":"contract","owner":"implementer","validation":"wrong verifier","dependencies":[]}'
validation_mismatch_envelope="$(envelope_for_run "$VALIDATION_MISMATCH_RUN")"
validation_mismatch_output="$("$CONTROLLER" --envelope "$validation_mismatch_envelope" --events "$EVENT_DIR/$VALIDATION_MISMATCH_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$validation_mismatch_output" | jq -e '.decision == "stop" and .reason == "slice_validation_mismatch"' >/dev/null ||
  fail "planned verifier mismatch was accepted: $validation_mismatch_output"

GLOBAL_SCOPE_RUN="fixture-global-scope"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$GLOBAL_SCOPE_RUN" project_slice_planned '{"slice":"contract","owner":"implementer","validation":"node --check scripts/lib/project-autonomy.mjs","dependencies":[]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$GLOBAL_SCOPE_RUN" file_changed '{"path":"outside/scope.txt","change":"out of scope"}'
global_scope_envelope="$(envelope_for_run "$GLOBAL_SCOPE_RUN")"
global_scope_output="$("$CONTROLLER" --envelope "$global_scope_envelope" --events "$EVENT_DIR/$GLOBAL_SCOPE_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$global_scope_output" | jq -e '.decision == "stop" and .reason == "file_outside_authorized_scope"' >/dev/null ||
  fail "global file scope was bypassed: $global_scope_output"

TRAVERSAL_RUN="fixture-path-traversal"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$TRAVERSAL_RUN" file_changed '{"path":"workflow/../../outside.txt","change":"attempted path traversal"}'
traversal_envelope="$(envelope_for_run "$TRAVERSAL_RUN")"
traversal_output="$("$CONTROLLER" --envelope "$traversal_envelope" --events "$EVENT_DIR/$TRAVERSAL_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$traversal_output" | jq -e '.decision == "stop" and .reason == "file_path_invalid"' >/dev/null ||
  fail "path traversal was accepted: $traversal_output"

UNSCOPED_CHANGE_RUN="fixture-unscoped-change"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$UNSCOPED_CHANGE_RUN" file_changed '{"path":"workflow/project-autonomy-envelope.md","change":"outside declared slice"}'
unscoped_change_envelope="$(envelope_for_run "$UNSCOPED_CHANGE_RUN")"
unscoped_change_output="$("$CONTROLLER" --envelope "$unscoped_change_envelope" --events "$EVENT_DIR/$UNSCOPED_CHANGE_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$unscoped_change_output" | jq -e '.decision == "stop" and .reason == "file_changed_without_active_slice"' >/dev/null ||
  fail "file change without active slice was accepted: $unscoped_change_output"

OUTSIDE_WORKFLOW_DIR="$TMP_DIR/not-workflow"
OUTSIDE_WORKFLOW_RUN="fixture-outside-workflow"
"$EVENT_TOOL" --dir "$OUTSIDE_WORKFLOW_DIR" append "$OUTSIDE_WORKFLOW_RUN" route_decided '{"route":"plan-implement","reason":"wrong ledger base"}'
outside_workflow_envelope="$(envelope_for_run "$OUTSIDE_WORKFLOW_RUN")"
outside_workflow_output="$("$CONTROLLER" --envelope "$outside_workflow_envelope" --events "$OUTSIDE_WORKFLOW_DIR/$OUTSIDE_WORKFLOW_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$outside_workflow_output" | jq -e '.decision == "stop" and .reason == "invalid_ledger"' >/dev/null ||
  fail "ledger outside .workflow was accepted: $outside_workflow_output"

SLICE_SCOPE_RUN="fixture-slice-scope"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$SLICE_SCOPE_RUN" project_slice_planned '{"slice":"contract","owner":"implementer","validation":"node --check scripts/lib/project-autonomy.mjs","dependencies":[]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$SLICE_SCOPE_RUN" file_changed '{"path":"tests/outside-contract.sh","change":"wrong active slice"}'
slice_scope_envelope="$(envelope_for_run "$SLICE_SCOPE_RUN")"
slice_scope_output="$("$CONTROLLER" --envelope "$slice_scope_envelope" --events "$EVENT_DIR/$SLICE_SCOPE_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$slice_scope_output" | jq -e '.decision == "stop" and .reason == "file_outside_active_slice"' >/dev/null ||
  fail "active slice file scope was bypassed: $slice_scope_output"

FAILED_EVALUATION_RUN="fixture-latest-evaluation-failure"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$FAILED_EVALUATION_RUN" project_slice_planned '{"slice":"contract","owner":"implementer","validation":"node --check scripts/lib/project-autonomy.mjs","dependencies":[]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$FAILED_EVALUATION_RUN" project_slice_completed '{"slice":"contract","validation":"passed","evidence":["fixture"],"remaining":["verification"]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$FAILED_EVALUATION_RUN" human_checkpoint '{"category":"fresh_context_review","decision":"authorized","target":"fixture-autonomy:verification"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$FAILED_EVALUATION_RUN" project_slice_planned '{"slice":"verification","owner":"verifier","validation":"scripts/verify-agentic-infra full","dependencies":["contract"]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$FAILED_EVALUATION_RUN" project_slice_completed '{"slice":"verification","validation":"passed","evidence":["fixture"],"remaining":[]}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$FAILED_EVALUATION_RUN" validation_run '{"command":"scripts/verify-agentic-infra full","exit":0}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$FAILED_EVALUATION_RUN" outcome_metric '{"outcome":"fixture-final-state-grader","success":true,"measured":false,"reason":"fixture"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$FAILED_EVALUATION_RUN" validation_failed '{"command":"scripts/verify-agentic-infra full","exit":1,"failure":"latest final-state run failed"}'
failed_evaluation_envelope="$(envelope_for_run "$FAILED_EVALUATION_RUN")"
failed_evaluation_output="$("$CONTROLLER" --envelope "$failed_evaluation_envelope" --events "$EVENT_DIR/$FAILED_EVALUATION_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$failed_evaluation_output" | jq -e '.decision == "stop" and .reason == "evaluation_runner_failed"' >/dev/null ||
  fail "later final-state failure was ignored: $failed_evaluation_output"

future_start_envelope="$TMP_DIR/future-start-envelope.json"
jq '.started_at = "2099-01-01T00:00:00Z"' "$ENVELOPE" >"$future_start_envelope"
future_start_output="$("$CONTROLLER" --envelope "$future_start_envelope" --events "$EMPTY_EVENTS" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$future_start_output" | jq -e '.decision == "stop" and .reason == "invalid_envelope"' >/dev/null ||
  fail "future start was accepted: $future_start_output"

null_slice_envelope="$TMP_DIR/null-slice-envelope.json"
jq '.slices = [null]' "$ENVELOPE" >"$null_slice_envelope"
null_slice_output="$("$CONTROLLER" --envelope "$null_slice_envelope" --events "$EMPTY_EVENTS" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$null_slice_output" | jq -e '.decision == "stop" and .reason == "invalid_envelope"' >/dev/null ||
  fail "null slice crashed or passed: $null_slice_output"

CANONICAL_COMPAT_RUN="fixture-canonical-compat"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$CANONICAL_COMPAT_RUN" route_decided '{"route":"plan-implement","reason":"fixture canonical route detail"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$CANONICAL_COMPAT_RUN" outcome_metric '{"outcome":"fixture-telemetry","success":true,"measured":false,"measurement_reason":"fixture has no runtime telemetry"}'
canonical_compat_envelope="$(envelope_for_run "$CANONICAL_COMPAT_RUN")"
canonical_compat_output="$("$CONTROLLER" --envelope "$canonical_compat_envelope" --events "$EVENT_DIR/$CANONICAL_COMPAT_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$canonical_compat_output" | jq -e '.decision == "plan_slice" and .reason == "next_verifiable_slice"' >/dev/null ||
  fail "canonical unmeasured outcome detail was rejected: $canonical_compat_output"

CANONICAL_MEASURED_RUN="fixture-canonical-measured"
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$CANONICAL_MEASURED_RUN" route_decided '{"route":"plan-implement","reason":"fixture canonical route detail"}'
"$EVENT_TOOL" --dir "$EVENT_DIR" append "$CANONICAL_MEASURED_RUN" outcome_metric '{"outcome":"fixture-telemetry","success":true,"measured":true,"input_tokens":1,"output_tokens":2,"total_tokens":3,"tool_calls":0,"elapsed_ms":0.5}'
canonical_measured_envelope="$(envelope_for_run "$CANONICAL_MEASURED_RUN")"
canonical_measured_output="$("$CONTROLLER" --envelope "$canonical_measured_envelope" --events "$EVENT_DIR/$CANONICAL_MEASURED_RUN/events.jsonl" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$canonical_measured_output" | jq -e '.decision == "plan_slice" and .reason == "next_verifiable_slice"' >/dev/null ||
  fail "canonical measured outcome detail was rejected: $canonical_measured_output"

INVALID_ROUTE_RUN="fixture-invalid-route"
invalid_route_ledger="$EVENT_DIR/$INVALID_ROUTE_RUN/events.jsonl"
mkdir -p "$EVENT_DIR/$INVALID_ROUTE_RUN"
printf '%s\n' '{"schema_version":2,"ts":"2026-07-24T10:00:00Z","event":"route_decided","run":"fixture-invalid-route","detail":{}}' >"$invalid_route_ledger"
invalid_route_envelope="$(envelope_for_run "$INVALID_ROUTE_RUN")"
invalid_route_output="$("$CONTROLLER" --envelope "$invalid_route_envelope" --events "$invalid_route_ledger" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$invalid_route_output" | jq -e '.decision == "stop" and .reason == "invalid_ledger"' >/dev/null ||
  fail "invalid canonical route detail was accepted: $invalid_route_output"

MALFORMED_RUN="fixture-malformed"
malformed_ledger="$EVENT_DIR/$MALFORMED_RUN/events.jsonl"
mkdir -p "$EVENT_DIR/$MALFORMED_RUN"
printf '%s\n' '{"schema_version":2,"ts":"2026-07-24T10:00:00Z","event":"outcome_metric","run":"fixture-malformed","detail":{"outcome":"fixture-final-state-grader","success":true}}' >"$malformed_ledger"
malformed_envelope="$(envelope_for_run "$MALFORMED_RUN")"
malformed_output="$("$CONTROLLER" --envelope "$malformed_envelope" --events "$malformed_ledger" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$malformed_output" | jq -e '.decision == "stop" and .reason == "invalid_ledger"' >/dev/null ||
  fail "malformed outcome metric was accepted: $malformed_output"

POST_TERMINAL_RUN="fixture-post-terminal"
post_terminal_ledger="$EVENT_DIR/$POST_TERMINAL_RUN/events.jsonl"
mkdir -p "$EVENT_DIR/$POST_TERMINAL_RUN"
printf '%s\n' '{"schema_version":2,"ts":"2026-07-24T10:00:00Z","event":"completed","run":"fixture-post-terminal","detail":{"summary":"done"}}' >"$post_terminal_ledger"
printf '%s\n' '{"schema_version":2,"ts":"2026-07-24T10:00:01Z","event":"blocked","run":"fixture-post-terminal","detail":{"reason":"late","needed_input":"none"}}' >>"$post_terminal_ledger"
post_terminal_envelope="$(envelope_for_run "$POST_TERMINAL_RUN")"
post_terminal_output="$("$CONTROLLER" --envelope "$post_terminal_envelope" --events "$post_terminal_ledger" --now 2026-07-24T10:05:00Z)"
printf '%s\n' "$post_terminal_output" | jq -e '.decision == "stop" and .reason == "invalid_ledger"' >/dev/null ||
  fail "post-terminal evidence was accepted: $post_terminal_output"

help_output="$("$ROOT_DIR/scripts/workflow-retrospect" --help)"
case "$help_output" in
  *"never applies"*) ;;
  *) fail "self-improvement helper must remain proposal-only" ;;
esac

printf 'project autonomy smoke test: ok\n'
