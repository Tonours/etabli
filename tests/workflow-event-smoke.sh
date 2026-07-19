#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
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
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-learning harness_candidate_rejected '{"candidate":"auto-apply workflow-retrospect patches","reason":"bypasses reviewed PLAN.md gate","regressions":["external write-back risk","permission boundary weakened"],"evidence":["workflow/skills/self-improvement-loop.md"]}'
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

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-runtime runtime_run_attached '{"adapter":"pi-workflow","run_id":"workflow_mq224pi8_775e71","workflow":"spec-review","state_path":".pi/workflows/workflow_mq224pi8_775e71","status":"running","usage_measured":false}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-runtime)"
assert_contains "$out" "1 events, ok"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel multi_execution_completed '{"participants":[{"id":"agent-terra","model":"openai-codex/gpt-5.6-terra","family":"openai"},{"id":"agent-glm","model":"zai/glm-5.2","family":"zai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":true,"input_tokens":10,"output_tokens":5,"total_tokens":15,"elapsed_ms":100},"fallback_status":"none"}'
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-panel)"
assert_contains "$out" "1 events, ok"

protocol_v2_base='{"protocol_version":2,"participants":[{"id":"agent-luna","model":"openai-codex/gpt-5.6-luna","family":"openai"},{"id":"agent-glm","model":"zai/glm-5.2","family":"zai"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":true,"input_tokens":100,"output_tokens":500,"total_tokens":600,"elapsed_ms":1000},"fallback_status":"none","trigger":"adaptive","strategy":"council","signals":["critical-risk"],"rounds":{"first_pass":1,"rebuttal":0,"adjudication":0},"claim_count":2,"disagreement_count":0,"stop_reason":"agreement","budget":{"max_claims":6,"first_pass_output_tokens":1800,"rebuttal_output_tokens":700,"adjudication_output_tokens":650,"total_output_tokens":3500},"stage_usage":{"first_pass":{"measured":true,"input_tokens":100,"output_tokens":500,"total_tokens":600,"elapsed_ms":900},"rebuttal":{"measured":false},"adjudication":{"measured":false}}}'
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

protocol_v2_scout_fallback="$(printf '%s\n' "$protocol_v2_scout" | jq -c '.participants=[{"id":"agent-kimi","model":"kimi-coding/k3","family":"kimi"}] | .verdict="degraded" | .stop_reason="agreement" | .fallback_status="degraded"')"
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-scout-v2-fallback multi_execution_completed "$protocol_v2_scout_fallback"
out="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate run-scout-v2-fallback)"
assert_contains "$out" "1 events, ok"

protocol_v2_council_fallback="$(printf '%s\n' "$protocol_v2_base" | jq -c '.participants[0]={"id":"agent-kimi","model":"kimi-coding/k3","family":"kimi"} | .verdict="degraded" | .stop_reason="agreement" | .fallback_status="degraded"')"
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

protocol_v2_fallback_adjudicated="$(printf '%s\n' "$protocol_v2_fallback_rebuttal" | jq -c '.stop_reason="adjudicated" | .rounds.adjudication=1 | .adjudicator="etabli-sol-judge"')"
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

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-v2-accepted-fallback multi_execution_completed "$(printf '%s\n' "$protocol_v2_base" | jq -c '.participants[1]={"id":"agent-kimi","model":"kimi-coding/k3","family":"kimi"} | .fallback_status="degraded"')")"
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

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-scout-v2-duplicate-luna multi_execution_completed "$(printf '%s\n' "$protocol_v2_scout" | jq -c '.participants += [{"id":"agent-luna-second","model":"openai-codex/gpt-5.6-luna","family":"openai"}]')")"
assert_contains "$out" "required fields"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-kimi multi_execution_completed '{"participants":[{"id":"agent-kimi","model":"kimi-coding/k3","family":"kimi"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"degraded","usage":{"measured":false},"fallback_status":"degraded"}'
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

out="$(expect_status 2 "$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-panel-bad-judge multi_execution_completed '{"participants":[{"id":"agent","model":"zai/glm-5.2","family":"zai"}],"independent_first_passes":true,"disagreement":true,"adjudicator":"arbitrary-judge","verdict":"accepted","usage":{"measured":false},"fallback_status":"none"}')"
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
