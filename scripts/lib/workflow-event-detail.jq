def nonempty_string: type == "string" and length > 0;
def boolean: type == "boolean";
def nonnegative_number: type == "number" and . >= 0;
def nonnegative_integer: nonnegative_number and floor == .;
def positive_integer: nonnegative_integer and . > 0;
def string_array: type == "array" and all(.[]; nonempty_string);
def evidence: nonempty_string or string_array;
def optional_string($value): $value == null or ($value | nonempty_string);
def optional_string_array($value): $value == null or ($value | string_array);
def harness_result:
  (.population | nonempty_string) and (.passed | nonnegative_integer) and (.total | positive_integer) and (.passed <= .total);
def usage_valid:
  (.measured | boolean) and
  if .measured then
    (.input_tokens | nonnegative_number) and (.output_tokens | nonnegative_number) and
    (.total_tokens | nonnegative_number) and (.total_tokens >= (.input_tokens + .output_tokens)) and
    (.elapsed_ms | nonnegative_number)
  else true
  end;
def participant_valid:
  (.id | nonempty_string) and
  (.model | IN("openai-codex/gpt-5.6-luna", "openai-codex/gpt-5.6-terra", "openai-codex/gpt-5.6-sol", "zai/glm-5.2", "kimi-coding/k3")) and
  (.family | IN("openai", "zai", "kimi")) and
  if (.model | startswith("openai-codex/")) then .family == "openai"
  elif (.model | startswith("zai/")) then .family == "zai"
  else .family == "kimi"
  end;
def protocol_v2_shape:
  (.trigger | IN("explicit", "adaptive")) and
  (.strategy | IN("scout", "council")) and
  (.signals | type == "array") and
  (all(.signals[]; . | IN("critical-risk", "system-complexity", "uncertainty", "prompt-failure-history"))) and
  ((.signals | unique | length) == (.signals | length)) and
  (if .trigger == "adaptive" then (.signals | length) > 0 else true end) and
  (.rounds | type == "object") and (.rounds.first_pass == 1) and
  (.rounds.rebuttal | IN(0, 1)) and (.rounds.adjudication | IN(0, 1)) and
  (.claim_count | nonnegative_number) and (.disagreement_count | nonnegative_number) and
  (.stop_reason | IN("agreement", "deterministic_check", "rebuttal_resolved", "budget_cap", "adjudicated", "degraded", "blocked")) and
  (.budget | type == "object") and (.budget.max_claims == 6) and
  (.budget.first_pass_output_tokens | nonnegative_number) and
  (.budget.rebuttal_output_tokens | nonnegative_number) and
  (.budget.adjudication_output_tokens | nonnegative_number) and
  (.budget.total_output_tokens | nonnegative_number) and
  (.stage_usage | type == "object") and
  (.stage_usage.first_pass | usage_valid) and
  (.stage_usage.rebuttal | usage_valid) and
  (.stage_usage.adjudication | usage_valid) and
  (if .strategy == "scout" then
    (.rounds.rebuttal == 0) and (.rounds.adjudication == 0) and (.adjudicator == null)
  else
    if .rounds.adjudication == 1 then .adjudicator == "etabli-sol-judge" else .adjudicator == null end
  end) and
  (((.claim_count > .budget.max_claims) or
    ((.stage_usage.first_pass.measured == true) and (.stage_usage.first_pass.output_tokens > .budget.first_pass_output_tokens)) or
    ((.stage_usage.rebuttal.measured == true) and (.stage_usage.rebuttal.output_tokens > .budget.rebuttal_output_tokens)) or
    ((.stage_usage.adjudication.measured == true) and (.stage_usage.adjudication.output_tokens > .budget.adjudication_output_tokens)) or
    ((.usage.measured == true) and (.usage.output_tokens > .budget.total_output_tokens))) as $over_budget |
    ($over_budget == (.stop_reason == "budget_cap")) and
    (if $over_budget then (.verdict | IN("degraded", "blocked")) else true end));
