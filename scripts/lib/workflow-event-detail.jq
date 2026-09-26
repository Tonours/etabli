def nonempty_string: type == "string" and length > 0;
def provenance_complete:
  (type == "object") and
  (.requested | (type == "object") and (.family | nonempty_string) and (.model | nonempty_string) and (.provider | nonempty_string) and ((has("route") | not) or (.route | nonempty_string))) and
  (.effective | (type == "object") and (.family | nonempty_string) and (.model | nonempty_string) and (.provider | nonempty_string)) and
  (.runner | nonempty_string) and (.run_id | nonempty_string);
def boolean: type == "boolean";
def nonnegative_number: type == "number" and . >= 0;
def nonnegative_integer: nonnegative_number and floor == .;
def positive_integer: nonnegative_integer and . > 0;
def sha256: type == "string" and test("^[a-f0-9]{64}$");
def optional_sha256: . == null or sha256;
def iso_timestamp: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$");
def string_array: type == "array" and all(.[]; nonempty_string);
def evidence: nonempty_string or string_array;
def optional_string($value): $value == null or ($value | nonempty_string);
def optional_string_array($value): $value == null or ($value | string_array);
def harness_result:
  (.population | nonempty_string) and (.passed | nonnegative_integer) and (.total | positive_integer) and (.passed <= .total);
def harness_objective:
  type == "object" and
  (.kind | IN("quality", "efficiency", "reliability")) and
  (.minimum_delta | type == "number" and . > 0) and
  (if .kind == "quality" then .metric == "held_in_passed" and .direction == "increase"
   elif .kind == "efficiency" then (.metric | IN("total_tokens", "elapsed_ms")) and .direction == "decrease" and (.measurement_population | nonempty_string)
   else .metric == "success_rate" and .direction == "increase" and (.measurement_population | nonempty_string) end);
def harness_measurement:
  type == "object" and (.population | nonempty_string) and
  (.metric | nonempty_string) and (.value | nonnegative_number) and
  (.sample_count | positive_integer) and (.sample_count >= 2);
