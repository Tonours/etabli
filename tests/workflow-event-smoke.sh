#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/scripts/lib/hash.sh"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"

grep -Fq 'elif $event == "multi_execution_completed" then' "$ROOT_DIR/scripts/lib/workflow-event-detail.jq" || {
  printf 'multi_execution_completed must use the extracted detail validator\n' >&2
  exit 1
}
if grep -Fq 'local expression=' "$ROOT_DIR/scripts/workflow-event"; then
  printf 'workflow-event must not keep an inline detail schema\n' >&2
  exit 1
fi

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

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-active route_decided '{"route":"plan-loop","reason":"active pointer test"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" activate run-active)"
assert_contains "$out" "active run: run-active"
jq -e '.schema_version == 1 and .run == "run-active"' "$EVENT_DIR/active-run.json" >/dev/null
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-other route_decided '{"route":"plan-loop","reason":"competing pointer test"}'
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" activate run-other)"
assert_contains "$out" "active run already selected"
jq -e '.run == "run-active"' "$EVENT_DIR/active-run.json" >/dev/null
export ROOT_DIR TMP_DIR
node --input-type=module <<'EOF'
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = process.env.ROOT_DIR;
const cwd = process.env.TMP_DIR;
const { ACTIVE_RUN_POINTER, selectActiveLedger } = await import(
  pathToFileURL(join(root, "scripts/lib/ledger-integrity.mjs")).href,
);
const { planMutationGuardDecision } = await import(
  pathToFileURL(join(root, "workflow/runtime/workflow-router-core.mjs")).href,
);

const selection = selectActiveLedger(cwd);
if (selection.reason) {
  throw new Error(`selectActiveLedger missed activate pointer: ${selection.reason}`);
}
if (selection.ledger?.run !== "run-active") {
  throw new Error(`expected activated run-active, got ${selection.ledger?.run}`);
}
const expectedPath = join(cwd, ".workflow", ACTIVE_RUN_POINTER);
if (selection.inspection.pointer.path !== expectedPath) {
  throw new Error(`pointer path ${selection.inspection.pointer.path} !== ${expectedPath}`);
}
if (selection.inspection.records.length !== 1) {
  throw new Error("pointer selection must inspect only the activated ledger");
}
const decision = planMutationGuardDecision({
  cwd,
  tool_name: "Write",
  tool_input: { file_path: join(cwd, "src/from-activate.ts"), content: "x" },
});
if (decision != null) {
  throw new Error(`guards did not see activated run: ${JSON.stringify(decision)}`);
}
EOF
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-active completed '{"summary":"active pointer closed"}'
[ ! -e "$EVENT_DIR/active-run.json" ] || {
  printf 'terminal append must clear its active-run pointer\n' >&2
  exit 1
}
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" activate run-a)"
assert_contains "$out" "cannot activate a terminal ledger"

mkdir -p "$EVENT_DIR/run-recover"
printf '{bad\n' > "$EVENT_DIR/run-recover/events.jsonl"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" recover run-recover corrupt-ledger)"
assert_contains "$out" "recovered run-recover"
find "$EVENT_DIR/run-recover" -name 'events.invalid-*.jsonl' -print -quit | grep -q . ||
  fail "recovery did not preserve invalid raw ledger"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-recover)"
