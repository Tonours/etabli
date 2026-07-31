#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
EVENT="$ROOT_DIR/scripts/workflow-event"
CHECK="$ROOT_DIR/scripts/workflow-loop-adherence"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DIR="$TMP/.workflow"

fail() {
  printf 'workflow-loop-adherence smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$CHECK" ] || chmod +x "$CHECK"

# Good autonomous ledger
"$EVENT" --dir "$DIR" append good-auto route_decided '{"route":"plan-implement","reason":"smoke"}'
"$EVENT" --dir "$DIR" append good-auto plan_created '{"path":"PLAN.md","status":"READY"}'
"$EVENT" --dir "$DIR" append good-auto adversary_completed '{"mode":"plan","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append good-auto file_changed '{"path":"scripts/x","change":"added"}'
"$EVENT" --dir "$DIR" append good-auto validation_run '{"command":"true","exit":0}'
"$EVENT" --dir "$DIR" append good-auto simplification_completed '{"status":"ok","evidence":"none"}'
"$EVENT" --dir "$DIR" append good-auto review_completed '{"status":"pass","evidence":"fresh-context GO"}'
"$EVENT" --dir "$DIR" append good-auto adversary_completed '{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append good-auto outcome_metric '{"outcome":"success","success":true,"measured":false,"reason":"offline","success_kind":"task_grader","grader_success":true}'
"$EVENT" --dir "$DIR" append good-auto archive_written '{"path":"docs/plan/example.md"}'
"$EVENT" --dir "$DIR" append good-auto plan_removed '{"path":"PLAN.md"}'
"$EVENT" --dir "$DIR" append good-auto completed '{"summary":"ok"}'
"$CHECK" --dir "$DIR" --profile autonomous --json good-auto | jq -e '.ok == true and .adherence == 1' >/dev/null

# False completed: completed without archive/plan_removed
"$EVENT" --dir "$DIR" append false-done route_decided '{"route":"plan-implement","reason":"smoke"}'
"$EVENT" --dir "$DIR" append false-done plan_created '{"path":"PLAN.md","status":"READY"}'
"$EVENT" --dir "$DIR" append false-done adversary_completed '{"mode":"plan","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append false-done file_changed '{"path":"scripts/x","change":"added"}'
"$EVENT" --dir "$DIR" append false-done validation_run '{"command":"true","exit":0}'
"$EVENT" --dir "$DIR" append false-done review_completed '{"status":"pass","evidence":"x"}'
"$EVENT" --dir "$DIR" append false-done adversary_completed '{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append false-done outcome_metric '{"outcome":"success","success":true,"measured":false,"reason":"offline"}'
"$EVENT" --dir "$DIR" append false-done completed '{"summary":"too early"}'
set +e
"$CHECK" --dir "$DIR" --profile autonomous --json false-done >"$TMP/loop-false.json" 2>"$TMP/loop-false.err"
status=$?
set -e
[ "$status" -ne 0 ] || fail "false completed should fail"
jq -e '.ok == false and (.false_completed == true or (.missing|length) > 0)' "$TMP/loop-false.json" >/dev/null ||
  fail "expected false_completed or missing transitions"

# Read-only profile rejects file_changed
"$EVENT" --dir "$DIR" append ro-bad route_decided '{"route":"review","reason":"smoke"}'
"$EVENT" --dir "$DIR" append ro-bad file_changed '{"path":"x","change":"nope"}'
"$EVENT" --dir "$DIR" append ro-bad review_completed '{"status":"pass","evidence":"x"}'
"$EVENT" --dir "$DIR" append ro-bad completed '{"summary":"done"}'
set +e
"$CHECK" --dir "$DIR" --profile read_only --json ro-bad >"$TMP/loop-ro.json" 2>"$TMP/loop-ro.err"
status=$?
set -e
[ "$status" -ne 0 ] || fail "read_only with file_changed should fail"
jq -e '.ok == false' "$TMP/loop-ro.json" >/dev/null || fail "read_only bad ledger should not be ok"

# Chaos: DRAFT plan must fail READY gate
"$EVENT" --dir "$DIR" append draft-bad route_decided '{"route":"plan-implement","reason":"smoke"}'
"$EVENT" --dir "$DIR" append draft-bad plan_created '{"path":"PLAN.md","status":"DRAFT"}'
"$EVENT" --dir "$DIR" append draft-bad adversary_completed '{"mode":"plan","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append draft-bad file_changed '{"path":"x","change":"y"}'
"$EVENT" --dir "$DIR" append draft-bad validation_run '{"command":"true","exit":0}'
"$EVENT" --dir "$DIR" append draft-bad simplification_completed '{"status":"ok","evidence":"n"}'
"$EVENT" --dir "$DIR" append draft-bad review_completed '{"status":"pass","evidence":"x"}'
"$EVENT" --dir "$DIR" append draft-bad adversary_completed '{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append draft-bad outcome_metric '{"outcome":"success","success":true,"measured":false,"reason":"offline","success_kind":"task_grader","grader_success":true}'
"$EVENT" --dir "$DIR" append draft-bad archive_written '{"path":"docs/plan/x.md"}'
"$EVENT" --dir "$DIR" append draft-bad plan_removed '{"path":"PLAN.md"}'
"$EVENT" --dir "$DIR" append draft-bad completed '{"summary":"no"}'
set +e
"$CHECK" --dir "$DIR" --profile autonomous --json draft-bad >"$TMP/loop-draft.json" 2>"$TMP/loop-draft.err"
st=$?
set -e
[ "$st" -ne 0 ] || fail "DRAFT plan should fail adherence"
jq -e '.ok == false' "$TMP/loop-draft.json" >/dev/null || fail "draft json ok"

# Chaos: adversary BLOCK must fail
"$EVENT" --dir "$DIR" append block-adv route_decided '{"route":"plan-implement","reason":"smoke"}'
"$EVENT" --dir "$DIR" append block-adv plan_created '{"path":"PLAN.md","status":"READY"}'
"$EVENT" --dir "$DIR" append block-adv adversary_completed '{"mode":"plan","verdict":"BLOCK","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append block-adv file_changed '{"path":"x","change":"y"}'
"$EVENT" --dir "$DIR" append block-adv validation_run '{"command":"true","exit":0}'
"$EVENT" --dir "$DIR" append block-adv simplification_completed '{"status":"ok","evidence":"n"}'
"$EVENT" --dir "$DIR" append block-adv review_completed '{"status":"pass","evidence":"x"}'
"$EVENT" --dir "$DIR" append block-adv adversary_completed '{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append block-adv outcome_metric '{"outcome":"success","success":true,"measured":false,"reason":"offline","success_kind":"task_grader","grader_success":true}'
"$EVENT" --dir "$DIR" append block-adv archive_written '{"path":"docs/plan/x.md"}'
"$EVENT" --dir "$DIR" append block-adv plan_removed '{"path":"PLAN.md"}'
"$EVENT" --dir "$DIR" append block-adv completed '{"summary":"no"}'
set +e
"$CHECK" --dir "$DIR" --profile autonomous --json block-adv >"$TMP/loop-block.json" 2>"$TMP/loop-block.err"
st=$?
set -e
[ "$st" -ne 0 ] || fail "BLOCK adversary should fail adherence"

# Chaos: inverted order route after plan
"$EVENT" --dir "$DIR" append bad-order plan_created '{"path":"PLAN.md","status":"READY"}'
"$EVENT" --dir "$DIR" append bad-order route_decided '{"route":"plan-implement","reason":"smoke"}'
"$EVENT" --dir "$DIR" append bad-order adversary_completed '{"mode":"plan","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append bad-order file_changed '{"path":"x","change":"y"}'
"$EVENT" --dir "$DIR" append bad-order validation_run '{"command":"true","exit":0}'
"$EVENT" --dir "$DIR" append bad-order simplification_completed '{"status":"ok","evidence":"n"}'
"$EVENT" --dir "$DIR" append bad-order review_completed '{"status":"pass","evidence":"x"}'
"$EVENT" --dir "$DIR" append bad-order adversary_completed '{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append bad-order outcome_metric '{"outcome":"success","success":true,"measured":false,"reason":"offline","success_kind":"task_grader","grader_success":true}'
"$EVENT" --dir "$DIR" append bad-order archive_written '{"path":"docs/plan/x.md"}'
"$EVENT" --dir "$DIR" append bad-order plan_removed '{"path":"PLAN.md"}'
"$EVENT" --dir "$DIR" append bad-order completed '{"summary":"no"}'
set +e
"$CHECK" --dir "$DIR" --profile autonomous --json bad-order >"$TMP/loop-order.json" 2>"$TMP/loop-order.err"
st=$?
set -e
[ "$st" -ne 0 ] || fail "inverted order should fail"
jq -e '.order_ok == false' "$TMP/loop-order.json" >/dev/null || fail "order_ok should be false"

printf 'workflow-loop-adherence smoke test: ok\n'
