# Implemented: Offline blueprint harness optimizations (M1/L1/T1/G1)

## Metadata

- Archived: 2026-07-31
- Source plan: Implémenter le maximum offline du blueprint d’optimisation harness
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`

## Outcome

Shipped offline harness instrumentation and mechanical helpers from
`docs/harness-optimization-blueprint.md` without live spend:

- **M1:** `outcome_metric` accepts optional `participant_usage` + batch makespan
  fields; `workflow-metrics` reports participant breakdown counts, batch
  makespan (including failed measured outcomes), and
  `verified_throughput_per_hour`.
- **L1:** `scripts/workflow-loop-adherence` enforces READY plan, non-blocking
  adversary verdicts, ordered autonomous transitions, false-completed detection.
- **T1:** `workflow/route-context-manifests.json` +
  `scripts/route-context-manifest-check` covering all 17 router routes.
- **G1:** `scripts/workflow-execution-graph` derived sequential event view with
  honest non-claims (not a semantic DAG / OS single-writer proof).

Smokes wired into full agentic-infra profile. Blueprint backlog rows updated.
Live −50% / +100% claims remain **not verified**.

## Decisions

### Optional schema only

- Choice: additive optional fields on `outcome_metric`
- Rejected: requiring participant breakdown on all historical ledgers
- Rationale: preserve legacy validate/metrics paths

### Throughput denominator includes failures

- Choice: sum `batch_wall_clock_ms` over all measured outcomes that carry it
- Rejected: success-only makespan (Goodhart)
- Rationale: blueprint §10.2

### L1 aligned toward autonomous-completed

- Choice: require file_changed, simplification, READY, task_grader outcome
- Rejected: no-op path without file_changed
- Rationale: reduce dual-definition of “autonomous completed”

## Validation Evidence

- `bash tests/workflow-event-smoke.sh` → ok
- `bash tests/workflow-metrics-smoke.sh` → ok
- `bash tests/workflow-loop-adherence-smoke.sh` → ok
- `bash tests/route-context-manifest-smoke.sh` → ok
- `bash tests/workflow-execution-graph-smoke.sh` → ok
- `bash tests/agentic-infra-manifest-smoke.sh` → ok
- `scripts/verify-agentic-infra core` → exit 0 (224 pi tests, router 53/53)
- `git diff --check` → ok
- Fresh-context review: GO WITH NOTES (accepted fixes folded)
- Adversary code_diff: GO WITH NOTES

## Follow-up State

- Remaining: runtime producers for participant_usage/batch fields; T1 loader
  wiring into router injection; T2/T3 tool output caps; H1 UCR annotation
  corpus; live A/B under `LIVE_EVAL_BUDGET_USD`
- Ledger: `.workflow/blueprint-offline-impl/events.jsonl`
- Next: populate M1 fields from Pi/Claude runtimes when token totals available