assert_contains "$out" "1 events, ok"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" recover run-a corrupt-ledger)"
assert_contains "$out" "already valid ledger"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-dogfood dogfood_matrix_created '{"path":"docs/dogfood.md","flows":1,"scenarios":2}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-dogfood dogfood_scenario_run '{"scenario":"reply-email-link","surface":"browser","status":"fail","artifacts":["trace.zip"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-dogfood dogfood_fix_applied '{"scenario":"reply-email-link","fix":"correct reply anchor","evidence":"rerun passed"}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-dogfood dogfood_blocked '{"scenario":"real-inbox-click","reason":"blocked-human-verify","needed_input":"human inbox verification"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-dogfood)"
assert_contains "$out" "4 events, ok"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning self_improvement_candidate '{"source":"events.jsonl","category":"router_miss","outcome":"router_fixture","confidence":"confirmed","evidence":["fixture"],"held_in":["misrouted prompt fixture"],"held_out":["read-only explanation fixture"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning harness_failure_pattern '{"terminal_cause":"router miss","causal_status":"confirmed","mechanism":"review pattern shadowed self-improvement route","verifier":"router eval","traces":["tests/router-evals/core.json"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning harness_proposal '{"candidate":"split explicit review guard","editable_surfaces":["pi/extensions/lib/workflow-router-runtime.ts","claude/hooks/workflow-router-lib.mjs"],"preserve":["read-only explanations stay answer"],"held_in":["self-improvement prompt routes plan-implement"],"held_out":["explicit self-improvement review stays review"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning harness_validation_completed '{"candidate":"split explicit review guard","verdict":"accepted","reason":"reproduced routes fixed without held-out regression","held_in":{"baseline":{"population":"router-misses-v1","passed":0,"total":2},"candidate":{"population":"router-misses-v1","passed":2,"total":2}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":4,"total":4}},"checks":["tests/router-eval-smoke.sh"],"evidence":["tests/router-evals/core.json"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning harness_validation_completed '{"candidate":"broad review keyword","verdict":"rejected","reason":"held-out route regression","held_in":{"baseline":{"population":"router-misses-v1","passed":0,"total":2},"candidate":{"population":"router-misses-v1","passed":2,"total":2}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":3,"total":4}},"checks":["tests/router-eval-smoke.sh"],"evidence":["tests/router-evals/core.json"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning harness_candidate_rejected '{"candidate":"auto-apply harness patches","reason":"bypasses reviewed PLAN.md gate","regressions":["external write-back risk","permission boundary weakened"],"evidence":["workflow/skills/implementation-loop.md"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning project_slice_planned '{"slice":"spec","owner":"planner","validation":"review","dependencies":[]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning project_slice_completed '{"slice":"spec","validation":"passed","evidence":["docs/spec.md"],"remaining":[]}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-learning)"
assert_contains "$out" "8 events, ok"
jq -e 'select(.event == "harness_proposal") | .detail.held_in[0] and .detail.held_out[0]' "$EVENT_DIR/run-learning/events.jsonl" >/dev/null
jq -e 'select(.event == "harness_validation_completed" and .detail.verdict == "accepted") | .detail.held_in.candidate.passed == 2 and .detail.held_out.candidate.passed == 4' "$EVENT_DIR/run-learning/events.jsonl" >/dev/null
jq -e 'select(.event == "harness_candidate_rejected") | .detail.regressions[0] and .detail.evidence[0]' "$EVENT_DIR/run-learning/events.jsonl" >/dev/null

while IFS=$'\t' read -r event required detail; do
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-valid-$event" "$event" "$detail"
  invalid_detail="$(printf '%s\n' "$detail" | jq -c --arg required "$required" 'del(.[$required])')"
  out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-invalid-$event" "$event" "$invalid_detail")"
  assert_contains "$out" "required fields"
done < "$ROOT_DIR/tests/fixtures/workflow-events-v2.tsv"

# Tranche 3: review_completed status enum (strict v2 only).
for status in "GO" "GO WITH NOTES" BLOCK; do
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-enum-ok" review_completed "$(jq -nc --arg s "$status" '{status:$s,evidence:"smoke"}')"
done
while IFS= read -r status; do
  [ -n "$status" ] || continue
  out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-enum-reject" review_completed "$(jq -nc --arg s "$status" '{status:$s,evidence:"smoke"}')")"
  assert_contains "$out" "required fields"
done <<'STATUSES'
pass
NO-GO
completed
ROUND2 GO WITH NOTES
ROUND1 WITH FIXES
READY
quality: sibling comparison clean
quality_passed
PASS
GO_WITH_NOTES
GO_LOCAL
changes_addressed
STATUSES
# Legacy/v1 free-text statuses stay valid (lenience, not new writes).
mkdir -p "$EVENT_DIR/schema-enum-legacy"
printf '%s\n' '{"ts":"2026-01-01T00:00:00Z","event":"review_completed","run":"schema-enum-legacy","detail":{"status":"pass","evidence":"old"}}' > "$EVENT_DIR/schema-enum-legacy/events.jsonl"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate schema-enum-legacy)"
assert_contains "$out" "1 events, ok"
# Tranche 4: quality_completed status enum (strict v2 only) + legacy lenience.
for status in pass unavailable; do
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-quality-ok" quality_completed "$(jq -nc --arg s "$status" '{status:$s,evidence:"smoke"}')"
done
for status in clean GO "GO WITH NOTES" skipped ""; do
  out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-quality-reject" quality_completed "$(jq -nc --arg s "$status" '{status:$s,evidence:"smoke"}')")"
  assert_contains "$out" "required fields"
done
mkdir -p "$EVENT_DIR/schema-quality-legacy"
printf '%s\n' '{"schema_version":1,"ts":"2026-01-01T00:00:00Z","event":"quality_completed","run":"schema-quality-legacy","detail":{"status":"clean","evidence":"old"}}' > "$EVENT_DIR/schema-quality-legacy/events.jsonl"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate schema-quality-legacy)"
assert_contains "$out" "1 events, ok"
# Tranche 4: model_provenance complete-when-present (strict + legacy).
PROV_OK='{"requested":{"family":"openai","model":"gpt-6-astra","provider":"codex","route":"codex/gpt-6-astra"},"effective":{"family":"openai","model":"gpt-6-astra","provider":"codex"},"runner":"codex-cli","run_id":"r1"}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-prov-ok" adversary_completed "$(jq -nc --argjson p "$PROV_OK" '{mode:"code_diff",verdict:"GO",accepted_findings:[],rejected_findings:[],model_provenance:$p}')"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-prov-noprovider" adversary_completed "$(jq -nc --argjson p "$PROV_OK" '{mode:"code_diff",verdict:"GO",accepted_findings:[],rejected_findings:[],model_provenance:($p|del(.requested.provider))}')")"
assert_contains "$out" "required fields"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-prov-norun" adversary_completed "$(jq -nc --argjson p "$PROV_OK" '{mode:"code_diff",verdict:"GO",accepted_findings:[],rejected_findings:[],model_provenance:($p|del(.run_id))}')")"
assert_contains "$out" "required fields"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-prov-wrongtype" adversary_completed "$(jq -nc --argjson p "$PROV_OK" '{mode:"code_diff",verdict:"GO",accepted_findings:[],rejected_findings:[],model_provenance:($p|.requested="x")}')")"
assert_contains "$out" "required fields"
mkdir -p "$EVENT_DIR/schema-prov-legacy-ok" "$EVENT_DIR/schema-prov-legacy-bad"
printf '%s\n' "$(jq -nc --argjson p "$PROV_OK" '{schema_version:1,ts:"2026-01-01T00:00:00Z",event:"adversary_completed",run:"schema-prov-legacy-ok",detail:{mode:"plan",verdict:"READY",accepted_findings:[],rejected_findings:[],model_provenance:$p}}')" > "$EVENT_DIR/schema-prov-legacy-ok/events.jsonl"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate schema-prov-legacy-ok)"
assert_contains "$out" "1 events, ok"
printf '%s\n' "$(jq -nc --argjson p "$PROV_OK" '{schema_version:1,ts:"2026-01-01T00:00:00Z",event:"adversary_completed",run:"schema-prov-legacy-bad",detail:{verdict:"READY",accepted_findings:[],model_provenance:($p|del(.effective.family))}}')" > "$EVENT_DIR/schema-prov-legacy-bad/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate schema-prov-legacy-bad)"
assert_contains "$out" "invalid detail for adversary_completed"
# route_decided additive contract fields accepted.
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-route-additive" route_decided '{"route":"plan-implement","reason":"smoke","contract_path":"/tmp/x/SKILL.md","contract_sha256":"f2a1","provenance":"repo"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate schema-route-additive)"
assert_contains "$out" "1 events, ok"
# ...but validated: bogus provenance, empty sha, and unknown keys rejected (validator/consumer parity).
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-route-bogus" route_decided '{"route":"plan-implement","reason":"smoke","provenance":"bogus"}')"
assert_contains "$out" "required fields"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-route-empty" route_decided '{"route":"plan-implement","reason":"smoke","contract_sha256":""}')"
assert_contains "$out" "required fields"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "schema-route-extra" route_decided '{"route":"plan-implement","reason":"smoke","contract_url":"https://x"}')"
assert_contains "$out" "required fields"

mkdir -p "$EVENT_DIR/target-a"
target_line='{"schema_version":2,"ts":"2026-07-01T00:02:00Z","event":"completed","run":"target-a","detail":{"summary":"done"}}'
printf '%s\n' "$target_line" > "$EVENT_DIR/target-a/events.jsonl"
target_ledger_sha="$(hash256 "$EVENT_DIR/target-a/events.jsonl" | awk '{print $1}')"
target_terminal_sha="$(printf '%s' "$target_line" | hash256 | awk '{print $1}')"
measurement_targets="$(jq -nc --arg ledger "$target_ledger_sha" --arg terminal "$target_terminal_sha" '[{target_run:"target-a",target_ledger_sha256:$ledger,target_terminal:"completed",target_terminal_event_sha256:$terminal,target_outcome_event_sha256:null,baseline_measured:false,baseline_usage_measured:false}]')"
manifest_sha="$(node -e 'const c=require("node:crypto"); const stable=(v)=>Array.isArray(v)?`[${v.map(stable).join(",")}]`:v&&typeof v==="object"?`{${Object.keys(v).sort().map((k)=>`${JSON.stringify(k)}:${stable(v[k])}`).join(",")}}`:JSON.stringify(v); process.stdout.write(c.createHash("sha256").update(stable(JSON.parse(process.argv[1]))).digest("hex"))' "$measurement_targets")"
population_id="terminal-runs-v1-${manifest_sha:0:16}"
measurement_population="$(jq -nc --arg population "$population_id" --arg manifest "$manifest_sha" --argjson targets "$measurement_targets" '{population_id:$population,manifest_sha256:$manifest,terminal_runs:1,targets:$targets}')"
measurement_import="$(jq -nc --arg population "$population_id" --arg ledger "$target_ledger_sha" --arg terminal "$target_terminal_sha" '{population_id:$population,import_id:"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",target_run:"target-a",target_ledger_sha256:$ledger,target_terminal:"completed",target_terminal_event_sha256:$terminal,target_outcome_event_sha256:null,source_adapter:"codex",source_scope:"primary_session_window",selection:"shortest_enclosing_primary_session",session_fingerprint:"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",window_started_at:"2026-07-01T00:00:00Z",window_ended_at:"2026-07-01T00:02:00Z",sample_started_at:"2026-07-01T00:00:00.000Z",sample_ended_at:"2026-07-01T00:02:30.000Z",sample_count:2,success:true,input_tokens:100,output_tokens:20,total_tokens:120,tool_calls:1,elapsed_ms:150000}')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-measurement outcome_measurement_population "$measurement_population"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-measurement outcome_measurement_imported "$measurement_import"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-measurement)"
assert_contains "$out" "2 events, ok"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-measurement outcome_measurement_imported "$measurement_import"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-measurement)"
assert_contains "$out" "must be unique members"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-measurement-unmatched outcome_measurement_population "$measurement_population"
unmatched_import="$(printf '%s\n' "$measurement_import" | jq -c '.target_run="target-missing" | .import_id="ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-measurement-unmatched outcome_measurement_imported "$unmatched_import"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-measurement-unmatched)"
assert_contains "$out" "must be unique members"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning-invalid harness_validation_completed '{"candidate":"false accepted regression","verdict":"accepted","reason":"must fail","held_in":{"baseline":{"population":"router-misses-v1","passed":0,"total":2},"candidate":{"population":"router-misses-v1","passed":2,"total":2}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":3,"total":4}},"checks":["tests/router-eval-smoke.sh"],"evidence":["tests/router-evals/core.json"]}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning-invalid harness_validation_completed '{"candidate":"false accepted no gain","verdict":"accepted","reason":"must fail","held_in":{"baseline":{"population":"router-misses-v1","passed":1,"total":2},"candidate":{"population":"router-misses-v1","passed":1,"total":2}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":4,"total":4}},"checks":["tests/router-eval-smoke.sh"],"evidence":["tests/router-evals/core.json"]}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning-invalid harness_validation_completed '{"candidate":"invalid counts","verdict":"rejected","reason":"must fail","held_in":{"baseline":{"population":"router-misses-v1","passed":0,"total":2},"candidate":{"population":"router-misses-v1","passed":3,"total":2}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":4,"total":4}},"checks":["tests/router-eval-smoke.sh"],"evidence":["tests/router-evals/core.json"]}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning-invalid harness_validation_completed '{"candidate":"mismatched population","verdict":"rejected","reason":"must fail","held_in":{"baseline":{"population":"router-misses-v1","passed":0,"total":2},"candidate":{"population":"different-misses-v1","passed":2,"total":2}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":4,"total":4}},"checks":["tests/router-eval-smoke.sh"],"evidence":["tests/router-evals/core.json"]}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning-invalid harness_validation_completed '{"candidate":"mismatched totals","verdict":"rejected","reason":"must fail","held_in":{"baseline":{"population":"router-misses-v1","passed":0,"total":2},"candidate":{"population":"router-misses-v1","passed":2,"total":3}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":4,"total":4}},"checks":["tests/router-eval-smoke.sh"],"evidence":["tests/router-evals/core.json"]}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning-invalid harness_validation_completed '{"candidate":"zero total","verdict":"rejected","reason":"must fail","held_in":{"baseline":{"population":"router-misses-v1","passed":0,"total":0},"candidate":{"population":"router-misses-v1","passed":0,"total":0}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":4,"total":4}},"checks":["tests/router-eval-smoke.sh"],"evidence":["tests/router-evals/core.json"]}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning-invalid harness_validation_completed '{"candidate":"fractional count","verdict":"rejected","reason":"must fail","held_in":{"baseline":{"population":"router-misses-v1","passed":0.5,"total":2},"candidate":{"population":"router-misses-v1","passed":2,"total":2}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":4,"total":4}},"checks":["tests/router-eval-smoke.sh"],"evidence":["tests/router-evals/core.json"]}')"
assert_contains "$out" "required fields"

