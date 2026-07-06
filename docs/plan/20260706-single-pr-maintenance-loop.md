# Implemented: Single-PR maintenance loop

## Metadata
- Archived: 2026-07-06
- Source plan: supervised single-PR maintenance loop
- Status: IMPLEMENTED
- Commit / branch: `main` at `db5fc9d`; changes are uncommitted

## Outcome
- Added `workflow/skills/pr-maintenance-loop.md`, a shared contract for a
  supervised one-PR, one-worktree, one-loop maintenance pilot.
- Added `scripts/pr-latest-head-status`, a local read-only helper that
  classifies PR review/check evidence against the latest pushed head SHA.
- Added fixture-backed smoke coverage for `clean_latest_head`, `stale_review`,
  `needs_rerun`, and missing latest-head checks, including a red-team stale
  review case where an old clean review must not count as done.
- Updated workflow docs, README, CI smoke pins, and docs smoke assertions to
  expose the pilot contract without authorizing push, merge, deploy, PR
  comments, bot review requests, or multi-PR overnight orchestration.

## Context
- `workflow/spec.md`: canonical Etabli routing, READY gates, event ledgers,
  fresh-context review, and no external write-back boundaries.
- `workflow/skills/pr-review.md` and `workflow/skills/sec-pr.md`: existing
  GitHub PR/security PR contracts that informed the supervised PR-maintenance
  shape.
- `scripts/workflow-retrospect`: existing read-only helper style used as the
  model for deterministic local verification.
- `.workflow/single-pr-maintenance-loop/events.jsonl`: local ignored run ledger
  with route, adversary, file-change, validation, review, and archive events.

## Decisions
### Keep The First Version Local And Deterministic
- Context: A live GitHub wrapper would add external-state and write-boundary
  risk before the latest-head rule was proven.
- Choice: Ship a fixture-driven helper that accepts a JSON snapshot.
- Rejected options: live `gh` mutation, automatic bot review requests,
  automatic push/merge/deploy, or a multi-PR scheduler.
- Rationale: The first useful invariant is that old clean evidence never
  satisfies latest-head completion.
- Consequences: A future supervised wrapper can collect live data and pass it
  to the same helper instead of duplicating the classifier.

### Preserve Single-PR Scope
- Context: The goal was a supervised pilot, not overnight queue processing.
- Choice: Contract language requires one PR, one worktree, one loop, clean base
  preflight, isolated branch/thread ownership, fresh-context review, cleanup,
  final report, and explicit worktree cleanup.
- Rejected options: multi-PR orchestration or implicit sibling-worktree edits.
- Rationale: Worktree leakage and stale reviews are the high-risk failure modes
  to block before scaling.
- Consequences: The contract is safe to invoke for one PR; scaling remains a
  later layer with separate evidence.

## Accepted Drift
- Original plan/spec: Add contract, helper, fixtures, smoke pins, review,
  archive, and cleanup.
- Implemented reality: Completed as planned. The first docs smoke failed on a
  fragile long-line assertion and was fixed with stable fragments before
  rerunning successfully. Code-diff adversary found two medium gaps; both were
  accepted, fixed, and revalidated.
- Why accepted: The adjustment strengthened mechanical pins and corrected
  latest-head semantics without expanding scope.

### Code-Diff Adversary Fixes
- Original plan/spec: Missing latest-head checks must prevent a clean result.
- Implemented reality: The first classifier version returned `stale_review` for
  an old clean review even when latest-head checks were missing.
- Why accepted: Missing latest-head checks now return `needs_rerun` with reason
  `latest_head_missing_checks`.

- Original plan/spec: The contract requires base worktree preflight, isolated
  worktree/branch/thread ownership, no sibling-worktree edits, and no automatic
  external write-back.
- Implemented reality: The first docs smoke pins did not cover every one of
  those requirements.
- Why accepted: The smoke now asserts the preflight, isolation, sibling-edit
  ban, and write-boundary phrases directly.

## Validation Evidence
- `bash tests/pr-latest-head-status-smoke.sh`
  - result: passed; covers clean latest head, stale review, generic rerun, and
    `latest_head_missing_checks`.
- `bash tests/workflow-docs-smoke.sh`
  - result: passed.
- `bash tests/workflow-contract-coverage-smoke.sh`
  - result: passed.
- `bash -n scripts/pr-latest-head-status tests/pr-latest-head-status-smoke.sh tests/workflow-docs-smoke.sh`
  - result: passed.
- `python3 codex/skills/codex-dynamic-workflows/scripts/verify_workflow.py .workflow/single-pr-maintenance-loop`
  - result: passed.
- `scripts/workflow-event validate single-pr-maintenance-loop`
  - result: passed.
- `git diff --check`
  - result: passed.
- Fresh-context review
  - result: `GO`, no findings.
- Code-diff adversary
  - result: `GO WITH NOTES`; accepted findings were fixed and targeted checks
    reran successfully.
- `scripts/pr-latest-head-status --json tests/fixtures/pr-maintenance/missing-latest-checks.json`
  - result: `needs_rerun` with reason `latest_head_missing_checks`.

## Follow-up State
- Remaining risks: The helper currently validates a supplied JSON snapshot; a
  live GitHub collection wrapper is still future work.
- Parking lot: Add a supervised `gh` snapshot adapter only after a real single
  PR pilot needs it.
- Superseded docs/specs: none.
- Next links:
  - `workflow/skills/pr-maintenance-loop.md`
  - `scripts/pr-latest-head-status`
  - `tests/pr-latest-head-status-smoke.sh`
  - `tests/fixtures/pr-maintenance/missing-latest-checks.json`
