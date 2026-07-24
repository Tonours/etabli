# Implemented: bounded project autonomy with proposal-only self-improvement

## Metadata
- Archived: 2026-07-24
- Source plan: Bounded project autonomy and evidence-first self-improvement
- Status: IMPLEMENTED
- Commit / branch: not created; unrelated pre-existing worktree changes were preserved

## Outcome

An explicitly authorized local run can now declare a versioned, bounded
envelope and obtain one read-only next-evidence decision from its typed v2
ledger. Completion requires the named final-state outcome after the named
evaluation runner; completion text from a driver alone is insufficient.

The controller never launches work, runs an envelope-declared verifier, edits
files, applies a proposal, or performs an external write. The existing
`workflow-retrospect` remains the sole evidence-first classifier and produces
only proposal categories.

## Context

- `scripts/workflow-event` is the canonical typed-v2 ledger validator.
-  already supplies frozen final-state and sealed held-out evidence; it
  was retained rather than duplicated or weakened.
- The starting worktree contained unrelated graph, , installer, and
  documentation changes. They were neither rewritten nor included in this
  feature's scope.

## Decisions

### Read-only controller with a declarative envelope

- Context: the workflow had events and final-state checks, but no machine
  checked project authority or deterministic next-slice decision.
- Choice: add a schema/template, a small Node controller, and a deterministic
  smoke fixture.
- Rejected options: a general orchestration runtime, permanent worker swarm,
  or an auto-apply improvement loop.
- Rationale: make scope, budgets, checkpoints, stop thresholds, final-state
  grader, and sealed held-out surface auditable before any normal workflow
  execution occurs.
- Consequences: the controller emits evidence obligations only; a READY-gated
  workflow still performs any implementation.

### Reuse canonical ledger validation

- Context: a partial local detail validator could drift from typed v2 events.
- Choice: delegate structural validation to the fixed, read-only
  `workflow-event validate` implementation for the exact
  `.workflow/<run>/events.jsonl` location.
- Rejected options: copying a second event schema into the controller.
- Rationale: preserve a single source of truth while keeping the controller
  unable to run any verifier named by an envelope.
- Consequences: canonical v2 additions remain compatible by construction.

### Fail closed on scope and stopping evidence

- Context: code-diff adversarial review exposed potential unbounded or
  unowned mutation claims.
- Choice: reject bare `**`, reject unsafe path segments, require an active
  declared slice for every `file_changed`, bind ledger placement to
  `.workflow`, and key derived same-hypothesis failure by command plus failure
  text.
- Rejected options: relying on a global allowed-files list outside a slice or
  treating equal failure text from different checks as one hypothesis.
- Rationale: preserve bounded ownership and avoid false no-progress stops.
- Consequences: the smoke now covers all four bypasses and resume remains
  evidence-based.

## Accepted Drift

- Original plan/spec: derive bounded slice transitions and use existing
  proposal-only self-improvement.
- Implemented reality: no product-scope drift. A code-diff review added four
  fail-closed refinements before completion.
- Why accepted: the refinements enforce the original authority and stopping
  invariants rather than extend autonomy.

## Validation Evidence

- `bash tests/project-autonomy-smoke.sh`
  - result: passed, including checkpoint, resume, final-state, no-progress,
    canonical v2 compatibility, path traversal, ledger location, unbounded
    scope, active-slice, and command-scoped hypothesis regressions.
- `bash tests/workflow-event-smoke.sh`
  - result: passed.
- `bash tests/workflow-retrospect-smoke.sh`
  - result: passed; proposal-only behavior remains pinned.
- `bash tests/workflow-docs-smoke.sh`
  - result: passed.
- `bash tests/-suite-smoke.sh`
  - result: passed.
- `scripts/verify-agentic-infra all`
  - result: passed after the final fixes.
- `git diff --check`
  - result: passed.
- Fresh-context review and repeat code-diff adversary review
  - result: GO; the first code-diff review's four blockers were fixed and
    regression-tested.

## Follow-up State

- Remaining risks: the envelope is a local workflow control, not an operating
  system sandbox; normal runtime permissions remain authoritative.
- Parking lot: empirical effectiveness measurement requires independent,
  approved runtime telemetry; it is intentionally not fabricated by this run.
- Superseded docs/specs: none.
- Next links: `workflow/project-autonomy-envelope.md`,
  `workflow/project-autonomy-envelope.schema.json`, and
  `tests/project-autonomy-smoke.sh`.