# X2: additive optional outcome_metric runtime fields are accepted (positive)
# and type-checked when present (negative). Proves the schema is additive, not
# a silent ignore: a valid core metric with the additive fields validates, and
# a non-integer turn_count is rejected.
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-outcome-additive outcome_metric '{"outcome":"success","success":true,"measured":true,"input_tokens":40,"output_tokens":20,"total_tokens":60,"tool_calls":1,"elapsed_ms":500,"runtime":"pi/glm-5.2","turn_count":5,"auto_continue_count":1,"token_estimate":60,"wall_clock_ms":512.5}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-outcome-additive)"
assert_contains "$out" "1 events, ok"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-outcome-additive-bad outcome_metric '{"outcome":"success","success":true,"measured":true,"input_tokens":40,"output_tokens":20,"total_tokens":60,"tool_calls":1,"elapsed_ms":500,"turn_count":"not-a-number"}')"
assert_contains "$out" "required fields"

# M1: participant_usage + batch makespan accepted when participant totals match total_tokens
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-outcome-m1 outcome_metric '{"outcome":"success","success":true,"measured":true,"input_tokens":70,"output_tokens":30,"total_tokens":100,"tool_calls":2,"elapsed_ms":800,"success_kind":"task_grader","grader_success":true,"participant_usage":[{"id":"parent","role":"parent","input_tokens":40,"output_tokens":20,"total_tokens":60},{"id":"scout","role":"sidecar","input_tokens":30,"output_tokens":10,"total_tokens":40}],"batch_wall_clock_ms":1800,"batch_started_at":"2026-07-31T12:00:00Z","batch_terminal_at":"2026-07-31T12:00:01.800Z"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-outcome-m1)"
assert_contains "$out" "1 events, ok"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-outcome-m1-bad outcome_metric '{"outcome":"success","success":true,"measured":true,"input_tokens":70,"output_tokens":30,"total_tokens":100,"tool_calls":2,"elapsed_ms":800,"participant_usage":[{"id":"parent","input_tokens":40,"output_tokens":20,"total_tokens":60},{"id":"scout","input_tokens":10,"output_tokens":5,"total_tokens":15}]}')"
assert_contains "$out" "required fields"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-runtime runtime_run_attached '{"adapter":"pi-workflow","run_id":"workflow_mq224pi8_775e71","workflow":"spec-review","state_path":".pi/workflows/workflow_mq224pi8_775e71","status":"running","usage_measured":false}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-runtime)"
assert_contains "$out" "1 events, ok"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel multi_execution_completed '{"participants":[{"id":"agent-analyst","model":"xai/grok-4.5","family":"xai"},{"id":"agent-glm","model":"zai/glm-5.2","family":"zai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":true,"input_tokens":10,"output_tokens":5,"total_tokens":15,"elapsed_ms":100},"fallback_status":"none"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-panel)"
assert_contains "$out" "1 events, ok"

protocol_v2_base='{"protocol_version":2,"participants":[{"id":"agent-analyst","model":"xai/grok-4.5","family":"xai"},{"id":"agent-glm","model":"zai/glm-5.2","family":"zai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":true,"input_tokens":100,"output_tokens":500,"total_tokens":600,"elapsed_ms":1000},"fallback_status":"none","trigger":"adaptive","strategy":"council","signals":["critical-risk"],"rounds":{"first_pass":1,"rebuttal":0,"adjudication":0},"claim_count":2,"disagreement_count":0,"stop_reason":"agreement","budget":{"max_claims":6,"first_pass_output_tokens":1800,"rebuttal_output_tokens":700,"adjudication_output_tokens":650,"total_output_tokens":3500},"stage_usage":{"first_pass":{"measured":true,"input_tokens":100,"output_tokens":500,"total_tokens":600,"elapsed_ms":900},"rebuttal":{"measured":false},"adjudication":{"measured":false}}}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2 multi_execution_completed "$protocol_v2_base"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-panel-v2)"
assert_contains "$out" "1 events, ok"

protocol_v2_budget_cap="$(printf '%s\n' "$protocol_v2_base" | jq -c '.verdict="degraded" | .stop_reason="budget_cap" | .usage.output_tokens=3600 | .usage.total_tokens=3700')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-cap multi_execution_completed "$protocol_v2_budget_cap"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-panel-v2-cap)"
assert_contains "$out" "1 events, ok"

