#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"
PLAN_DIR="$TMP_DIR/docs/plan"

if grep -Fq 'IGNORECASE' "$ROOT_DIR/scripts/workflow-retrospect"; then
  printf 'workflow-retrospect must use POSIX awk case folding\n' >&2
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

mkdir -p "$EVENT_DIR/bad-run-a" "$EVENT_DIR/bad-run-b" "$EVENT_DIR/bad-run-c" "$EVENT_DIR/good-run-a" "$EVENT_DIR/good-run-b" "$PLAN_DIR"
mkdir -p "$EVENT_DIR/repeated-initiative" "$EVENT_DIR/repeated-initiative-v2"

cat >"$EVENT_DIR/bad-run-a/events.jsonl" <<'JSONL'
{"ts":"2026-07-06T10:00:00Z","event":"route_decided","run":"bad-run-a","detail":{"route":"plan-implement","reason":"router miss: read-only adversary prompt incorrectly routed to plan-implement"}}
{"ts":"2026-07-06T10:00:30Z","event":"harness_failure_pattern","run":"bad-run-a","detail":{"terminal_cause":"router miss: harness failure pattern shadowed self-improvement route","causal_status":"confirmed","mechanism":"generic review pattern won before self-improvement routing","verifier":"router eval"}}
{"ts":"2026-07-06T10:00:45Z","event":"harness_failure_pattern","run":"bad-run-a","detail":{"terminal_cause":"oversight moved inside mutation loop","causal_status":"confirmed","mechanism":"proposal validation delegated to evolving harness","verifier":"plan review"}}
{"ts":"2026-07-06T10:01:00Z","event":"adversary_completed","run":"bad-run-a","detail":{"verdict":"BLOCK","accepted_findings":["runtime capability overclaim: claimed subagents were available without checking runtime","missing archive cleanup before completion"],"rejected_findings":[]}}
{"ts":"2026-07-06T10:02:00Z","event":"validation_failed","run":"bad-run-a","detail":{"command":"bash tests/workflow-docs-smoke.sh","exit":1,"failure":"plan drift: archived plan omitted validation evidence"}}
{"ts":"2026-07-06T10:03:00Z","event":"validation_failed","run":"bad-run-a","detail":{"command":"bash tests/workflow-docs-smoke.sh","exit":1,"failure":"smoke pin missing remediation message"}}
{"ts":"2026-07-06T10:04:00Z","event":"outcome_metric","run":"bad-run-a","detail":{"outcome":"blocked","success":false,"measured":true,"input_tokens":10,"output_tokens":5,"total_tokens":15,"tool_calls":1,"elapsed_ms":100}}
{"ts":"2026-07-06T10:05:00Z","event":"blocked","run":"bad-run-a","detail":{"reason":"smoke fixture terminal","needed_input":"none"}}
JSONL

cat >"$EVENT_DIR/bad-run-b/events.jsonl" <<'JSONL'
{"ts":"2026-07-06T11:00:00Z","event":"route_decided","run":"bad-run-b","detail":{"route":"review","reason":"router miss: read-only adversary prompt incorrectly routed to plan-implement"}}
{"ts":"2026-07-06T11:00:30Z","event":"harness_failure_pattern","run":"bad-run-b","detail":{"terminal_cause":"router miss: harness failure pattern shadowed self-improvement route","causal_status":"confirmed","mechanism":"generic review pattern won before self-improvement routing","verifier":"router eval"}}
{"ts":"2026-07-06T11:00:45Z","event":"harness_failure_pattern","run":"bad-run-b","detail":{"terminal_cause":"oversight moved inside mutation loop","causal_status":"confirmed","mechanism":"proposal validation delegated to evolving harness","verifier":"plan review"}}
{"ts":"2026-07-06T11:01:00Z","event":"validation_failed","run":"bad-run-b","detail":{"command":"bash tests/workflow-docs-smoke.sh","exit":1,"failure":"plan drift: archived plan omitted validation evidence"}}
{"ts":"2026-07-06T11:02:00Z","event":"dogfood_blocked","run":"bad-run-b","detail":{"scenario":"browser-checkout","reason":"dogfood blocker: no observable UI evidence","needed_input":"browser trace"}}
{"ts":"2026-07-06T11:03:00Z","event":"validation_failed","run":"bad-run-b","detail":{"command":"bash tests/workflow-docs-smoke.sh","exit":1,"failure":"smoke pin missing remediation message"}}
JSONL

