# Implemented: M1 runtime producers for participant_usage / batch

## Metadata

- Archived: 2026-07-31
- Source plan: Produire participant_usage/batch depuis runtimes et ledgers
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`

## Outcome

Wired producers for blueprint M1 fields without inventing tokens:

- `scripts/lib/outcome-metric-builder.mjs` — pure aggregation of parent +
  `multi_execution_completed` usage into `participant_usage`, batch window from
  ledger timestamps.
- `scripts/workflow-outcome-metric` — dry-run/apply CLI; apply only on open
  ledgers without an existing measured `outcome_metric`.
- `scripts/lib/outcome-metric-emit.mjs` + Pi adapter — `maybeEmitOutcomeMetric`.
- Pi `workflow-router` accumulates assistant `usage` on `agent_end` and emits at
  most one measured `outcome_metric` on `agent_settled` when an active ledger
  exists.
- Smoke `tests/workflow-outcome-metric-smoke.sh` in full agentic-infra profile.

Claude remains CLI-driven until a native usage hook is proven. Live −50%/×2
still **not verified**.

## Validation Evidence

- `bash tests/workflow-outcome-metric-smoke.sh` → ok
- `bash tests/workflow-event-smoke.sh` → ok
- `bash tests/workflow-metrics-smoke.sh` → ok
- `bash tests/agentic-infra-manifest-smoke.sh` → ok
- `scripts/verify-agentic-infra core` → exit 0
- `git diff --check` → ok

## Follow-up

- Optional Claude PostToolUse/session-end producer when usage is available
- Populate `success_kind: task_grader` only when a final-state grader actually ran
- Live baseline under explicit `LIVE_EVAL_BUDGET_USD`
