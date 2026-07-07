# Implemented: Harness self-improvement hardening

## Metadata
- Archived: 2026-07-07
- Source plan: Harness-informed self-improvement hardening for Etabli
- Status: IMPLEMENTED
- Commit / branch: `main` at `ab39b30`; changes are uncommitted

## Outcome
- Strengthened `workflow/skills/self-improvement-loop.md` with a
  Self-Harness-style sequence: weakness mining, bounded proposal, proposal
  validation, and rejection logging.
- Added ledger vocabulary for rich harness improvement evidence:
  `harness_failure_pattern`, `harness_proposal`, and
  `harness_candidate_rejected`.
- Updated `scripts/workflow-retrospect` so typed `harness_failure_pattern`
  events are mined as first-class recurring issues and mapped to
  `contract_patch`, without being silently discarded or recategorized through
  older keyword rules.
- Hardened Pi and Claude routing so self-improvement prompts containing run
  evidence or run proof route to `plan-implement`, while explicit verification
  verbs still route to verification.
- Added router, event, retrospect, docs, README, and scaffold smoke coverage
  for the new behavior.

## Context
- Article source: Lilian Weng, "Harness Engineering for Self-Improvement",
  published 2026-07-04.
- Relevant article lessons used here: harnesses are the deployment layer around
  planning, tool use, memory, artifacts, and evaluation; Self-Harness uses
  weakness mining, bounded proposals, and validation; future risks include
  fuzzy evaluators, negative results, diversity collapse, reward hacking,
  long-term repo health, and human oversight.
- Current repo context: self-improvement and ambitious-project routing already
  existed in the dirty worktree before this run. This archive records the
  article-driven hardening layered on top.

## Decisions
### Keep The Existing Route Model
- Context: Existing Etabli self-improvement work already routes through
  `plan-implement` and `implement` with the READY gate.
- Choice: Add stronger contracts, event types, retrospect mining, and fixtures
  without adding a new route value.
- Rejected options: create a standalone self-improvement optimizer route or
  bypass `PLAN.md`.
- Rationale: the article argues for harness-level improvement, but Etabli's
  safety model still depends on reviewed plans and smoke checks.
- Consequences: behavior improves without new external write permissions.

### Treat Harness Failure Patterns As Typed Evidence
- Context: A typed `harness_failure_pattern` event can contain words such as
  "router miss", but the event type itself matters.
- Choice: preserve `harness_failure_pattern` before keyword classification and
  map repeated instances to `contract_patch`.
- Rejected options: rely on old text matching or discard harness-specific
  weakness records unless they mention known categories.
- Rationale: article-backed weakness mining needs rich causal records, not only
  legacy issue labels.
- Consequences: `workflow-retrospect` can surface new harness failure modes
  such as oversight moving inside the mutation loop.

### Keep Verify Wording Explicit
- Context: the broad nouns "evidence" and "preuve" caused self-improvement
  prompts to route to verification before the self-improvement branch.
- Choice: remove those broad nouns from verify routing while keeping explicit
  verbs such as `verify`, `verifie`, `prouve`, `retest`, and
  `completion audit`.
- Rejected options: move self-improvement before verify wholesale, which could
  steal explicit verification requests.
- Rationale: "run evidence" and "preuve de run" are common evidence sources for
  self-improvement, not necessarily verifier commands.
- Consequences: English and French run-evidence prompts now route through
  `plan-implement`; explicit proof/verification verbs remain read-only.

## Accepted Drift
- Original plan/spec: only docs/contract/event surfaces were expected.
- Implemented reality: router fixtures and Pi/Claude verify patterns also
  changed.
- Why accepted: fresh-context review found a real route regression directly
  affecting self-improvement prompts grounded in run evidence.

## Validation Evidence
- `bun test pi/extensions/__tests__/`
  - result: passed, 198 tests
- `bash tests/router-eval-smoke.sh`
  - result: passed
- `bash tests/workflow-docs-smoke.sh`
  - result: passed
- `bash tests/workflow-event-smoke.sh`
  - result: passed
- `bash tests/workflow-retrospect-smoke.sh`
  - result: passed
- `git diff --check`
  - result: passed
- `scripts/workflow-event validate harness-self-improvement-hardening`
  - result: passed before archive
- Fresh-context review:
  - first pass: `BLOCK`; accepted findings fixed
  - final pass: `GO WITH NOTES`; no remaining findings in scope
  - note: the read-only review sandbox could not run mktemp-backed smoke tests,
    but the main run executed them successfully.

## Follow-up State
- Remaining risks: the worktree still contains pre-existing uncommitted
  self-improvement/ambitious-project changes from before this run.
- Parking lot: richer schemas for `harness_proposal` and
  `harness_candidate_rejected` can be added if future real ledgers need field
  validation beyond event-type acceptance.
- Superseded docs/specs: none.
- Next links:
  - `workflow/skills/self-improvement-loop.md`
  - `workflow/events.md`
  - `scripts/workflow-retrospect`
  - `tests/workflow-retrospect-smoke.sh`
  - `tests/router-evals/core.json`