def protocol_v2_consistent:
  (.independent_first_passes == true) and
  (.verdict | IN("accepted", "degraded", "blocked")) and
  (.disagreement == (.disagreement_count > 0)) and
  (.disagreement_count <= .claim_count) and
  (([.participants[].id] | unique | length) == (.participants | length)) and
  (all(.participants[]; .model != "openai-codex/gpt-5.6-sol")) and
  (([.participants[].model]) as $models |
    (($models | unique | length) == ($models | length)) and
    if .strategy == "scout" then
      if .fallback_status == "none" then
        ($models | length) == 1 and ($models[0] | IN("openai-codex/gpt-5.6-luna", "openai-codex/gpt-5.6-terra"))
      else
        (($models | index("kimi-coding/k3")) != null) and (($models | length) <= 2) and
        (all($models[]; . | IN("openai-codex/gpt-5.6-luna", "openai-codex/gpt-5.6-terra", "kimi-coding/k3")))
      end
    else
      if .fallback_status == "none" then
        ($models | length) == 2 and (($models | index("zai/glm-5.2")) != null) and
        (any($models[]; . | IN("openai-codex/gpt-5.6-luna", "openai-codex/gpt-5.6-terra")))
      elif ($models | length) == 2 then
        (($models | index("kimi-coding/k3")) != null) and
        (any($models[]; . | IN("openai-codex/gpt-5.6-luna", "openai-codex/gpt-5.6-terra", "zai/glm-5.2")))
      else
        ($models | length) == 3 and (($models | index("kimi-coding/k3")) != null) and
        (($models | index("zai/glm-5.2")) != null) and
        (any($models[]; . | IN("openai-codex/gpt-5.6-luna", "openai-codex/gpt-5.6-terra")))
      end
    end) and
  (if .strategy == "scout" then
    ((.participants | length) >= 1) and ((.participants | length) <= 2) and
    (.budget == {max_claims:6, first_pass_output_tokens:600, rebuttal_output_tokens:0, adjudication_output_tokens:0, total_output_tokens:600})
  else
    ((.participants | length) >= 2) and ((.participants | length) <= 3) and
    (.budget == {max_claims:6, first_pass_output_tokens:1800, rebuttal_output_tokens:700, adjudication_output_tokens:650, total_output_tokens:3500})
  end) and
  (if .trigger == "explicit" then .strategy == "council"
  elif .strategy == "scout" then (.signals | length) == 1 and (.signals[0] != "critical-risk")
  else ((.signals | index("critical-risk")) != null) or ((.signals | length) >= 2)
  end) and
  ((any(.participants[]; .model == "kimi-coding/k3")) == (.fallback_status != "none")) and
  (if .fallback_status == "degraded" then .verdict == "degraded"
  elif .fallback_status == "blocked" then .verdict == "blocked"
  else true
  end) and
  (if .verdict == "accepted" then
    (.stop_reason | IN("agreement", "deterministic_check", "rebuttal_resolved", "adjudicated")) and (.fallback_status == "none")
  elif .verdict == "degraded" then
    (.stop_reason | IN("agreement", "deterministic_check", "rebuttal_resolved", "adjudicated", "budget_cap", "degraded"))
  else .stop_reason | IN("budget_cap", "blocked")
  end) and
  (if (.stop_reason | IN("agreement", "deterministic_check")) then .disagreement_count == 0
  elif (.stop_reason | IN("rebuttal_resolved", "adjudicated")) then .disagreement_count > 0
  else true
  end) and
  (if .stop_reason | IN("agreement", "deterministic_check") then
    (.rounds.rebuttal == 0) and (.rounds.adjudication == 0)
  elif .stop_reason == "rebuttal_resolved" then
    (.rounds.rebuttal == 1) and (.rounds.adjudication == 0)
  elif .stop_reason == "adjudicated" then
    (.rounds.rebuttal == 1) and (.rounds.adjudication == 1)
  else true
  end) and
  (if .rounds.rebuttal == 0 then .stage_usage.rebuttal.measured == false else true end) and
  (if .rounds.adjudication == 0 then .stage_usage.adjudication.measured == false else true end);