protocol_v2_scout="$(printf '%s\n' "$protocol_v2_base" | jq -c '.participants=[.participants[0]] | .strategy="scout" | .signals=["system-complexity"] | .claim_count=1 | .budget={"max_claims":6,"first_pass_output_tokens":600,"rebuttal_output_tokens":0,"adjudication_output_tokens":0,"total_output_tokens":600}')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-scout-v2 multi_execution_completed "$protocol_v2_scout"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-scout-v2)"
assert_contains "$out" "1 events, ok"

protocol_v2_scout_fallback="$(printf '%s\n' "$protocol_v2_scout" | jq -c '.participants=[{"id":"agent-fallback","model":"openai-codex/gpt-5.6-luna","family":"openai-codex"}] | .verdict="degraded" | .stop_reason="agreement" | .fallback_status="degraded"')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-scout-v2-fallback multi_execution_completed "$protocol_v2_scout_fallback"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-scout-v2-fallback)"
assert_contains "$out" "1 events, ok"

protocol_v2_council_fallback="$(printf '%s\n' "$protocol_v2_base" | jq -c '.participants[0]={"id":"agent-fallback","model":"openai-codex/gpt-5.6-luna","family":"openai-codex"} | .verdict="degraded" | .stop_reason="agreement" | .fallback_status="degraded"')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-council-v2-fallback multi_execution_completed "$protocol_v2_council_fallback"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-council-v2-fallback)"
assert_contains "$out" "1 events, ok"

protocol_v2_fallback_deterministic="$(printf '%s\n' "$protocol_v2_council_fallback" | jq -c '.stop_reason="deterministic_check"')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-council-v2-fallback-deterministic multi_execution_completed "$protocol_v2_fallback_deterministic"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-council-v2-fallback-deterministic)"
assert_contains "$out" "1 events, ok"

protocol_v2_fallback_rebuttal="$(printf '%s\n' "$protocol_v2_council_fallback" | jq -c '.stop_reason="rebuttal_resolved" | .rounds.rebuttal=1 | .disagreement=true | .disagreement_count=1')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-council-v2-fallback-rebuttal multi_execution_completed "$protocol_v2_fallback_rebuttal"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-council-v2-fallback-rebuttal)"
assert_contains "$out" "1 events, ok"

protocol_v2_fallback_adjudicated="$(printf '%s\n' "$protocol_v2_fallback_rebuttal" | jq -c '.stop_reason="adjudicated" | .rounds.adjudication=1 | .adjudicator="adjudicator-agent"')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-council-v2-fallback-adjudicated multi_execution_completed "$protocol_v2_fallback_adjudicated"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-council-v2-fallback-adjudicated)"
assert_contains "$out" "1 events, ok"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-over-accepted multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.usage.output_tokens=3600 | .usage.total_tokens=3700')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-over-stage multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.stage_usage.first_pass.output_tokens=1900 | .stage_usage.first_pass.total_tokens=2000')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-over-claims multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.claim_count=7')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-duplicate-signals multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.signals=["critical-risk","critical-risk"]')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-bad-round multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.rounds.adjudication=1 | .stop_reason="adjudicated"')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-bad-stop-shape multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.rounds.rebuttal=1')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-raised-budget multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.budget.total_output_tokens=999999')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-dependent-passes multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.independent_first_passes=false')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-accepted-fallback multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.participants[1]={"id":"agent-fallback","model":"openai-codex/gpt-5.6-luna","family":"openai-codex"} | .fallback_status="degraded"')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-accepted-blocked multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.stop_reason="blocked"')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-too-many-disagreements multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.disagreement=true | .disagreement_count=3')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-one-councillor multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.participants=[.participants[0]]')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-bad-adaptive-score multi_execution_completed "$(printf '%s\n' "$protocol_v2_scout" | jq -c '.signals=["critical-risk"]')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-rollback-verdict multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.verdict="rollback_to_opt_in"')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-unused-stage-usage multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.stage_usage.rebuttal={"measured":true,"input_tokens":0,"output_tokens":0,"total_tokens":0,"elapsed_ms":0}')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-duplicate-agent-id multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.participants[1].id=.participants[0].id')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-duplicate-glm multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.participants[0]={"id":"agent-glm-second","model":"zai/glm-5.2","family":"zai"}')")"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-scout-v2-duplicate-luna multi_execution_completed "$(printf '%s\n' "$protocol_v2_scout" | jq -c '.participants += [{"id":"agent-scout-second","model":"opencode-go/deepseek-v4-flash","family":"opencode-go"}]')")"
assert_contains "$out" "required fields"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-kimi multi_execution_completed '{"participants":[{"id":"agent-fallback","model":"openai-codex/gpt-5.6-luna","family":"openai-codex"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"degraded","usage":{"measured":false},"fallback_status":"degraded"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-panel-kimi)"
assert_contains "$out" "1 events, ok"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-retired-kimi multi_execution_completed '{"participants":[{"id":"agent-kimi","model":"opencode-go/kimi-k2.6","family":"kimi"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"degraded","usage":{"measured":false},"fallback_status":"degraded"}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-bad multi_execution_completed '{"participants":[],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":false},"fallback_status":"none"}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-bad-model multi_execution_completed '{"participants":[{"id":"agent","model":"unknown/model","family":"openai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":false},"fallback_status":"none"}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-bad-family multi_execution_completed '{"participants":[{"id":"agent","model":"zai/glm-5.2","family":"openai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":false},"fallback_status":"none"}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-bad-usage multi_execution_completed '{"participants":[{"id":"agent","model":"zai/glm-5.2","family":"zai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":true},"fallback_status":"none"}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-bad-total multi_execution_completed '{"participants":[{"id":"agent","model":"zai/glm-5.2","family":"zai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":true,"input_tokens":10,"output_tokens":5,"total_tokens":14,"elapsed_ms":1},"fallback_status":"none"}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-too-many multi_execution_completed '{"participants":[{"id":"one","model":"zai/glm-5.2","family":"zai"},{"id":"two","model":"zai/glm-5.2","family":"zai"},{"id":"three","model":"zai/glm-5.2","family":"zai"},{"id":"four","model":"zai/glm-5.2","family":"zai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":false},"fallback_status":"none"}')"
assert_contains "$out" "required fields"

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-bad-judge multi_execution_completed '{"participants":[{"id":"agent","model":"zai/glm-5.2","family":"zai"}],"independent_first_passes":true,"disagreement":true,"adjudicator":"","verdict":"accepted","usage":{"measured":false},"fallback_status":"none"}')"
assert_contains "$out" "required fields"

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
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-terminal)"
assert_contains "$out" "legacy post-terminal compatibility"

mkdir -p "$EVENT_DIR/run-terminal-v2"
printf '%s\n' \
  '{"schema_version":2,"ts":"2026-07-09T10:00:00Z","event":"completed","run":"run-terminal-v2","detail":{"summary":"done"}}' \
  '{"schema_version":2,"ts":"2026-07-09T10:00:01Z","event":"validation_run","run":"run-terminal-v2","detail":{"command":"true","exit":0}}' \
  > "$EVENT_DIR/run-terminal-v2/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-terminal-v2)"
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
  'outcome_metric {"outcome":"success","success":true,"measured":false,"reason":"telemetry unavailable in smoke"}' \
  'plan_removed {"path":"PLAN.md"}' \
  'completed {"summary":"done"}'; do
  event="${event_detail%% *}"
  detail="${event_detail#* }"
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-complete "$event" "$detail"
done
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-complete --profile autonomous-completed)"
assert_contains "$out" "12 events, ok"