cat >"$EVENT_DIR/bad-run-c/events.jsonl" <<'JSONL'
{"ts":"2026-07-06T12:00:00Z","event":"adversary_completed","run":"bad-run-c","detail":{"verdict":"BLOCK","accepted_findings":["runtime capability overclaim: claimed subagents were available without checking runtime","missing archive cleanup before completion"],"rejected_findings":[]}}
{"ts":"2026-07-06T12:01:00Z","event":"dogfood_blocked","run":"bad-run-c","detail":{"scenario":"browser-checkout","reason":"dogfood blocker: no observable UI evidence","needed_input":"browser trace"}}
{"ts":"2026-07-06T12:02:00Z","event":"validation_failed","run":"bad-run-c","detail":{"command":"bash tests/one-off.sh","exit":1,"failure":"one-off lint failure in temporary fixture"}}
JSONL

cat >"$EVENT_DIR/good-run-a/events.jsonl" <<'JSONL'
{"ts":"2026-07-06T13:00:00Z","event":"route_decided","run":"good-run-a","detail":{"route":"plan-implement","reason":"normal implementation request"}}
{"ts":"2026-07-06T13:01:00Z","event":"outcome_metric","run":"good-run-a","detail":{"outcome":"success","success":true,"measured":true,"input_tokens":20,"output_tokens":8,"total_tokens":28,"tool_calls":2,"elapsed_ms":200}}
{"ts":"2026-07-06T13:02:00Z","event":"completed","run":"good-run-a","detail":{"summary":"done"}}
JSONL

cat >"$EVENT_DIR/good-run-b/events.jsonl" <<'JSONL'
{"ts":"2026-07-06T14:00:00Z","event":"route_decided","run":"good-run-b","detail":{"route":"plan-implement","reason":"normal implementation request"}}
{"ts":"2026-07-06T14:01:00Z","event":"outcome_metric","run":"good-run-b","detail":{"outcome":"success","success":true,"measured":false,"reason":"fixture: no usage source"}}
{"ts":"2026-07-06T14:02:00Z","event":"completed","run":"good-run-b","detail":{"summary":"done"}}
JSONL

cat >"$EVENT_DIR/repeated-initiative/events.jsonl" <<'JSONL'
{"ts":"2026-07-06T15:00:00Z","event":"route_decided","run":"repeated-initiative","detail":{"route":"review","reason":"router miss: versioned retry duplicated one initiative"}}
JSONL

cat >"$EVENT_DIR/repeated-initiative-v2/events.jsonl" <<'JSONL'
{"ts":"2026-07-06T15:10:00Z","event":"route_decided","run":"repeated-initiative-v2","detail":{"route":"review","reason":"router miss: versioned retry duplicated one initiative"}}
JSONL

cat >"$PLAN_DIR/20260706-bad-run-retro.md" <<'MD'
# Bad Run Archive

- Plan drift: archived plan omitted validation evidence.
- Router miss: read-only adversary prompt incorrectly routed to plan-implement.
- Runtime capability overclaim: claimed subagents were available without checking runtime.
- Dogfood blocker: no observable UI evidence.
- Router miss: versioned retry duplicated one initiative.
MD

before_status="$(git -C "$ROOT_DIR" status --porcelain)"
json_output="$("$ROOT_DIR/scripts/workflow-retrospect" --dir "$EVENT_DIR" --plans "$PLAN_DIR" --min-count 2 --json)"
text_output="$("$ROOT_DIR/scripts/workflow-retrospect" --dir "$EVENT_DIR" --plans "$PLAN_DIR" --min-count 2)"
after_status="$(git -C "$ROOT_DIR" status --porcelain)"

if [ "$before_status" != "$after_status" ]; then
  printf 'workflow-retrospect mutated git status\n' >&2
  exit 1
fi