def multi_execution_completed_detail:
  type == "object" and
  (.participants | type == "array") and ((.participants | length) > 0) and ((.participants | length) <= 3) and
  (all(.participants[]; participant_valid)) and
  (.independent_first_passes | boolean) and (.disagreement | boolean) and
  ((.adjudicator == null) or (.adjudicator == "etabli-sol-judge")) and
  (.verdict | IN("accepted", "degraded", "blocked", "rollback_to_opt_in")) and
  (.usage | type == "object") and (.usage | usage_valid) and
  (.fallback_status | IN("none", "degraded", "blocked")) and
  if (.protocol_version // 1) == 1 then
    (.protocol_version == null) or (.protocol_version == 1)
  elif .protocol_version == 2 then
    protocol_v2_shape and protocol_v2_consistent
  else false
  end;

def strict_detail($event):
  type == "object" and
  if $event == "route_decided" then
    (.route | nonempty_string) and (.reason | nonempty_string)
  elif $event == "plan_created" then
    (.path | nonempty_string) and (.status | IN("DRAFT", "CHALLENGED", "READY"))
  elif $event == "adversary_completed" then
    (.mode | IN("plan", "code_diff")) and (.verdict | nonempty_string) and
    (.accepted_findings | string_array) and (.rejected_findings | string_array)
  elif $event == "review_completed" or $event == "simplification_completed" then
    (.status | nonempty_string) and (.evidence | evidence)
  elif $event == "file_changed" then
    (.path | nonempty_string) and (.change | nonempty_string)
  elif $event == "validation_run" then
    (.command | nonempty_string) and (.exit | nonnegative_integer)
  elif $event == "validation_failed" then
    (.command | nonempty_string) and (.exit | positive_integer) and (.failure | nonempty_string)
  elif $event == "dogfood_matrix_created" then
    (.path | nonempty_string) and (.flows | nonnegative_integer) and (.scenarios | nonnegative_integer)
  elif $event == "dogfood_scenario_run" then
    (.scenario | nonempty_string) and (.surface | nonempty_string) and (.status | nonempty_string) and (.artifacts | string_array)
  elif $event == "dogfood_fix_applied" then
    (.scenario | nonempty_string) and (.fix | nonempty_string) and (.evidence | evidence)
  elif $event == "dogfood_blocked" then
    (.scenario | nonempty_string) and (.reason | nonempty_string) and (.needed_input | nonempty_string)
  elif $event == "self_improvement_candidate" then
    (.source | nonempty_string) and (.category | nonempty_string) and (.outcome | nonempty_string) and
    (.confidence | nonempty_string) and (.evidence | string_array) and
    optional_string_array(.held_in) and optional_string_array(.held_out)
  elif $event == "harness_failure_pattern" then
    (.terminal_cause | nonempty_string) and (.causal_status | nonempty_string) and
    (.mechanism | nonempty_string) and (.verifier | nonempty_string) and (.traces | string_array)
  elif $event == "harness_proposal" then
    (.candidate | nonempty_string) and (.editable_surfaces | string_array) and (.preserve | string_array) and
    (.held_in | string_array) and (.held_out | string_array)
  elif $event == "harness_validation_completed" then
    (.candidate | nonempty_string) and (.verdict | IN("accepted", "rejected")) and (.reason | nonempty_string) and
    (.checks | string_array) and ((.checks | length) > 0) and (.evidence | string_array) and ((.evidence | length) > 0) and
    (.held_in.baseline | harness_result) and (.held_in.candidate | harness_result) and
    (.held_in.baseline.population == .held_in.candidate.population) and (.held_in.baseline.total == .held_in.candidate.total) and
    (.held_out.baseline | harness_result) and (.held_out.candidate | harness_result) and
    (.held_out.baseline.population == .held_out.candidate.population) and (.held_out.baseline.total == .held_out.candidate.total) and
    (if .verdict == "accepted" then
      (.held_in.candidate.passed > .held_in.baseline.passed) and (.held_out.candidate.passed >= .held_out.baseline.passed)
    else true end)
  elif $event == "harness_candidate_rejected" then
    (.candidate | nonempty_string) and (.reason | nonempty_string) and
    (.regressions | string_array) and (.evidence | string_array)
  elif $event == "project_slice_planned" then
    (.slice | nonempty_string) and (.owner | nonempty_string) and (.validation | nonempty_string) and (.dependencies | string_array)
  elif $event == "project_slice_completed" then
    (.slice | nonempty_string) and (.validation | nonempty_string) and (.evidence | string_array) and (.remaining | string_array)
  elif $event == "runtime_run_attached" then
    (.adapter == "pi-workflow") and (.run_id | test("^workflow_[A-Za-z0-9_-]+$")) and (.workflow | nonempty_string) and
    (.state_path == (".pi/workflows/" + .run_id)) and
    (.status | IN("running", "blocked", "completed", "failed", "interrupted")) and (.usage_measured | boolean)
  elif $event == "multi_execution_completed" then
    multi_execution_completed_detail
  elif $event == "outcome_metric" then
    (.outcome | nonempty_string) and (.success | boolean) and (.measured | boolean) and
    if .measured then
      (.input_tokens | nonnegative_integer) and (.output_tokens | nonnegative_integer) and
      (.total_tokens | nonnegative_integer) and (.total_tokens >= (.input_tokens + .output_tokens)) and
      (.tool_calls | nonnegative_integer) and (.elapsed_ms | nonnegative_number)
    else
      ((.reason // .measurement_reason) | nonempty_string) and
      (.input_tokens? == null) and (.output_tokens? == null) and (.total_tokens? == null) and
      (.tool_calls? == null) and (.elapsed_ms? == null)
    end
  elif $event == "retry_classified" then
    (.failure_class | nonempty_string) and (.next_action | nonempty_string)
  elif $event == "no_progress" then
    (.check_or_hypothesis | nonempty_string) and (.command | nonempty_string) and
    (.attempts | positive_integer) and (.head_sha | nonempty_string) and (.eliminated | string_array)
  elif $event == "handoff" then
    (.branch | nonempty_string) and (.sha | nonempty_string) and (.done | string_array) and
    (.pending | string_array) and (.next_action | nonempty_string) and (.do_not_redo | string_array)
  elif $event == "human_checkpoint" then
    (.category | nonempty_string) and (.decision | nonempty_string) and (.target | nonempty_string)
  elif $event == "archive_written" then
    (.path | nonempty_string)
  elif $event == "plan_removed" then
    .path == "PLAN.md"
  elif $event == "completed" then
    (.summary | nonempty_string)
  elif $event == "blocked" then
    (.reason | nonempty_string) and (.needed_input | nonempty_string)
  else
    false
  end;

def legacy_detail($event):
  strict_detail($event) or
  if $event == "plan_created" then
    (.plan | nonempty_string) and (.status | nonempty_string) and optional_string(.scope)
  elif $event == "adversary_completed" then
    (.verdict | nonempty_string) and (
      (.accepted_findings? | string_array) or (.accepted? | evidence) or
      ((.finding? | nonempty_string) and (.mitigation? | nonempty_string))
    )
  elif $event == "file_changed" then
    ((.paths? | string_array) and ((.change? // .reason? // "") | nonempty_string)) or
    ((.etabli? | string_array) and (.obvault? | string_array)) or
    ((.paths? | string_array) and (.local_cleanup? | evidence))
  elif $event == "validation_run" then
    ((.command? | nonempty_string) and ((.result? // .summary? // .evidence? // .note? // "") | evidence)) or
    ((.commands? | string_array) and ((.result? // "legacy") | nonempty_string)) or
    ((.commands? | type == "array") and all(.commands[]; (.command | nonempty_string) and (.result | nonempty_string)))
  elif $event == "validation_failed" then
    (.command | nonempty_string) and (.result | nonempty_string) and (.cause | nonempty_string)
  elif $event == "outcome_metric" then
    ((.outcome? | nonempty_string) or (.success? | boolean)) and
    optional_string(.reason) and optional_string(.measurement_reason) and
    ([.input_tokens?, .output_tokens?, .total_tokens?, .tool_calls?, .elapsed_ms?] | all(. == null or (type == "number" and . >= 0)))
  elif $event == "retry_classified" then
    (.classification | nonempty_string) and (.action | nonempty_string) and optional_string(.stage) and optional_string(.provider)
  elif $event == "handoff" then
    (.branch | nonempty_string) and (.sha | nonempty_string) and (.next_action | nonempty_string) and
    (.done | evidence) and (.pending | evidence) and (.do_not_redo | evidence)
  elif $event == "archive_written" then
    (.archive | nonempty_string)
  elif $event == "completed" then
    (.result? | nonempty_string) or (.status? | nonempty_string) or (.goal_complete? | boolean)
  elif $event == "harness_failure_pattern" then
    (.terminal_cause | nonempty_string) and (.causal_status | nonempty_string) and
    (.mechanism | nonempty_string) and (.verifier | nonempty_string)
  elif $event == "self_improvement_candidate" then
    (.source | nonempty_string) and (.category | nonempty_string) and (.outcome | nonempty_string) and
    (.confidence | nonempty_string) and (.evidence | evidence) and
    (.held_in? == null or (.held_in | evidence)) and (.held_out? == null or (.held_out | evidence))
  else
    false
  end;

if $strict then strict_detail($event) else legacy_detail($event) end
