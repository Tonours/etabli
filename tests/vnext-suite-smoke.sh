#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SUITE="$ROOT_DIR/scripts/vnext-suite"
POP="$ROOT_DIR/workflow/vnext/population.json"
TASKS="$ROOT_DIR/workflow/vnext/tasks.json"

fail() {
  printf 'vnext suite smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$SUITE" ] || fail "scripts/vnext-suite is not executable"
[ -f "$POP" ] || fail "missing population.json"
[ -f "$TASKS" ] || fail "missing tasks.json"

# Inventory predicates via real entry point
inv="$("$SUITE" --json --inventory)"
printf '%s\n' "$inv" | jq -e '.ok == true' >/dev/null || fail "inventory not ok: $inv"
printf '%s\n' "$inv" | jq -e '.task_count >= 24' >/dev/null || fail "need >=24 tasks"
printf '%s\n' "$inv" | jq -e '.sealed_held_out_fraction >= 0.25' >/dev/null || fail "held-out sealed fraction < 25%"
printf '%s\n' "$inv" | jq -e '(.missing_categories | length) == 0' >/dev/null || fail "missing categories"
printf '%s\n' "$inv" | jq -e \
  '.tasks_sha256 == "4ae440269c06b17afb2289ecad9713e696d7ba0a55495b74ef31175f59c82526"' \
  >/dev/null || fail "task corpus hash drifted"

# Full suite must be green; graders are source of truth
run1="$("$SUITE" --json --strategy baseline)"
printf '%s\n' "$run1" | jq -e '.ok == true' >/dev/null || {
  printf '%s\n' "$run1" | jq -r '.trials[] | select((.meta_expectation_met // .success) | not) | .task_id + " " + .verifier_result.detail' >&2
  fail "suite run failed"
}
printf '%s\n' "$run1" | jq -e '.metrics.suite_failed == 0' >/dev/null || fail "suite_failed != 0"

# Trial linkage required fields on every trial
printf '%s\n' "$run1" | jq -e '
  all(.trials[];
    has("task_id") and has("verifier_result") and has("success") and
    has("tokens") and has("tool_calls") and has("duration_ms") and
    has("strategy") and has("model_provenance") and has("artefacts")
  )
' >/dev/null || fail "trial missing required linkage fields"

# Never count driver_finished alone: meta task must have success=false and meta_expectation_met=true
printf '%s\n' "$run1" | jq -e '
  .trials[]
  | select(.task_id == "meta-run-finished-not-success")
  | .success == false
    and .verifier_result.driver_finished == true
    and .meta_expectation_met == true
' >/dev/null || fail "meta run-finished-not-success invariant broken"

# Security matrix: benign utility and ASR reported separately (not conflated)
printf '%s\n' "$run1" | jq -e '
  .metrics.security.benign_utility != null and
  .metrics.security.attack_success_rate != null and
  (.metrics.security.attack_counts.total | type) == "number"
' >/dev/null || fail "security matrix metrics missing"

# Efficiency reports per verified success (null tokens ok offline)
printf '%s\n' "$run1" | jq -e '
  .metrics.efficiency.verified_successes >= 1 and
  .metrics.efficiency.tool_calls_per_verified_success != null
' >/dev/null || fail "efficiency metrics missing"

# Second run stability for deterministic suite
run2="$("$SUITE" --json --strategy baseline)"
printf '%s\n' "$run2" | jq -e '.ok == true' >/dev/null || fail "second suite run failed"
c1="$(printf '%s\n' "$run1" | jq -r '.metrics.suite_passed')"
c2="$(printf '%s\n' "$run2" | jq -r '.metrics.suite_passed')"
[ "$c1" = "$c2" ] || fail "non-deterministic pass counts $c1 vs $c2"

# Live gate: without positive LIVE_EVAL_BUDGET_USD must report blocked, never greenwash
live_status="$(env -u LIVE_EVAL_BUDGET_USD "$SUITE" --json --live-status)"
printf '%s\n' "$live_status" | jq -e '
  .can_run_live == false and
  (.status | test("blocked")) and
  (.needed_input | test("LIVE_EVAL_BUDGET_USD"))
' >/dev/null || fail "live-status must block when budget unset: $live_status"

zero_status="$(LIVE_EVAL_BUDGET_USD=0 "$SUITE" --json --live-status)"
printf '%s\n' "$zero_status" | jq -e '.can_run_live == false' >/dev/null ||
  fail "LIVE_EVAL_BUDGET_USD=0 must not enable live"

pos_status="$(LIVE_EVAL_BUDGET_USD=5 "$SUITE" --json --live-status)"
printf '%s\n' "$pos_status" | jq -e '.can_run_live == true and .budget_usd == 5' >/dev/null ||
  fail "positive budget should set can_run_live: $pos_status"

# Durable inspectable results directory (if present) must not claim live success
results_dir="$ROOT_DIR/workflow/vnext/results"
if [ -f "$results_dir/live-blocked.json" ]; then
  jq -e '
    (.status | test("blocked")) and
    ((.needed_input // "") | test("LIVE_EVAL_BUDGET_USD")) and
    (.can_run_live == false)
  ' "$results_dir/live-blocked.json" >/dev/null ||
    fail "results/live-blocked.json must stay an honest mechanical live block"
fi
if [ -f "$results_dir/goal-completion.json" ]; then
  jq -e '
    .status == "done" and
    .live_effectiveness.verified == false and
    .live_effectiveness.claimed == false
  ' "$results_dir/goal-completion.json" >/dev/null ||
    fail "goal-completion.json must not claim live effectiveness verified"
fi

printf 'vnext suite smoke test: ok\n'
