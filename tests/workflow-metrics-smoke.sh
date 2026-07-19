#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a outcome_metric '{"outcome":"success","success":true,"measured":true,"input_tokens":100,"output_tokens":50,"total_tokens":150,"tool_calls":3,"elapsed_ms":1200}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a outcome_metric '{"outcome":"failed","success":false,"measured":true,"input_tokens":200,"output_tokens":25,"total_tokens":225,"tool_calls":1,"elapsed_ms":800}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a harness_proposal '{"candidate":"router guard","editable_surfaces":["router"],"preserve":["answer routes"],"held_in":["miss"],"held_out":["goldens"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a harness_proposal '{"candidate":"router guard","editable_surfaces":["router"],"preserve":["answer routes"],"held_in":["miss"],"held_out":["goldens"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a harness_validation_completed '{"candidate":"router guard","verdict":"rejected","reason":"first candidate revision regressed held-out","held_in":{"baseline":{"population":"router-misses-v1","passed":1,"total":2},"candidate":{"population":"router-misses-v1","passed":2,"total":2}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":3,"total":4}},"checks":["router smoke"],"evidence":["first revision"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a harness_validation_completed '{"candidate":"router guard","verdict":"accepted","reason":"held-in gain without regression","held_in":{"baseline":{"population":"router-misses-v1","passed":1,"total":2},"candidate":{"population":"router-misses-v1","passed":2,"total":2}},"held_out":{"baseline":{"population":"router-goldens-v1","passed":4,"total":4},"candidate":{"population":"router-goldens-v1","passed":4,"total":4}},"checks":["router smoke"],"evidence":["router fixtures"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-b outcome_metric '{"outcome":"success","success":true,"measured":true,"input_tokens":200,"output_tokens":100,"total_tokens":300,"tool_calls":2,"elapsed_ms":1000}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-b harness_validation_completed '{"candidate":"orphan candidate","verdict":"rejected","reason":"no matching proposal in this run","held_in":{"baseline":{"population":"workflow-failures-v1","passed":0,"total":2},"candidate":{"population":"workflow-failures-v1","passed":1,"total":2}},"held_out":{"baseline":{"population":"workflow-smokes-v1","passed":4,"total":4},"candidate":{"population":"workflow-smokes-v1","passed":3,"total":4}},"checks":["workflow smoke"],"evidence":["held-out regression"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-c harness_proposal '{"candidate":"unvalidated candidate","editable_surfaces":["workflow"],"preserve":["gates"],"held_in":["failure"],"held_out":["smokes"]}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-d outcome_metric '{"outcome":"success","success":true,"measured":false,"reason":"runtime telemetry unavailable"}'
mkdir -p "$EVENT_DIR/run-legacy"
cat > "$EVENT_DIR/run-legacy/events.jsonl" <<'JSONL'
{"schema_version":1,"ts":"2026-07-01T00:00:00Z","event":"outcome_metric","run":"run-legacy","detail":{"outcome":"success","success":true,"total_tokens":90,"tool_calls":1,"elapsed_ms":500}}
JSONL
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-runtime multi_execution_completed '{"participants":[{"id":"agent-terra","model":"openai-codex/gpt-5.6-terra","family":"openai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":true,"input_tokens":40,"output_tokens":20,"total_tokens":60,"elapsed_ms":70},"fallback_status":"none"}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-runtime completed '{"summary":"runtime completed without an outcome metric"}'

json_output="$("$ROOT_DIR/scripts/workflow-metrics" --dir "$EVENT_DIR" --json)"
text_output="$("$ROOT_DIR/scripts/workflow-metrics" --dir "$EVENT_DIR")"

printf '%s\n' "$json_output" | jq -e '.totals.outcomes == 5' >/dev/null
printf '%s\n' "$json_output" | jq -e '.totals.measured_outcomes == 3 and .totals.usage_measured_outcomes == 3' >/dev/null
printf '%s\n' "$json_output" | jq -e '.totals.unmeasured_outcomes == 2 and .totals.legacy_outcomes == 1 and .totals.measurement_coverage == 0.5' >/dev/null
printf '%s\n' "$json_output" | jq -e '.totals.successful_outcomes == 4 and .totals.measured_successful_outcomes == 2' >/dev/null
printf '%s\n' "$json_output" | jq -e '.totals.tokens_per_successful_outcome == 225' >/dev/null
printf '%s\n' "$json_output" | jq -e '.totals.total_tokens == 675 and .totals.legacy_total_tokens == 90' >/dev/null
printf '%s\n' "$json_output" | jq -e '.totals.runtime_usage_records == 1 and .totals.runtime_total_tokens == 60 and .totals.runtime_elapsed_ms == 70' >/dev/null
printf '%s\n' "$json_output" | jq -e '.runs[] | select(.run == "run-runtime") | .successful_outcomes == 0 and .runtime_usage_records == 1 and .unmeasured_outcomes == 1' >/dev/null
printf '%s\n' "$json_output" | jq -e '.harness.proposed_candidates == 2' >/dev/null
printf '%s\n' "$json_output" | jq -e '.harness.validated_candidates == 2' >/dev/null
printf '%s\n' "$json_output" | jq -e '.harness.validated_proposals == 1' >/dev/null
printf '%s\n' "$json_output" | jq -e '.harness.unmatched_validations == 1' >/dev/null
printf '%s\n' "$json_output" | jq -e '.harness.accepted_candidates == 1 and .harness.rejected_candidates == 1' >/dev/null
printf '%s\n' "$json_output" | jq -e '.harness.validation_coverage == 0.5' >/dev/null
printf '%s\n' "$json_output" | jq -e '.harness.candidates[] | select(.run == "run-a" and .candidate == "router guard") | .proposed == true and .held_in_delta_pp == 50 and .held_out_delta_pp == 0' >/dev/null
printf '%s\n' "$json_output" | jq -e '.harness.candidates[] | select(.run == "run-b" and .candidate == "orphan candidate") | .proposed == false' >/dev/null
printf '%s\n' "$json_output" | jq -e '.runs[] | select(.run == "run-c") | .harness.validation_coverage == 0' >/dev/null
printf '%s\n' "$json_output" | jq -e '.harness.candidates[] | select(.run == "run-c" and .candidate == "unvalidated candidate") | .proposed == true and .verdict == null and .reason == null and .held_in_delta_pp == null and .held_out_delta_pp == null and .checks == null and .evidence == null' >/dev/null

case "$text_output" in
  *tokens_per_successful_outcome=225*harness_validation_coverage=0.5*) ;;
  *)
    printf 'expected token metric in text output\n%s\n' "$text_output" >&2
    exit 1
    ;;
esac

printf 'workflow metrics smoke test: ok\n'