mkdir -p "$EVENT_DIR/run-failed-validation" "$EVENT_DIR/run-blocked-review" "$EVENT_DIR/run-blocked-adversary" "$EVENT_DIR/run-stale-evidence" "$EVENT_DIR/run-stale-evidence-spaced" "$EVENT_DIR/run-reversed-validation" "$EVENT_DIR/run-reversed-review" "$EVENT_DIR/run-reversed-adversary" "$EVENT_DIR/run-reversed-plan-adversary" "$EVENT_DIR/run-recovered-evidence" "$EVENT_DIR/run-native-validation-failed" "$EVENT_DIR/run-native-validation-recovered" "$EVENT_DIR/run-native-validation-other-success"
jq -c --arg run run-failed-validation '
  .run = $run |
  if .event == "validation_run" then .detail.exit = 1 else . end
' "$EVENT_DIR/run-complete/events.jsonl" >"$EVENT_DIR/run-failed-validation/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-failed-validation --profile autonomous-completed)"
assert_contains "$out" "latest validation attempt"

jq -c --arg run run-blocked-review '
  .run = $run |
  if .event == "review_completed" then .detail.status = "BLOCK" else . end
' "$EVENT_DIR/run-complete/events.jsonl" >"$EVENT_DIR/run-blocked-review/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-blocked-review --profile autonomous-completed)"
assert_contains "$out" "latest review_completed"

jq -c --arg run run-blocked-adversary '
  .run = $run |
  if .event == "adversary_completed" and .detail.mode == "code_diff" then .detail.verdict = "BLOCK" else . end
' "$EVENT_DIR/run-complete/events.jsonl" >"$EVENT_DIR/run-blocked-adversary/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-blocked-adversary --profile autonomous-completed)"
assert_contains "$out" "latest code_diff adversary"

late_ts="$(sed -n '8p' "$EVENT_DIR/run-complete/events.jsonl" | jq -r '.ts')"
late_change="$(sed -n '4p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-stale-evidence --arg ts "$late_ts" '.run = $run | .ts = $ts | .detail.path = "src/late.ts"')"
jq -c --arg run run-stale-evidence '.run = $run' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v late="$late_change" 'NR == 9 { print late } { print }' >"$EVENT_DIR/run-stale-evidence/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-stale-evidence --profile autonomous-completed)"
assert_contains "$out" "after last file change"

spaced_change="$(sed -n '4p' "$EVENT_DIR/run-complete/events.jsonl" |
  jq -c --arg run run-stale-evidence-spaced --arg ts "$late_ts" '.run = $run | .ts = $ts | .detail.path = "src/spaced-late.ts"' |
  sed 's/":/": /g; s/,"/, "/g')"
jq -c --arg run run-stale-evidence-spaced '.run = $run' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v late="$spaced_change" 'NR == 9 { print late } { print }' >"$EVENT_DIR/run-stale-evidence-spaced/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-stale-evidence-spaced --profile autonomous-completed)"
assert_contains "$out" "after last file change"

reversed_validation="$(sed -n '5p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-reversed-validation --arg ts "$late_ts" '.run = $run | .ts = $ts | .detail.exit = 1')"
jq -c --arg run run-reversed-validation '.run = $run' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v late="$reversed_validation" 'NR == 9 { print late } { print }' >"$EVENT_DIR/run-reversed-validation/events.jsonl"

reversed_review="$(sed -n '7p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-reversed-review --arg ts "$late_ts" '.run = $run | .ts = $ts | .detail.status = "BLOCK"')"
jq -c --arg run run-reversed-review '.run = $run' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v late="$reversed_review" 'NR == 9 { print late } { print }' >"$EVENT_DIR/run-reversed-review/events.jsonl"

reversed_adversary="$(sed -n '8p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-reversed-adversary --arg ts "$late_ts" '.run = $run | .ts = $ts | .detail.verdict = "BLOCK"')"
jq -c --arg run run-reversed-adversary '.run = $run' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v late="$reversed_adversary" 'NR == 9 { print late } { print }' >"$EVENT_DIR/run-reversed-adversary/events.jsonl"

reversed_plan_adversary="$(sed -n '3p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-reversed-plan-adversary --arg ts "$late_ts" '.run = $run | .ts = $ts | .detail.verdict = "BLOCK"')"
jq -c --arg run run-reversed-plan-adversary '.run = $run' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v late="$reversed_plan_adversary" 'NR == 9 { print late } { print }' >"$EVENT_DIR/run-reversed-plan-adversary/events.jsonl"

native_failure="$(jq -nc --arg run run-native-validation-failed --arg ts "$late_ts" '{schema_version:2,ts:$ts,event:"validation_failed",run:$run,detail:{command:"true",exit:1,failure:"native test failure"}}')"
jq -c --arg run run-native-validation-failed '.run = $run' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v late="$native_failure" 'NR == 9 { print late } { print }' >"$EVENT_DIR/run-native-validation-failed/events.jsonl"

native_recovered_failure="$(printf '%s\n' "$native_failure" | jq -c --arg run run-native-validation-recovered '.run = $run')"
native_recovery="$(sed -n '5p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-native-validation-recovered --arg ts "$late_ts" '.run = $run | .ts = $ts')"
jq -c --arg run run-native-validation-recovered '.run = $run' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v failure="$native_recovered_failure" -v recovery="$native_recovery" 'NR == 9 { print failure; print recovery } { print }' >"$EVENT_DIR/run-native-validation-recovered/events.jsonl"

native_other_failure="$(printf '%s\n' "$native_failure" | jq -c --arg run run-native-validation-other-success '.run = $run | .detail.command = "npm test"')"
native_other_success="$(sed -n '5p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-native-validation-other-success --arg ts "$late_ts" '.run = $run | .ts = $ts | .detail.command = "npm run lint"')"
jq -c --arg run run-native-validation-other-success '.run = $run' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v failure="$native_other_failure" -v success="$native_other_success" 'NR == 9 { print failure; print success } { print }' >"$EVENT_DIR/run-native-validation-other-success/events.jsonl"

recovered_validation="$(sed -n '5p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-recovered-evidence --arg ts "$late_ts" '.run = $run | .ts = $ts')"
recovered_review="$(sed -n '7p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-recovered-evidence --arg ts "$late_ts" '.run = $run | .ts = $ts')"
recovered_adversary="$(sed -n '8p' "$EVENT_DIR/run-complete/events.jsonl" | jq -c --arg run run-recovered-evidence --arg ts "$late_ts" '.run = $run | .ts = $ts')"
jq -c --arg run run-recovered-evidence '
  .run = $run |
  if .event == "validation_run" then .detail.exit = 1
  elif .event == "review_completed" then .detail.status = "BLOCK"
  elif .event == "adversary_completed" and .detail.mode == "code_diff" then .detail.verdict = "BLOCK"
  else . end
' "$EVENT_DIR/run-complete/events.jsonl" |
  awk -v validation="$recovered_validation" -v review="$recovered_review" -v adversary="$recovered_adversary" 'NR == 9 { print validation; print review; print adversary } { print }' >"$EVENT_DIR/run-recovered-evidence/events.jsonl"