printf '%s\n' "$json_output" | jq -e '.confirmed_issue_count >= 6' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "router_miss" and .confirmed == true and .action_kind == "router_fixture")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "harness_failure_pattern" and .confirmed == true and (.key | contains("harness failure pattern shadowed")))' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "harness_failure_pattern" and .confirmed == true and .action_kind == "contract_patch" and (.key | contains("oversight moved inside mutation loop")))' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "plan_drift" and .confirmed == true and .action_kind == "contract_patch")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "runtime_capability_overclaim" and .confirmed == true and .action_kind == "contract_patch")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "dogfood_blocker" and .confirmed == true and .action_kind == "recommendation")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "validation_failure" and .confirmed == true and .action_kind == "mechanical_check")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "adversary_finding" and .confirmed == true and (.samples[0].text | contains("missing archive cleanup")))' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "runtime_capability_overclaim") | .count == 2 and .evidence_count == 3 and (.samples | any(.origin == "archive"))' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "router_miss" and (.key | contains("versioned retry duplicated"))) | .count == 1 and .evidence_count == 3 and .confirmed == false and .initiatives == ["repeated-initiative"] and (.samples | any(.origin == "archive"))' >/dev/null
printf '%s\n' "$json_output" | jq -e '.issues[] | select(.confirmed == false and .category == "validation_failure")' >/dev/null
if printf '%s\n' "$json_output" | jq -e '.issues[] | select(.category == "observed_route")' >/dev/null; then
  printf 'normal route_decided events should not become retrospect issues\n%s\n' "$json_output" >&2
  exit 1
fi

assert_contains "$text_output" "confirmed recurring workflow issues"
assert_contains "$text_output" "router_fixture"
assert_contains "$text_output" "contract_patch"
assert_contains "$text_output" "mechanical_check"
assert_contains "$text_output" "recommendation"

printf '%s\n' "$json_output" | jq -e '.context_budget and .telemetry and .terminal' >/dev/null ||
  { printf 'json output missing context_budget/telemetry/terminal\n' >&2; exit 1; }
printf '%s\n' "$json_output" | jq -e '.context_budget | type == "object" and (.surfaces | length >= 1)' >/dev/null ||
  { printf 'context_budget is not the gate report\n' >&2; exit 1; }
# Fixture ledgers: 2 measured + 1 unmeasured outcome_metric; 2 completed, 1 blocked, 4 in-progress.
printf '%s\n' "$json_output" | jq -e '.telemetry.measured == 2 and .telemetry.unmeasured == 1' >/dev/null ||
  { printf 'telemetry counts do not match fixture ledgers\n%s\n' "$json_output" >&2; exit 1; }
printf '%s\n' "$json_output" | jq -e '.terminal.completed == 2 and .terminal.blocked == 1 and .terminal.in_progress == 4' >/dev/null ||
  { printf 'terminal counts do not match fixture ledgers\n%s\n' "$json_output" >&2; exit 1; }
assert_contains "$text_output" "context budget:"
assert_contains "$text_output" "telemetry: measured=2 unmeasured=1"
assert_contains "$text_output" "terminal: completed=2 blocked=1 in_progress=4"

unavail_json="$(WORKFLOW_CONTEXT_BUDGET_BIN=/nonexistent "$ROOT_DIR/scripts/workflow-retrospect" --dir "$EVENT_DIR" --plans "$PLAN_DIR" --min-count 2 --json)"
unavail_text="$(WORKFLOW_CONTEXT_BUDGET_BIN=/nonexistent "$ROOT_DIR/scripts/workflow-retrospect" --dir "$EVENT_DIR" --plans "$PLAN_DIR" --min-count 2)"
printf '%s\n' "$unavail_json" | jq -e '.context_budget == "unavailable"' >/dev/null ||
  { printf 'missing budget binary must report context_budget unavailable\n%s\n' "$unavail_json" >&2; exit 1; }
assert_contains "$unavail_text" "context budget: unavailable"

empty_output="$("$ROOT_DIR/scripts/workflow-retrospect" --dir "$TMP_DIR/no-workflows" --plans "$TMP_DIR/no-plans")"
case "$empty_output" in
  *"no confirmed recurring workflow issues"*) ;;
  *)
    printf 'expected empty output to be explicit\n%s\n' "$empty_output" >&2
    exit 1
    ;;
esac

printf 'workflow retrospect smoke test: ok\n'
