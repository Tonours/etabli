# Implemented: Transcript-Driven Workflow Feedback Loops

## Metadata
- Archived: 2026-07-05
- Source plan: Transcript-driven workflow feedback loops and metrics
- Status: IMPLEMENTED
- Commit / branch: `main` at `a8de09d`; changes are uncommitted

## Outcome
- Added read-only workflow ledger helpers:
  - `scripts/workflow-monitor` reports active, stale, blocked, and failing runs.
  - `scripts/workflow-metrics` aggregates optional `outcome_metric` events and computes tokens per successful outcome.
  - `scripts/workflow-dossier` emits sanitized replay/debug context for one run.
- Added router evaluation support:
  - `scripts/router-eval` and `scripts/router-eval.mjs`.
  - `tests/router-evals/core.json` with route, write-permission, ops-stop, research, and alignment scenarios.
- Added source-backed research and lean-ctx guardrails:
  - `scripts/research-proof-check` rejects research artifacts without evidence and status/confidence labels.
  - `scripts/lean-ctx-check` verifies lean-ctx availability/fallback documentation without installing anything.
- Renamed the misleading workflow efficiency concept from documented source surfaces as conflicts to explicit `documented_source_surfaces`, while keeping `source_of_truth_conflicts` as a zero-valued compatibility field.
- Wired the new helpers into smoke tests, docs, and CI.

## Context
- `/tmp/tonours-brain.HR6nad/docs/aie-202606-transcripts/README.md`: transcript synthesis listed monitoring loops, router golden evals, and tokens-per-outcome metrics as non-implemented reserves.
- `workflow/spec.md`: event ledgers are the durable source for autonomous route status.
- `workflow/events.md`: event details are schema-by-convention, so new metric fields must remain optional.
- `lean-ctx` was unavailable in this runtime, and native shell/search fallback was used.

## Decisions
### Keep Workflow Helpers Read-Only
- Context: Monitoring could evolve into external PR/comment/Slack automation.
- Choice: Implement only local read-only scripts.
- Rejected options: automatic external write-back.
- Rationale: External writes need explicit human checkpoints under the Etabli workflow.
- Consequences: Operators get evidence and summaries, but publishing remains manual.

### Add Router Eval In Bun-Backed Path
- Context: The eval imports the Pi TypeScript router and Claude router implementation.
- Choice: Run `router-eval-smoke` where Bun is available.
- Rejected options: adding router eval to shell-only CI steps.
- Rationale: Running before Bun setup would create a false CI failure.
- Consequences: Router eval is covered in the Pi TypeScript CI job.

### Keep Event Metric Fields Optional
- Context: Existing `.workflow/**/events.jsonl` ledgers predate `outcome_metric`.
- Choice: Treat missing metric fields as unavailable or zero, not as malformed data.
- Rejected options: mandatory schema migration for old ledgers.
- Rationale: Old ledgers should remain valid evidence.
- Consequences: Metrics are useful for new runs and safe for historical runs.

## Accepted Drift
- Original plan/spec: Add helper scripts plus smoke and CI coverage.
- Implemented reality: Completed as planned.
- Why accepted: No substantive drift.

## Validation Evidence
- `bash tests/workflow-monitor-smoke.sh`
  - result: passed
- `bash tests/workflow-metrics-smoke.sh`
  - result: passed
- `bash tests/workflow-dossier-smoke.sh`
  - result: passed
- `bash tests/router-eval-smoke.sh`
  - result: passed
- `bash tests/research-proof-check-smoke.sh`
  - result: passed
- `bash tests/lean-ctx-check-smoke.sh`
  - result: passed
- `bash tests/workflow-event-smoke.sh`
  - result: passed
- `bash tests/workflow-efficiency-report-smoke.sh`
  - result: passed
- `bash tests/workflow-docs-smoke.sh`
  - result: passed
- `bash tests/workflow-contract-coverage-smoke.sh`
  - result: passed
- `bash tests/claude-hooks-smoke.sh`
  - result: passed
- `bash tests/agent-scenarios-smoke.sh`
  - result: passed
- `bun test pi/extensions/__tests__/`
  - result: passed, 186 tests
- `bash -n` on changed shell scripts and smoke tests
  - result: passed
- `git diff --check`
  - result: passed

## Follow-up State
- Remaining risks: The new helpers depend on `jq`; this matches existing shell tooling patterns but should remain explicit in error messages.
- Parking lot: Scheduling workflow monitoring or posting external reports remains out of scope.
- Superseded docs/specs: none.
- Next links:
  - `workflow/events.md`
  - `workflow/spec.md`
  - `.github/workflows/agentic-infra.yml`
