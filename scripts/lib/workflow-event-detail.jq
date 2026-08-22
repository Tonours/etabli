def nonempty_string: type == "string" and length > 0;
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
    (if .verdict == "accepted" then
      (.held_in.candidate.passed > .held_in.baseline.passed) and (.held_out.candidate.passed >= .held_out.baseline.passed)
    else true end) and
    # Additive self-improvement provenance (optional here; enforced by the strict
    # profile and workflow-self-improvement-integrity, never by legacy callers).
    ((.candidate_fingerprint? == null) or (.candidate_fingerprint | sha256)) and
    ((.evaluator_manifest_sha256? == null) or (.evaluator_manifest_sha256 | sha256)) and
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
      (.input_tokens | nonnegative_integer) and (.output_tokens | nonnegative_integer) and
      (.total_tokens | nonnegative_integer) and (.total_tokens >= (.input_tokens + .output_tokens)) and
      (.tool_calls | nonnegative_integer) and (.elapsed_ms | nonnegative_number)
    else
      ((.reason // .measurement_reason) | nonempty_string) and
      (.input_tokens? == null) and (.output_tokens? == null) and (.total_tokens? == null) and
      (.tool_calls? == null) and (.elapsed_ms? == null)
    end and
    # Additive optional runtime-outcome fields (X2): type-checked when present,
    # accepted in both measured and unavailable branches, ignored when absent.
    # Producers (tasks-till-done runtime loop, telemetry-recover) populate these
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
