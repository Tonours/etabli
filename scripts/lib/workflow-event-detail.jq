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
def retired_events: ["dogfood_matrix_created", "dogfood_scenario_run", "dogfood_fix_applied", "dogfood_blocked", "self_improvement_candidate", "harness_failure_pattern", "harness_proposal", "harness_validation_completed", "harness_candidate_rejected", "project_slice_planned", "project_slice_completed", "program_initialized", "program_unit_started", "program_unit_result", "program_unit_verdict", "program_unit_head_changed", "program_unit_retry", "program_unit_reconciled", "runtime_run_attached", "multi_execution_completed", "runtime_receipt", "outcome_measurement_population", "outcome_measurement_imported", "outcome_metric"];

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
  elif $event == "retry_classified" then
    (.classification | nonempty_string) and (.action | nonempty_string) and optional_string(.stage) and optional_string(.provider)
  elif $event == "handoff" then
    (.branch | nonempty_string) and (.sha | nonempty_string) and (.next_action | nonempty_string) and
    (.done | evidence) and (.pending | evidence) and (.do_not_redo | evidence)
  elif $event == "archive_written" then
    (.archive | nonempty_string)
  elif $event == "completed" then
    (.result? | nonempty_string) or (.status? | nonempty_string) or (.goal_complete? | boolean)
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
# per-line spawn loop (~7 jq per line) plus the profile checks. Input is the RAW ledger text (jq -Rs); output is
# seven plain lines consumed by validate_ledger_file():
#   1 status (OK|ERR)
#   2 error message ("-" when none)
#   3 terminal event ("" when none)
#   4 reserved (always 0)
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
    | ($event | IN(retired_events[])) as $retired
    | if (($event | IN($list[])) or $retired) | not
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
      elif (if $retired then ((($v.detail // null) | type) != "object")
            else ((($v.detail // null) | if $sv == "2" then strict_detail($event) else legacy_detail($event) end) | not) end)
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
  | ([
      (if $success then (if $st.term != "ship_completed" then "profile \($label) requires final ship_completed event" else null end)
       else (if $st.term != "blocked" then "profile \($label) requires final blocked event" else null end) end),
      (if ($ship | not) then "profile \($label) requires ship_completed before terminal" else null end),
      (["file_changed", "validation_run"] | map(. as $req
          | if ([$values[] | select(.event == $req)] | length) == 0 and $success
            then "profile \($label) missing \($req)" else null end)),
      (if $success and (($latest | length) == 0 or (any($latest[]; (.value.event != "validation_run" or .value.detail.exit != 0)))) then "profile \($label) requires validation after last file change with every latest attempt succeeding" else null end),
      (if ($success | not) and ship_success_detail($ship.detail) then "profile \($label) requires non-success-form ship_completed (au moins un marqueur d'arrêt)" else null end),
      (if $success and (ship_success_detail($ship.detail) | not)
        then "profile \($label) requires success-form ship_completed (green, URL, no markers, no open findings)" else null end)
    ] | flatten | map(select(. != null)) | first);

def autonomous_profile_error($values; $st; $label):
  (["route_decided","plan_created","adversary_completed","file_changed","validation_run","simplification_completed","review_completed","archive_written","plan_removed"]) as $required
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
  | (if $st.legacy == 0 and $st.term_line > 0 and $st.term_line != $count
     then "terminal event must be last (line \($st.term_line) of \($count))" else null end) as $term_err
  | (if $profile == "structural" then null
     elif $profile == "autonomous-completed" then autonomous_profile_error($values; $st; "autonomous-completed")
     elif $profile == "blocked-terminal"
     then (if $st.term != "blocked" then "profile blocked-terminal requires final blocked event" else null end)
     elif $profile == "ship-completed" then ship_profile_error($values; $st; "ship-completed"; true)
     elif $profile == "ship-stopped" then ship_profile_error($values; $st; "ship-stopped"; false)
     else "unknown validation profile: \($profile)"
     end) as $profile_err
  | ([$st.err, $term_err, $profile_err] | map(select(. != null)) | first) as $err
  | (([$values[] | select(.schema_version == 2 and .event == "route_decided" and .detail.route == "plan-implement")] | length) > 0) as $has_v2
  | "\(if $err == null then "OK" else "ERR" end)\n\($err // "-")\n\($st.term)\n0\n\($st.legacy)\n\($count)\n\($st.term_line)\n\(if $has_v2 then 1 else 0 end)";

if ($ARGS.named.mode // "single") == "batch" then
  batch_ledger($ARGS.named.slug // ""; $ARGS.named.profile // "structural"; $ARGS.named.allowed // [])
else
  if ($ARGS.named.strict // false) then strict_detail($ARGS.named.event // "") else legacy_detail($ARGS.named.event // "") end
end