def harness_promotion_policy:
  (.objective // {kind:"quality", metric:"held_in_passed", direction:"increase", minimum_delta:1}) as $objective
  | ($objective | harness_objective) and
    (if $objective.kind == "quality" then
       (.held_in.candidate.passed - .held_in.baseline.passed) >= $objective.minimum_delta
     else
       (.held_in.candidate.passed >= .held_in.baseline.passed) and
       (.measurement.baseline | harness_measurement) and
       (.measurement.candidate | harness_measurement) and
       (.measurement.baseline.population == .measurement.candidate.population) and
       (.measurement.baseline.population == $objective.measurement_population) and
       (.measurement.baseline.metric == $objective.metric) and
       (.measurement.candidate.metric == $objective.metric) and
       (.measurement.baseline.sample_count == .measurement.candidate.sample_count) and
       (if $objective.kind == "efficiency" then
          (.measurement.baseline.value - .measurement.candidate.value) >= $objective.minimum_delta
        else
          (.measurement.baseline.value <= 1) and (.measurement.candidate.value <= 1) and
          (.measurement.candidate.value - .measurement.baseline.value) >= $objective.minimum_delta
        end)
     end);
def usage_valid:
  (.measured | boolean) and
  if .measured then
    (.input_tokens | nonnegative_number) and (.output_tokens | nonnegative_number) and
    (.total_tokens | nonnegative_number) and (.total_tokens >= (.input_tokens + .output_tokens)) and
    (.elapsed_ms | nonnegative_number)
  else true
  end;
def family_matches_model:
  if (.model | startswith("zai/")) then .family == "zai"
  elif (.model | startswith("xai/")) then .family == "xai"
  elif (.model | startswith("openai-codex/")) then .family == "openai-codex"
  elif (.model | startswith("opencode-go/")) then .family == "opencode-go"
  elif (.model | startswith("kimi-coding/")) then .family == "kimi-coding"
  else false
  end;
def participant_valid:
  (.id | nonempty_string) and
  (.model | nonempty_string) and
  (.family | IN("zai", "xai", "openai-codex", "opencode-go", "kimi-coding")) and
  family_matches_model;
# Optional per-participant usage on outcome_metric (blueprint M1). Distinct from
# multi_execution portfolio participants: ids/roles are free-form strings.
def outcome_participant_usage_entry:
  (.id | nonempty_string) and
  ((.role? == null) or (.role | nonempty_string)) and
  (.input_tokens | nonnegative_integer) and
  (.output_tokens | nonnegative_integer) and
  (.total_tokens | nonnegative_integer) and
  (.total_tokens >= (.input_tokens + .output_tokens));
def outcome_participant_usage_valid:
  (.participant_usage? == null) or (
    (.participant_usage | type == "array") and
    ((.participant_usage | length) > 0) and
    (all(.participant_usage[]; outcome_participant_usage_entry)) and
    (([.participant_usage[].id] | unique | length) == (.participant_usage | length)) and
    (if .measured then
      (([.participant_usage[].total_tokens] | add) == .total_tokens)
     else true end)
  );
def outcome_batch_fields_valid:
  ((.batch_wall_clock_ms? == null) or ((.batch_wall_clock_ms | nonnegative_number) and .batch_wall_clock_ms > 0)) and
  ((.batch_started_at? == null) or (.batch_started_at | iso_timestamp)) and
  ((.batch_terminal_at? == null) or (.batch_terminal_at | iso_timestamp)) and
  ((.batch_started_at? == null) or (.batch_terminal_at? == null) or
    (.batch_terminal_at >= .batch_started_at));
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
    if .rounds.adjudication == 1 then (.adjudicator | nonempty_string) else .adjudicator == null end
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
  (([.participants[].model]) as $models |
    (($models | unique | length) == ($models | length)) and
    if .strategy == "scout" then
      if .fallback_status == "none" then
        ($models | length) == 1
      else
        ($models | length) <= 2
      end
    else
      if .fallback_status == "none" then
        ($models | length) == 2
      elif ($models | length) == 2 then
        true
      else
        ($models | length) == 3
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
  ((.adjudicator == null) or (.adjudicator | nonempty_string)) and
  (.verdict | IN("accepted", "degraded", "blocked", "rollback_to_opt_in")) and
  (.usage | type == "object") and (.usage | usage_valid) and
  (.fallback_status | IN("none", "degraded", "blocked")) and
  if (.protocol_version // 1) == 1 then
    (.protocol_version == null) or (.protocol_version == 1)
  elif .protocol_version == 2 then
    protocol_v2_shape and protocol_v2_consistent
  else false
  end;

def outcome_measurement_target:
  type == "object" and
  ((keys | sort) == (["baseline_measured", "baseline_usage_measured", "target_ledger_sha256", "target_outcome_event_sha256", "target_run", "target_terminal", "target_terminal_event_sha256"] | sort)) and
  (.target_run | test("^[a-z0-9][a-z0-9-]*$")) and
  (.target_ledger_sha256 | sha256) and
  (.target_terminal | IN("completed", "blocked")) and
  (.target_terminal_event_sha256 | sha256) and
  (.target_outcome_event_sha256 | optional_sha256) and
  (.baseline_measured | boolean) and (.baseline_usage_measured | boolean) and
  (if .baseline_usage_measured then .baseline_measured else true end);

def outcome_measurement_population_detail:
  type == "object" and
  ((keys | sort) == (["manifest_sha256", "population_id", "targets", "terminal_runs"] | sort)) and
  (.population_id | test("^terminal-runs-v1-[a-f0-9]{16}$")) and (.manifest_sha256 | sha256) and
  (.terminal_runs | positive_integer) and
  (.targets | type == "array") and (.targets | length) == .terminal_runs and
  all(.targets[]; outcome_measurement_target);

def outcome_measurement_imported_detail:
  type == "object" and
  ((keys | sort) == (["elapsed_ms", "import_id", "input_tokens", "output_tokens", "population_id", "sample_count", "sample_ended_at", "sample_started_at", "selection", "session_fingerprint", "source_adapter", "source_scope", "success", "target_ledger_sha256", "target_outcome_event_sha256", "target_run", "target_terminal", "target_terminal_event_sha256", "tool_calls", "total_tokens", "window_ended_at", "window_started_at"] | sort)) and
  (.population_id | test("^terminal-runs-v1-[a-f0-9]{16}$")) and (.import_id | sha256) and
  (.target_run | test("^[a-z0-9][a-z0-9-]*$")) and (.target_ledger_sha256 | sha256) and
  (.target_terminal | IN("completed", "blocked")) and
  (.target_terminal_event_sha256 | sha256) and
  (.target_outcome_event_sha256 | optional_sha256) and
  (.source_adapter == "codex") and (.source_scope == "primary_session_window") and
  (.selection == "shortest_enclosing_primary_session") and
  (.session_fingerprint | sha256) and
  (.window_started_at | iso_timestamp) and (.window_ended_at | iso_timestamp) and
  (.sample_started_at | iso_timestamp) and (.sample_ended_at | iso_timestamp) and
  (.sample_count | positive_integer) and (.success | boolean) and
  (.input_tokens | nonnegative_integer) and (.output_tokens | nonnegative_integer) and
  (.total_tokens | nonnegative_integer) and (.total_tokens >= (.input_tokens + .output_tokens)) and
  (.tool_calls | nonnegative_integer) and (.elapsed_ms | nonnegative_integer);

def exact_keys($expected):
  (keys | sort) == ($expected | sort);
def program_id: type == "string" and test("^[a-z0-9][a-z0-9-]{1,62}$");
def program_emitter:
  type == "object" and exact_keys(["id", "role"]) and
  (.id | nonempty_string) and .role == "coordinator";
def program_worker:
  type == "object" and exact_keys(["branch", "head", "id", "model_family", "worktree"]) and
  (.id | nonempty_string) and (.model_family | nonempty_string) and
  ((.worktree == null) or (.worktree | nonempty_string)) and (.branch | nonempty_string) and
  (.head | test("^[a-f0-9]{40,64}$"));
def program_artifact:
  type == "object" and exact_keys(["path", "sha256"]) and
  (.path | nonempty_string) and (.sha256 | sha256);
def program_common:
  (.event_id | sha256) and (.program_id | program_id) and
  (.manifest_sha256 | sha256) and (.unit_id | nonempty_string) and
  (.attempt_id | nonempty_string) and (.emitter | program_emitter);
def program_detail($event):
  type == "object" and program_common and
  if $event == "program_initialized" then
    exact_keys(["attempt_id", "emitter", "event_id", "manifest_path", "manifest_sha256", "program_id", "runtime_capability", "unit_id"]) and
    (.manifest_path | nonempty_string) and (.runtime_capability | IN("proxy_supported", "blocked"))
  elif $event == "program_unit_started" then
    exact_keys(["attempt_id", "emitter", "event_id", "files", "manifest_sha256", "program_id", "tools", "unit_id", "worker"]) and
    (.files | string_array) and (.tools | string_array) and (.worker | program_worker)
  elif $event == "program_unit_result" then
    exact_keys(["artifact", "attempt_id", "emitter", "event_id", "head", "manifest_sha256", "program_id", "status", "unit_id", "worker_id"]) and
    (.worker_id | nonempty_string) and (.head | test("^[a-f0-9]{40,64}$")) and
    (.status | IN("passed", "failed")) and (.artifact | program_artifact)
  elif $event == "program_unit_verdict" then
    exact_keys(["attempt_id", "emitter", "event_id", "evidence", "head", "manifest_sha256", "program_id", "unit_id", "verdict", "verifier"]) and
    (.head | test("^[a-f0-9]{40,64}$")) and (.verdict | IN("passed", "failed")) and
    (.evidence | program_artifact) and
    (.verifier | type == "object" and exact_keys(["id", "model_family"]) and (.id | nonempty_string) and (.model_family | nonempty_string))
  elif $event == "program_unit_head_changed" then
    exact_keys(["attempt_id", "emitter", "event_id", "manifest_sha256", "new_head", "previous_head", "program_id", "unit_id", "worker_id"]) and
    (.worker_id | nonempty_string) and (.previous_head | test("^[a-f0-9]{40,64}$")) and (.new_head | test("^[a-f0-9]{40,64}$"))
  elif $event == "program_unit_retry" then
    exact_keys(["attempt_id", "emitter", "event_id", "manifest_sha256", "previous_attempt_id", "program_id", "reason", "unit_id"]) and
    (.previous_attempt_id | nonempty_string) and (.reason | nonempty_string)
  elif $event == "program_unit_reconciled" then
    exact_keys(["attempt_id", "disposition", "emitter", "event_id", "manifest_sha256", "program_id", "reason", "unit_id", "zombie_attempt_id"]) and
    (.zombie_attempt_id | nonempty_string) and (.disposition | IN("ignored", "accepted")) and (.reason | nonempty_string)
  else false end;

def strict_detail($event):
  type == "object" and
  if $event == "route_decided" then
    (.route | nonempty_string) and (.reason | nonempty_string)
    and ((keys - ["route", "reason", "contract_path", "contract_sha256", "provenance"]) | length == 0)
    and ((has("contract_path") | not) or (.contract_path | nonempty_string))
    and ((has("contract_sha256") | not) or (.contract_sha256 | nonempty_string))
    and ((has("provenance") | not) or (.provenance | IN("deployed-pi", "deployed-agents", "repo")))
  elif $event == "plan_created" then
    (.path | nonempty_string) and (.status | IN("DRAFT", "CHALLENGED", "READY"))
  elif $event == "adversary_completed" then
    (.mode | IN("plan", "code_diff")) and (.verdict | nonempty_string) and
    (.accepted_findings | string_array) and (.rejected_findings | string_array) and
    ((has("model_provenance") | not) or (.model_provenance | provenance_complete))
  elif $event == "review_completed" then
    (.status | IN("GO", "GO WITH NOTES", "BLOCK")) and (.evidence | evidence)
  elif $event == "simplification_completed" then
    (.status | nonempty_string) and (.evidence | evidence)
  elif $event == "quality_completed" then
    (.status | IN("pass", "unavailable")) and (.evidence | evidence)
  elif $event == "ship_completed" then
    ((.cumulative_review == "not-reached:6") or ((.cumulative_review | type == "string") and (.cumulative_review | test("^.+\\.\\.\\.HEAD @ .+$")))) and
    ((.thermo_nuclear | IN("clean", "unavailable")) or ((.thermo_nuclear | type == "string") and (.thermo_nuclear | test("^findings:[0-9]+-(folded|open)$"))) or (.thermo_nuclear == "not-reached:5")) and
    ((.pr_body_style | IN("write-direct+unslop", "write-direct", "no-ai-slop-detect", "plain")) or (.pr_body_style == "not-reached:9")) and
    ((.delta_rereview | IN("yes", "no", "n/a")) or (.delta_rereview == "not-reached:11")) and
    ((.deciding_code | IN("complete", "incomplete", "n/a")) or (.deciding_code == "not-reached:6")) and
    (.escaped_defects_recorded | nonnegative_integer) and
    (has("pr_url") and ((.pr_url | nonempty_string) or (.pr_url == null))) and
    (.ci_state | IN("green", "capped", "blocked", "not-run")) and
    (if .ci_state == "green" or .ci_state == "capped" then (.pr_url | type == "string")
     elif .ci_state == "not-run" then (.pr_url == null) else true end)
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
    optional_string_array(.held_in) and optional_string_array(.held_out) and
    ((.supersedes? == null) or (.supersedes | string_array))
  elif $event == "harness_failure_pattern" then
    (.terminal_cause | nonempty_string) and (.causal_status | nonempty_string) and
    (.mechanism | nonempty_string) and (.verifier | nonempty_string) and (.traces | string_array)
  elif $event == "harness_proposal" then
    (.candidate | nonempty_string) and (.editable_surfaces | string_array) and (.preserve | string_array) and
    (.held_in | string_array) and (.held_out | string_array) and
    ((.supersedes? == null) or (.supersedes | string_array))
  elif $event == "harness_validation_completed" then
    (.candidate | nonempty_string) and (.verdict | IN("accepted", "rejected")) and (.reason | nonempty_string) and
    (.checks | string_array) and ((.checks | length) > 0) and (.evidence | string_array) and ((.evidence | length) > 0) and
    (.held_in.baseline | harness_result) and (.held_in.candidate | harness_result) and
    (.held_in.baseline.population == .held_in.candidate.population) and (.held_in.baseline.total == .held_in.candidate.total) and
    (.held_out.baseline | harness_result) and (.held_out.candidate | harness_result) and
    (.held_out.baseline.population == .held_out.candidate.population) and (.held_out.baseline.total == .held_out.candidate.total) and
    ((.safety? == null) or ((.safety.baseline | harness_result) and (.safety.candidate | harness_result) and
      (.safety.baseline.population == .safety.candidate.population) and (.safety.baseline.total == .safety.candidate.total))) and
    ((.objective? == null) or (.objective | harness_objective)) and
    ((.measurement? == null) or ((.measurement.baseline | harness_measurement) and (.measurement.candidate | harness_measurement))) and
    (if .verdict == "accepted" then harness_promotion_policy and (.held_out.candidate.passed >= .held_out.baseline.passed)
    else true end) and
    # Additive provenance fields, shape-checked only when present.
    ((.baseline_fingerprint? == null) or (.baseline_fingerprint | sha256)) and
    ((.candidate_fingerprint? == null) or (.candidate_fingerprint | sha256)) and
    ((.evaluator_manifest_sha256? == null) or (.evaluator_manifest_sha256 | sha256)) and
    ((.evaluator_bundle_sha256? == null) or (.evaluator_bundle_sha256 | sha256)) and
    ((.comparison_path? == null) or (.comparison_path | nonempty_string)) and
    ((.comparison_sha256? == null) or (.comparison_sha256 | sha256)) and
    ((.revision? == null) or (.revision | nonempty_string))
  elif $event == "harness_candidate_rejected" then
    (.candidate | nonempty_string) and (.reason | nonempty_string) and
    (.regressions | string_array) and (.evidence | string_array)
  elif $event == "project_slice_planned" then
    (.slice | nonempty_string) and (.owner | nonempty_string) and (.validation | nonempty_string) and (.dependencies | string_array)
  elif $event == "project_slice_completed" then
    (.slice | nonempty_string) and (.validation | nonempty_string) and (.evidence | string_array) and (.remaining | string_array)
  elif ($event | startswith("program_")) then
    program_detail($event)
  elif $event == "runtime_run_attached" then
    (.adapter == "pi-workflow") and (.run_id | test("^workflow_[A-Za-z0-9_-]+$")) and (.workflow | nonempty_string) and
    (.state_path == (".pi/workflows/" + .run_id)) and
    (.status | IN("running", "blocked", "completed", "failed", "interrupted")) and (.usage_measured | boolean)
  elif $event == "multi_execution_completed" then
    multi_execution_completed_detail
  elif $event == "outcome_measurement_population" then
    outcome_measurement_population_detail
  elif $event == "outcome_measurement_imported" then
    outcome_measurement_imported_detail
  elif $event == "outcome_metric" then
    (.outcome | nonempty_string) and (.success | boolean) and (.measured | boolean) and
    # success_kind is additive: run_terminal (default historical) vs task_grader (final-state grader)
    ((.success_kind? == null) or (.success_kind == "run_terminal") or (.success_kind == "task_grader")) and
    ((.grader_success? == null) or (.grader_success | type) == "boolean") and
    if .measured then
      # Some historical producers marked a quality/grader result as measured
      # without token usage. Keep that evidence readable, but require a complete
      # usage tuple whenever any usage field is supplied; coverage code decides
      # whether the tuple is valid native usage.
      . as $detail |
      if (["input_tokens", "output_tokens", "total_tokens", "tool_calls", "elapsed_ms"] | any(. as $key | $detail | has($key))) then
        (.input_tokens | nonnegative_integer) and (.output_tokens | nonnegative_integer) and
        (.total_tokens | nonnegative_integer) and (.total_tokens >= (.input_tokens + .output_tokens)) and
        (.tool_calls | nonnegative_integer) and (.elapsed_ms | nonnegative_number)
      else true end
    else
      ((.reason // .measurement_reason) | nonempty_string) and
      (.input_tokens? == null) and (.output_tokens? == null) and (.total_tokens? == null) and
      (.tool_calls? == null) and (.elapsed_ms? == null)
    end and
    # Additive optional runtime-outcome fields (X2): type-checked when present,
    # accepted in both measured and unavailable branches, ignored when absent.
    # Producers (tasks-till-done runtime loop) populate these
    # where observed; absence never blocks a valid core outcome_metric.
    ((.runtime? == null) or (.runtime | nonempty_string)) and
    ((.turn_count? == null) or (.turn_count | nonnegative_integer)) and
    ((.auto_continue_count? == null) or (.auto_continue_count | nonnegative_integer)) and
    ((.token_estimate? == null) or (.token_estimate | nonnegative_integer)) and
    ((.wall_clock_ms? == null) or (.wall_clock_ms | nonnegative_number)) and
    # Blueprint M1 additive fields: all-participant breakdown + batch makespan.
    outcome_participant_usage_valid and
    outcome_batch_fields_valid
  elif $event == "runtime_receipt" then
    (.receipt_for | nonempty_string) and
    (.source | nonempty_string) and
    (.kind | IN("file_change","validation","review","archive","completion")) and
    (.subject_sha256 | sha256) and
    ((.exit? == null) or (.exit | nonnegative_integer)) and
    ((.worktree_sha256? == null) or (.worktree_sha256 | sha256)) and
    ((.artifact_sha256? == null) or (.artifact_sha256 | sha256)) and
    (.observed_by == "parent-process") and
    (.cryptographic == false)
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
    ) and ((has("model_provenance") | not) or (.model_provenance | provenance_complete))
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
  elif $event == "review_completed" or $event == "quality_completed" then
    (.status | nonempty_string) and (.evidence | evidence)
  elif $event == "ship_completed" then
    true
  else
    false
  end;

#
# ---------------------------------------------------------------------------
# Batch/ledger mode: the whole-ledger structural check for
# scripts/workflow-event validate. One jq invocation replaces the previous
# per-line spawn loop (~7 jq per line) plus the measurement-uniqueness pass
# plus the profile checks. Input is the RAW ledger text (jq -Rs); output is
# seven plain lines consumed by validate_ledger_file():
#   1 status (OK|ERR)
#   2 error message ("-" when none)
#   3 terminal event ("" when none)
#   4 has_measurement (1|0)
#   5 legacy_post_terminal (count of post-terminal lines)
#   6 event count
#   7 terminal line number (0 when none)
# Per-line check order and message texts match the historic bash loop exactly:
# invalid json, invalid timestamp, timestamp moved backwards, unknown event
# type, unsupported schema_version, event follows terminal, run mismatch,
# invalid detail. Single-detail mode keeps the historic one-detail contract
# used by detail_valid(). The tail dispatch reads mode and every mode argument
# through $ARGS.named with per-mode defaults, so each caller passes only the
# args it needs and the other mode's variables still resolve at compile time:
#   batch  --arg mode batch --arg slug S --arg profile P --argjson allowed A
#   single --arg mode single --arg event E --argjson strict true|false
# ---------------------------------------------------------------------------
def ts_iso: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");

def batch_line($entry; $st; $slug; $list):
  $entry.n as $n
  | $entry.v as $v
  | if ($v | type) == "object" and $v.__parse_error == true
    then {err: "line \($n): invalid json"}
  elif ($v | type) != "object"
    then {err: "line \($n): invalid timestamp"}
  elif (($v.ts // null) | ts_iso) | not
    then {err: "line \($n): invalid timestamp"}
  elif $st.prev != null and $v.ts < $st.prev
    then {err: "line \($n): timestamp moved backwards"}
  else
    (if ($v.event // null) == null then "" else ($v.event | tostring) end) as $event
    | if ($event | IN($list[])) | not
      then {err: "line \($n): unknown event type \($event)"}
    else
      (if ($v.schema_version // null) == null then "legacy" else ($v.schema_version | tostring) end) as $sv
      | if ($sv | IN("legacy", "1", "2")) | not
        then {err: "line \($n): unsupported schema_version \($sv)"}
      elif $st.term_line > 0 and ($sv == "2" or $st.term_sv == "2")
        and (($event == "blocked" and $st.term == "ship_completed") | not)
        then {err: "line \($n): event follows terminal \($st.term) at line \($st.term_line)"}
      elif (if ($v.run // null) == null then "" else ($v.run | tostring) end) != $slug
        then {err: "line \($n): run does not match \($slug)"}
      elif (($v.detail // null) | if $sv == "2" then strict_detail($event) else legacy_detail($event) end) | not
        then {err: "line \($n): invalid detail for \($event)"}
      else
        {ts: $v.ts, event: $event, sv: $sv,
         legacy: ($st.term_line > 0 and ((($event == "blocked" and $st.term == "ship_completed") and ($sv == "2" or $st.term_sv == "2")) | not)),
         terminal: ($event == "completed" or $event == "blocked" or $event == "ship_completed")}
      end
    end
  end;

# Single-sourced success-form predicate over a ship_completed detail
# (null-safe: a missing detail is never success-form). Positive form —
# the success branch negates it, the arrêt branch requires it: an
# exhaustive split with no gap and no overlap.
def ship_success_detail($d):
  ((($d.ci_state // "") == "green")
   and ((($d.pr_url // null) | type) == "string")
   and ((($d.pr_url // "") | length) > 0)
   and ([$d.cumulative_review, $d.thermo_nuclear, $d.pr_body_style, $d.delta_rereview, $d.deciding_code]
        | all(type == "string" and ((startswith("not-reached:") | not))))
   and ((($d.thermo_nuclear // "") | test("-open$")) | not)
   and (($d.deciding_code // "") != "incomplete"));
def ship_profile_error($values; $st; $label; $success):
  ([$values[] | select(.event == "ship_completed")] | last // null) as $ship
  | ([$values | to_entries[] | select(.value.event == "file_changed") | .key] | last // -1) as $lc
  | ([$values | to_entries[] | select(.key > $lc and (.value.event == "validation_run" or .value.event == "validation_failed"))] | group_by(.value.detail.command) | map(last)) as $latest
  | ([$values[] | select(.event == "outcome_metric" and .detail.success == true)] | length) as $ok
  | ([
      (if $success then (if $st.term != "ship_completed" then "profile \($label) requires final ship_completed event" else null end)
       else (if $st.term != "blocked" then "profile \($label) requires final blocked event" else null end) end),
      (if ($ship | not) then "profile \($label) requires ship_completed before terminal" else null end),
      (["file_changed", "validation_run", "outcome_metric"] | map(. as $req
          | if ([$values[] | select(.event == $req)] | length) == 0 and $success
            then "profile \($label) missing \($req)" else null end)),
      (if $success and $ok == 0 then "profile \($label) requires successful outcome_metric" else null end),
      (if $success and (($latest | length) == 0 or (any($latest[]; (.value.event != "validation_run" or .value.detail.exit != 0)))) then "profile \($label) requires validation after last file change with every latest attempt succeeding" else null end),
      (if ($success | not) and ship_success_detail($ship.detail) then "profile \($label) requires non-success-form ship_completed (au moins un marqueur d'arrêt)" else null end),
      (if $success and (ship_success_detail($ship.detail) | not)
        then "profile \($label) requires success-form ship_completed (green, URL, no markers, no open findings)" else null end)
    ] | flatten | map(select(. != null)) | first);

def autonomous_profile_error($values; $st; $label; $strict):
  (["route_decided","plan_created","adversary_completed","file_changed","validation_run","simplification_completed","review_completed","outcome_metric","archive_written","plan_removed"]) as $required
  | ([$values | to_entries[] | select(.value.event == "file_changed") | .key] | last // -1) as $lc
  | ([$values | to_entries[] | select(
      .key > $lc and (.value.event == "validation_run" or .value.event == "validation_failed")
    )]) as $validation_attempts
  | ($validation_attempts | group_by(.value.detail.command) | map(last)) as $latest_validations
  | ([$values | to_entries[] | select(.value.event == "review_completed")] | last // null) as $review
  | ([$values | to_entries[] | select(.value.event == "adversary_completed" and .value.detail.mode == "code_diff")] | last // null) as $code_adversary
  | ([$values | to_entries[] | select(.value.event == "adversary_completed" and .value.detail.mode == "plan")] | last // null) as $plan_adversary
  | ($review.key // -1) as $lr
  | ($code_adversary.key // -1) as $la
  | ([
      (if $st.term != "completed" then "profile \($label) requires final completed event" else null end),
      ($required | map(. as $req
          | if ([$values[] | select(.event == $req)] | length) == 0
            then "profile \($label) missing \($req)" else null end)),
      (["plan", "code_diff"] | map(. as $mode
          | if ([$values[] | select(.event == "adversary_completed" and .detail.mode == $mode)] | length) == 0
            then "profile \($label) missing adversary mode \($mode)" else null end)),
      (if ($validation_attempts | length) == 0
        then "profile \($label) requires validation after last file change" else null end),
      (if ($latest_validations | length) > 0 and (all($latest_validations[]; .value.event == "validation_run" and .value.detail.exit == 0) | not)
        then "profile \($label) requires every latest validation attempt per command to succeed" else null end),
      (if (($review.value.detail.status // "") | IN("GO", "GO WITH NOTES")) | not
        then "profile \($label) requires the latest review_completed verdict to be non-blocking" else null end),
      (if (($plan_adversary.value.detail.verdict // "") | IN("READY", "GO", "GO WITH NOTES")) | not
        then "profile \($label) requires the latest plan adversary verdict to be non-blocking" else null end),
      (if (($code_adversary.value.detail.verdict // "") | IN("GO", "GO WITH NOTES")) | not
        then "profile \($label) requires the latest code_diff adversary verdict to be non-blocking" else null end),
      (if $strict then
        (["validation", "review", "archive", "completion"] | map(. as $kind
            | if ([$values[] | select(.event == "runtime_receipt"
                  and .detail.kind == $kind
                  and .detail.cryptographic == false
                  and .detail.observed_by == "parent-process")] | length) == 0
              then "profile \($label) missing runtime_receipt kind \($kind)" else null end))
        , (if (([$values[] | select(.event == "harness_validation_completed")] | length) > 0)
          and (([$values[] | select(.event == "harness_validation_completed"
                and (.detail.baseline_fingerprint // null) != null
                and (.detail.candidate_fingerprint // null) != null
                and (.detail.evaluator_manifest_sha256 // null) != null
                and (.detail.evaluator_bundle_sha256 // null) != null
                and (.detail.comparison_path // null) != null
                and (.detail.comparison_sha256 // null) != null
                and (.detail.safety // null) != null
                and (.detail.safety.baseline.population // null) == (.detail.safety.candidate.population // null)
                and (.detail.safety.baseline.total // null) == (.detail.safety.candidate.total // null))] | length)
               != ([$values[] | select(.event == "harness_validation_completed")] | length))
          then "profile \($label) requires artifact fingerprints, evaluator provenance, safety and comparison_path/comparison_sha256 on every harness_validation_completed"
          else null end)
        else null end),
      (if $lc >= 0 and $lr <= $lc then "profile \($label) requires non-blocking review after last file change"
       elif $lc >= 0 and $la <= $lc then "profile \($label) requires non-blocking code_diff adversary after last file change"
       else null end)
    ] | flatten | map(select(. != null)) | first) // null;

def batch_ledger($slug; $profile; $list):
  (split("\n") | if length > 0 and .[-1] == "" then .[:-1] else . end) as $lines
  | ([range(0; ($lines | length)) as $i
      | {n: ($i + 1), v: (try ($lines[$i] | fromjson) catch {__parse_error: true})}]) as $entries
  | (reduce $entries[] as $entry (
      {err: null, prev: null, term: "", term_line: 0, term_sv: "", legacy: 0};
      if .err != null then .
      else (batch_line($entry; .; $slug; $list)) as $r
        | if $r.err != null then .err = $r.err
          else
            {err: null,
             prev: $r.ts,
             term: (if $r.terminal then $r.event else .term end),
             term_line: (if $r.terminal then $entry.n else .term_line end),
             term_sv: (if $r.terminal then $r.sv else .term_sv end),
             legacy: (if $r.legacy then .legacy + 1 else .legacy end)}
          end
      end)) as $st
  | ($entries | length) as $count
  | ([$entries[] | .v | select((type == "object") and .__parse_error != true)]) as $values
  | ([$values[] | select(.event == "outcome_measurement_population") | .detail]) as $pops
  | ([$values[] | select(.event == "outcome_measurement_imported") | .detail]) as $imps
  | ((($pops | length) + ($imps | length)) > 0) as $hasm
  | (if ($pops | length) == 0 and ($imps | length) == 0 then null
     elif (all($pops[]; ([.targets[].target_run] | unique | length) == (.targets | length)))
      and (($imps | map(.import_id) | unique | length) == ($imps | length))
      and (all($imps[]; . as $import
          | ([$pops[] | select(.population_id == $import.population_id)] | length) == 1
            and ([$pops[] | select(.population_id == $import.population_id) | .targets[]
                 | select(.target_run == $import.target_run
                     and .target_ledger_sha256 == $import.target_ledger_sha256
                     and .target_terminal == $import.target_terminal
                     and .target_terminal_event_sha256 == $import.target_terminal_event_sha256
                     and .target_outcome_event_sha256 == $import.target_outcome_event_sha256)] | length) == 1))
      and (($imps | group_by(.target_run) | all(.[]; length == 1)))
     then null
     else "measurement imports must be unique members of exactly one matching population"
     end) as $measure_err
  | (if $st.legacy == 0 and $st.term_line > 0 and $st.term_line != $count
     then "terminal event must be last (line \($st.term_line) of \($count))" else null end) as $term_err
  | (if $profile == "structural" then null
     elif $profile == "autonomous-completed" then autonomous_profile_error($values; $st; "autonomous-completed"; false)
     elif $profile == "autonomous-completed-strict" then autonomous_profile_error($values; $st; "autonomous-completed-strict"; true)
     elif $profile == "blocked-terminal"
     then (if $st.term != "blocked" then "profile blocked-terminal requires final blocked event" else null end)
     elif $profile == "ship-completed" then ship_profile_error($values; $st; "ship-completed"; true)
     elif $profile == "ship-stopped" then ship_profile_error($values; $st; "ship-stopped"; false)
     else "unknown validation profile: \($profile)"
     end) as $profile_err
  | ([$st.err, $term_err, $measure_err, $profile_err] | map(select(. != null)) | first) as $err
  | (([$values[] | select(.schema_version == 2 and .event == "route_decided" and .detail.route == "plan-implement")] | length) > 0) as $has_v2
  | "\(if $err == null then "OK" else "ERR" end)\n\($err // "-")\n\($st.term)\n\(if $hasm then 1 else 0 end)\n\($st.legacy)\n\($count)\n\($st.term_line)\n\(if $has_v2 then 1 else 0 end)";

if ($ARGS.named.mode // "single") == "batch" then
  batch_ledger($ARGS.named.slug // ""; $ARGS.named.profile // "structural"; $ARGS.named.allowed // [])
else
  if ($ARGS.named.strict // false) then strict_detail($ARGS.named.event // "") else legacy_detail($ARGS.named.event // "") end
end