for reversal in \
  'run-reversed-validation:latest validation attempt' \
  'run-reversed-review:latest review_completed' \
  'run-reversed-adversary:latest code_diff adversary' \
  'run-reversed-plan-adversary:latest plan adversary' \
  'run-native-validation-failed:latest validation attempt' \
  'run-native-validation-other-success:latest validation attempt'; do
  reversal_slug="${reversal%%:*}"
  reversal_message="${reversal#*:}"
  for reversal_profile in autonomous-completed autonomous-completed-strict; do
    out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate "$reversal_slug" --profile "$reversal_profile")"
    assert_contains "$out" "$reversal_message"
  done
done
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-recovered-evidence --profile autonomous-completed)"
assert_contains "$out" "15 events, ok"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-native-validation-recovered --profile autonomous-completed)"
assert_contains "$out" "14 events, ok"

allowed_events="$(awk '
  /^ALLOWED_EVENTS=\(/ { inside=1; next }
  inside && /^\)/ { inside=0; next }
  inside { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); if ($0 != "") print $0 }
' "$ROOT_DIR/scripts/workflow-event" | jq -Rsc 'split("\n") | map(select(length > 0))')"
for batch_case in \
  'run-failed-validation:latest validation attempt' \
  'run-blocked-review:latest review_completed' \
  'run-blocked-adversary:latest code_diff adversary' \
  'run-stale-evidence:after last file change' \
  'run-stale-evidence-spaced:after last file change' \
  'run-reversed-validation:latest validation attempt' \
  'run-reversed-review:latest review_completed' \
  'run-reversed-adversary:latest code_diff adversary' \
  'run-reversed-plan-adversary:latest plan adversary' \
  'run-native-validation-failed:latest validation attempt' \
  'run-native-validation-other-success:latest validation attempt'; do
  batch_slug="${batch_case%%:*}"
  batch_message="${batch_case#*:}"
  batch_out="$(jq -Rrs \
    --arg mode batch \
    --arg slug "$batch_slug" \
    --arg profile autonomous-completed \
    --argjson allowed "$allowed_events" \
    -f "$ROOT_DIR/scripts/lib/workflow-event-detail.jq" \
    "$EVENT_DIR/$batch_slug/events.jsonl")"
  assert_contains "$batch_out" "ERR"
  assert_contains "$batch_out" "$batch_message"
done
for strict_reversal in \
  'run-reversed-validation:latest validation attempt' \
  'run-reversed-review:latest review_completed' \
  'run-reversed-adversary:latest code_diff adversary' \
  'run-reversed-plan-adversary:latest plan adversary' \
  'run-native-validation-failed:latest validation attempt' \
  'run-native-validation-other-success:latest validation attempt'; do
  strict_slug="${strict_reversal%%:*}"
  strict_message="${strict_reversal#*:}"
  strict_out="$(jq -Rrs \
    --arg mode batch \
    --arg slug "$strict_slug" \
    --arg profile autonomous-completed-strict \
    --argjson allowed "$allowed_events" \
    -f "$ROOT_DIR/scripts/lib/workflow-event-detail.jq" \
    "$EVENT_DIR/$strict_slug/events.jsonl")"
  assert_contains "$strict_out" "ERR"
  assert_contains "$strict_out" "$strict_message"
done
recovered_batch="$(jq -Rrs \
  --arg mode batch \
  --arg slug run-recovered-evidence \
  --arg profile autonomous-completed \
  --argjson allowed "$allowed_events" \
  -f "$ROOT_DIR/scripts/lib/workflow-event-detail.jq" \
  "$EVENT_DIR/run-recovered-evidence/events.jsonl")"
assert_contains "$recovered_batch" "OK"
native_recovered_batch="$(jq -Rrs \
  --arg mode batch \
  --arg slug run-native-validation-recovered \
  --arg profile autonomous-completed \
  --argjson allowed "$allowed_events" \
  -f "$ROOT_DIR/scripts/lib/workflow-event-detail.jq" \
  "$EVENT_DIR/run-native-validation-recovered/events.jsonl")"
assert_contains "$native_recovered_batch" "OK"

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
  cat "$ROOT_DIR/workflow/events.md" "$ROOT_DIR/workflow/events-validator.md" |
    awk -F'|' '/^\| `[^`]+` / { gsub(/[`[:space:]]/, "", $2); print $2 }' |
    grep -v '^program_\*$' | sort
)"
if ! diff -u <(printf '%s\n' "$script_types") <(printf '%s\n' "$doc_types"); then
  printf 'workflow event type list drifted between docs and script\n' >&2
  exit 1
fi

if [ -d "$ROOT_DIR/.workflow/plan012-selftest" ]; then
  printf 'smoke test should not write to the repo .workflow directory\n' >&2
  exit 1
fi

# Tranche 4 e2e: quality_completed passes every layer (vocab → schema →
# integrity selection → retrospect shape AND decision). Blocked (not completed)
# is the terminal: completed appends enforce the full autonomous chain, which is
# not this pin's subject. Ledger timestamps are shifted post-validate to
# bracket the frozen fixture trace window (2026-09-20T10:00–10:03Z); CLI stamps
# wall-clock and retrospect binds trace↔ledger windows, so unshifted ledgers
# stop at trace_window_mismatch before any shape verdict.
EW="$TMP_DIR/e2e"
"$ROOT_DIR/scripts/workflow-event" --dir "$EW/.workflow" append e2e route_decided '{"route":"plan-implement","reason":"smoke"}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EW/.workflow" append e2e plan_created '{"path":"PLAN.md","status":"READY"}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EW/.workflow" append e2e quality_completed '{"status":"pass","evidence":"smoke"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EW/.workflow" validate e2e)"
assert_contains "$out" "3 events, ok"
printf '{"schema_version":1,"run":"e2e"}' > "$EW/.workflow/active-run.json"
node -e 'import(process.argv[1]).then(m => { const r = m.selectActiveLedger(process.argv[2]); if (!r.ledger || r.ledger.run !== "e2e") { console.error("not selected: " + r.reason); process.exit(1); } })' "$ROOT_DIR/scripts/lib/ledger-integrity.mjs" "$EW"
"$ROOT_DIR/scripts/workflow-event" --dir "$EW/.workflow" append e2e blocked '{"reason":"smoke terminal","needed_input":"none"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EW/.workflow" validate e2e)"
assert_contains "$out" "4 events, ok"

# Tranche 5: ship_completed vocabulary — success/arrêt dual form, strict
# rejects (numbers, matrix, format, presence), ship profiles, batch mirror,
# legacy lenience, terminal order, e2e append→terminal→cleanup→validate.
t5_ship_ok='{"cumulative_review":"main...HEAD @ abc123","thermo_nuclear":"clean","pr_body_style":"write-direct","delta_rereview":"n/a","deciding_code":"complete","escaped_defects_recorded":0,"pr_url":"https://example.test/pr/1","ci_state":"green"}'
t5_ship_open='{"cumulative_review":"main...HEAD @ abc123","thermo_nuclear":"findings:2-open","pr_body_style":"write-direct","delta_rereview":"n/a","deciding_code":"complete","escaped_defects_recorded":0,"pr_url":"https://example.test/pr/1","ci_state":"green"}'
t5_ship_stop5='{"cumulative_review":"not-reached:6","thermo_nuclear":"findings:3-open","pr_body_style":"not-reached:9","delta_rereview":"not-reached:11","deciding_code":"not-reached:6","escaped_defects_recorded":0,"pr_url":"https://example.test/pr/2","ci_state":"capped"}'
open_t5_ledger() {
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "$1" file_changed '{"path":"wt","change":"run ouvert"}' >/dev/null
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "$1" validation_run '{"command":"c","exit":0}' >/dev/null
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "$1" outcome_metric '{"outcome":"ship","success":true,"measured":false,"reason":"smoke"}' >/dev/null
}
open_t5_ledger t5-ok
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-ok ship_completed "$t5_ship_ok" >/dev/null
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-ok --profile ship-completed)"
assert_contains "$out" "4 events, ok"
open_t5_ledger t5-open
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-open ship_completed "$t5_ship_open" >/dev/null
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-open --profile ship-completed)"
assert_contains "$out" "success-form ship_completed"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-open blocked '{"reason":"open findings","needed_input":"fix then reship"}' >/dev/null
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-open --profile ship-stopped)"
assert_contains "$out" "5 events, ok"
open_t5_ledger t5-stop5
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-stop5 ship_completed "$t5_ship_stop5" >/dev/null
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-stop5 blocked '{"reason":"stop step 5","needed_input":"human decision"}' >/dev/null
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-stop5 --profile ship-stopped)"
assert_contains "$out" "5 events, ok"
# Success content + blocked is not a stopped run (negated success form).
open_t5_ledger t5-greenstop
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-greenstop ship_completed "$t5_ship_ok" >/dev/null
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-greenstop blocked '{"reason":"stop","needed_input":"x"}' >/dev/null
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-greenstop --profile ship-stopped)"
assert_contains "$out" "non-success-form ship_completed"
# Failed-latest validation poisons ship-completed freshness.
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-stale file_changed '{"path":"wt","change":"run ouvert"}' >/dev/null
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-stale validation_run '{"command":"c","exit":0}' >/dev/null
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-stale validation_failed '{"command":"c","exit":1,"failure":"red"}' >/dev/null
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-stale outcome_metric '{"outcome":"ship","success":true,"measured":false,"reason":"smoke"}' >/dev/null
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-stale ship_completed "$t5_ship_ok" >/dev/null
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-stale --profile ship-completed)"
assert_contains "$out" "every latest attempt succeeding"
# Strict rejects: wrong not-reached numbers (one per distinct step).
open_t5_ledger t5-badnum
for wrong in '.thermo_nuclear = "not-reached:7"' '.cumulative_review = "not-reached:5"' '.pr_body_style = "not-reached:5"' '.delta_rereview = "not-reached:6"' '.deciding_code = "not-reached:9"'; do
  bad_detail="$(printf '%s' "$t5_ship_stop5" | jq -c "$wrong")"
  out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-badnum ship_completed "$bad_detail")"
  assert_contains "$out" "invalid json detail for event ship_completed"
done
# Strict rejects: matrix cells (green/capped demand a URL, not-run forbids one).
for wrong in '.pr_url = null' '.ci_state = "not-run"'; do
  bad_detail="$(printf '%s' "$t5_ship_ok" | jq -c "$wrong")"
  out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-badnum ship_completed "$bad_detail")"
  assert_contains "$out" "invalid json detail for event ship_completed"
done
bad_detail="$(printf '%s' "$t5_ship_stop5" | jq -c '.pr_url = null')"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-badnum ship_completed "$bad_detail")"
assert_contains "$out" "invalid json detail for event ship_completed"
# Strict rejects: formless cumulative record, SHA-less record, missing pr_url key.
bad_detail="$(printf '%s' "$t5_ship_ok" | jq -c '.cumulative_review = "nonsense"')"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-badnum ship_completed "$bad_detail")"
assert_contains "$out" "invalid json detail for event ship_completed"
bad_detail="$(printf '%s' "$t5_ship_ok" | jq -c '.cumulative_review = "...HEAD @ "')"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-badnum ship_completed "$bad_detail")"
assert_contains "$out" "invalid json detail for event ship_completed"
bad_detail="$(printf '%s' "$t5_ship_stop5" | jq -c 'del(.pr_url)')"
out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-badnum ship_completed "$bad_detail")"
assert_contains "$out" "invalid json detail for event ship_completed"
# incomplete deciding: strict-valid, routed away from success, accepted stopped.
open_t5_ledger t5-inc
bad_detail="$(printf '%s' "$t5_ship_ok" | jq -c '.deciding_code = "incomplete"')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-inc ship_completed "$bad_detail" >/dev/null
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-inc --profile ship-completed)"
assert_contains "$out" "success-form ship_completed"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-inc blocked '{"reason":"incomplete deciding","needed_input":"x"}' >/dev/null
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-inc --profile ship-stopped)"
assert_contains "$out" "5 events, ok"
# Valid arrêt matrix cells: not-run+null, blocked±PR.
for cell in '{"pr_url":null,"ci_state":"not-run"}' '{"pr_url":"https://example.test/pr/3","ci_state":"blocked"}' '{"pr_url":null,"ci_state":"blocked"}'; do
  slug="t5-cell-$(printf '%s' "$cell" | jq -r '.ci_state')-$(printf '%s' "$cell" | jq -r 'if .pr_url == null then "nopr" else "pr" end')"
  open_t5_ledger "$slug"
  cell_detail="$(printf '%s' "$t5_ship_stop5" | jq -c --argjson cell "$cell" '. * $cell')"
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "$slug" ship_completed "$cell_detail" >/dev/null
  "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append "$slug" blocked '{"reason":"stop","needed_input":"x"}' >/dev/null
  out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate "$slug" --profile ship-stopped)"
  assert_contains "$out" "5 events, ok"
done
# Terminal order: nothing but blocked follows ship_completed.
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-ok file_changed '{"path":"x","change":"late"}')"
assert_contains "$out" "refusing append after terminal event"
# Batch jq mirror agrees with the CLI on all four profile outcomes.
t5_allowed="$(awk '
  /^ALLOWED_EVENTS=\(/ { inside=1; next }
  inside && /^\)/ { inside=0; next }
  inside { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); if ($0 != "") print $0 }
' "$ROOT_DIR/scripts/workflow-event" | jq -Rsc 'split("\n") | map(select(length > 0))')"
t5_batch() {
  jq -Rrs --arg mode batch --arg slug "$1" --arg profile "$2" \
    --argjson allowed "$t5_allowed" -f "$ROOT_DIR/scripts/lib/workflow-event-detail.jq" \
    "$EVENT_DIR/$1/events.jsonl" | head -1
}
[ "$(t5_batch t5-stop5 ship-stopped)" = "OK" ] || { printf 'batch jq rejected the stopped order\n' >&2; exit 1; }
[ "$(t5_batch t5-ok ship-completed)" = "OK" ] || { printf 'batch jq rejected the success order\n' >&2; exit 1; }
[ "$(t5_batch t5-greenstop ship-stopped)" = "ERR" ] || { printf 'batch jq accepted green content as stopped\n' >&2; exit 1; }
[ "$(t5_batch t5-stale ship-completed)" = "ERR" ] || { printf 'batch jq accepted a failed-latest validation\n' >&2; exit 1; }
# Legacy envelope: ship_completed unconstrained (AC4).
mkdir -p "$EVENT_DIR/t5-legacy"
printf '{"ts":"2026-09-24T00:00:01Z","event":"file_changed","run":"t5-legacy","detail":{"paths":["f"],"change":"c"}}\n' > "$EVENT_DIR/t5-legacy/events.jsonl"
printf '{"ts":"2026-09-24T00:00:02Z","event":"ship_completed","run":"t5-legacy","detail":{"whatever":"legacy garbage"}}\n' >> "$EVENT_DIR/t5-legacy/events.jsonl"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-legacy)"
assert_contains "$out" "2 events, ok"
# Legacy stopped order: CLI reports post-terminal compatibility and the batch
# mirror counts it as legacy (the clean carve-out is v2-only).
mkdir -p "$EVENT_DIR/t5-legacy-stop"
printf '{"ts":"2026-09-24T00:00:01Z","event":"ship_completed","run":"t5-legacy-stop","detail":{"whatever":"legacy garbage"}}\n' > "$EVENT_DIR/t5-legacy-stop/events.jsonl"
printf '{"ts":"2026-09-24T00:00:02Z","event":"blocked","run":"t5-legacy-stop","detail":{"reason":"stop","needed_input":"x"}}\n' >> "$EVENT_DIR/t5-legacy-stop/events.jsonl"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-legacy-stop)"
assert_contains "$out" "legacy post-terminal compatibility"
t5_legacy_batch="$(jq -Rrs --arg mode batch --arg slug t5-legacy-stop --arg profile ship-stopped \
  --argjson allowed "$t5_allowed" -f "$ROOT_DIR/scripts/lib/workflow-event-detail.jq" \
  "$EVENT_DIR/t5-legacy-stop/events.jsonl")"
[ "$(printf '%s\n' "$t5_legacy_batch" | sed -n '1p')" = "OK" ] || { printf 'batch jq rejected the legacy stopped order\n' >&2; exit 1; }
[ "$(printf '%s\n' "$t5_legacy_batch" | sed -n '5p')" = "1" ] || { printf 'batch jq miscounted legacy post-terminal lines\n' >&2; exit 1; }
# Multi-receipt legacy ledgers: CLI and batch both judge the LAST receipt
# (an earlier matching receipt must not decide the profile). Legacy
# envelopes + strict-shaped context so the profile reaches the form check.
mkdir -p "$EVENT_DIR/t5-multi-ok"
printf '{"ts":"2026-09-24T00:00:01Z","event":"file_changed","run":"t5-multi-ok","detail":{"path":"wt","change":"run ouvert"}}\n' > "$EVENT_DIR/t5-multi-ok/events.jsonl"
printf '{"ts":"2026-09-24T00:00:02Z","event":"validation_run","run":"t5-multi-ok","detail":{"command":"c","exit":0}}\n' >> "$EVENT_DIR/t5-multi-ok/events.jsonl"
printf '{"ts":"2026-09-24T00:00:03Z","event":"outcome_metric","run":"t5-multi-ok","detail":{"outcome":"ship","success":true,"measured":false,"reason":"smoke"}}\n' >> "$EVENT_DIR/t5-multi-ok/events.jsonl"
printf '{"ts":"2026-09-24T00:00:04Z","event":"ship_completed","run":"t5-multi-ok","detail":%s}\n' "$t5_ship_ok" >> "$EVENT_DIR/t5-multi-ok/events.jsonl"
printf '{"ts":"2026-09-24T00:00:05Z","event":"ship_completed","run":"t5-multi-ok","detail":{"whatever":"legacy garbage"}}\n' >> "$EVENT_DIR/t5-multi-ok/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-multi-ok --profile ship-completed)"
assert_contains "$out" "success-form ship_completed"
mkdir -p "$EVENT_DIR/t5-multi-stop"
printf '{"ts":"2026-09-24T00:00:01Z","event":"file_changed","run":"t5-multi-stop","detail":{"path":"wt","change":"run ouvert"}}\n' > "$EVENT_DIR/t5-multi-stop/events.jsonl"
printf '{"ts":"2026-09-24T00:00:02Z","event":"validation_run","run":"t5-multi-stop","detail":{"command":"c","exit":0}}\n' >> "$EVENT_DIR/t5-multi-stop/events.jsonl"
printf '{"ts":"2026-09-24T00:00:03Z","event":"outcome_metric","run":"t5-multi-stop","detail":{"outcome":"ship","success":true,"measured":false,"reason":"smoke"}}\n' >> "$EVENT_DIR/t5-multi-stop/events.jsonl"
printf '{"ts":"2026-09-24T00:00:04Z","event":"ship_completed","run":"t5-multi-stop","detail":{"whatever":"legacy garbage"}}\n' >> "$EVENT_DIR/t5-multi-stop/events.jsonl"
printf '{"ts":"2026-09-24T00:00:05Z","event":"ship_completed","run":"t5-multi-stop","detail":%s}\n' "$t5_ship_ok" >> "$EVENT_DIR/t5-multi-stop/events.jsonl"
printf '{"ts":"2026-09-24T00:00:06Z","event":"blocked","run":"t5-multi-stop","detail":{"reason":"stop","needed_input":"x"}}\n' >> "$EVENT_DIR/t5-multi-stop/events.jsonl"
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-multi-stop --profile ship-stopped)"
assert_contains "$out" "non-success-form ship_completed"
[ "$(t5_batch t5-multi-ok ship-completed)" = "ERR" ] || { printf 'batch judged an earlier receipt for completed\n' >&2; exit 1; }
[ "$(t5_batch t5-multi-stop ship-stopped)" = "ERR" ] || { printf 'batch judged an earlier receipt for stopped\n' >&2; exit 1; }
# E2e: append→terminal→cleanup→validate (a scratch worktree removal changes
# nothing about ledger validity).
mkdir -p "$TMP_DIR/scratch-wt"
open_t5_ledger t5-e2e
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-e2e ship_completed "$t5_ship_ok" >/dev/null
rm -rf "$TMP_DIR/scratch-wt"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate t5-e2e --profile ship-completed)"
assert_contains "$out" "4 events, ok"
# Ship terminals drive the activate/pointer lifecycle like other terminals.
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-ptr file_changed '{"path":"wt","change":"run ouvert"}' >/dev/null
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" activate t5-ptr)"
assert_contains "$out" "active run: t5-ptr"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-ptr validation_run '{"command":"c","exit":0}' >/dev/null
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-ptr outcome_metric '{"outcome":"ship","success":true,"measured":false,"reason":"smoke"}' >/dev/null
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append t5-ptr ship_completed "$t5_ship_ok" >/dev/null
[ ! -e "$EVENT_DIR/active-run.json" ] || { printf 'ship_completed append did not clear the pointer\n' >&2; exit 1; }
out="$(expect_status 1 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" activate t5-ptr)"
assert_contains "$out" "cannot activate a terminal ledger"
# Runtime ledger-integrity mirror: accepts the stopped order, rejects any
# other post-ship_completed event. Runs last: it pollutes t5-ok on purpose.
export EVENT_DIR ROOT_DIR
node --input-type=module <<'EOF'
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { appendFileSync } from "node:fs";
const root = process.env.ROOT_DIR;
const dir = process.env.EVENT_DIR;
const { inspectLedgerFile } = await import(
  pathToFileURL(join(root, "scripts/lib/ledger-integrity.mjs")).href
);
const stopped = inspectLedgerFile(join(dir, "t5-stop5", "events.jsonl"), "t5-stop5");
if (!stopped.valid) throw new Error(`integrity rejected stopped order: ${stopped.reason}`);
const success = inspectLedgerFile(join(dir, "t5-ok", "events.jsonl"), "t5-ok");
if (!success.valid) throw new Error(`integrity rejected success order: ${success.reason}`);
appendFileSync(
  join(dir, "t5-ok", "events.jsonl"),
  '{"schema_version":2,"ts":"2027-01-01T00:00:00Z","event":"file_changed","run":"t5-ok","detail":{"path":"x","change":"late"}}\n'
);
const late = inspectLedgerFile(join(dir, "t5-ok", "events.jsonl"), "t5-ok");
if (late.valid || late.reason !== "terminal_not_final") {
  throw new Error(`integrity accepted a non-blocked post-terminal event: ${late.reason}`);
}
EOF

printf 'workflow event smoke test: ok\n'
