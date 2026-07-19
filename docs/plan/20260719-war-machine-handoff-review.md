# Implemented: Audited War Machine handoff and comparative harness credit

## Metadata

- Archived: 2026-07-19
- Source plan: Audit du handoff War Machine et fermeture du gap de mesure Self-Harness
- Status: IMPLEMENTED
- Commit / branch: uncommitted worktree on `main` at `d93ef6f0`
- Pulled baseline: fast-forward `7222d221..d93ef6f0` from `origin/main`

## Outcome

- Replaced the requested ten-line placeholder with one canonical, sourced
  French handoff that separates observed repo facts, external preprint results,
  decisions, rejected proposals, validation evidence, and permission gates.
- Converted the other three handoffs from the pulled four-commit batch into
  explicit historical pointers to the canonical review.
- Rejected a duplicate Self-Harness route/skill, automatic apply/commit, a
  static model table, a proxy, generic multi-worktree fan-out, a skill factory,
  and a dashboard because they duplicated current owners, weakened gates, or
  lacked reproducible failure evidence.
- Added `harness_validation_completed` as the missing comparative credit event.
  It requires stable population identifiers, positive integer counts, equal
  baseline/candidate totals per split, a strict held-in gain for acceptance,
  and held-out non-regression.
- Extended `workflow-metrics` additively with proposal/validation coverage,
  unmatched validations, verdicts, and percentage-point deltas per candidate.
  Proposed but unvalidated candidates remain visible with comparative fields
  at `null`; heterogeneous suites are never averaged.

## Context

- `docs/handoffs/20260719-etabli-war-machine-handoff.md`: the requested file
  was a placeholder that incorrectly claimed workflow ownership and requested
  a commit without listing executable commands.
- Commits `0fadd7fc`, `c7b471e9`, `f72e2eb5`, and `d93ef6f0`: four competing
  handoffs landed after the capabilities they described as future work.
- `docs/plan/20260707-harness-self-improvement-hardening.md`: weakness mining,
  bounded proposal, validation, typed events, and the no-auto-apply gate were
  already implemented.
- `docs/plan/20260719-adaptive-council-routing.md`: adaptive multi-model routing
  and the parent-only writer rule were already implemented before the handoff
  batch.
- `.workflow/war-machine-handoff-review/events.jsonl`: append-only local ledger
  for plan, adversary, implementation, validation, and review evidence.

## Decisions

### Consolidate the handoff instead of implementing its roadmap

- Context: the four pulled documents contradicted one another and proposed
  owners that already existed in the workflow contract.
- Choice: preserve one audited canonical document and retain the other paths as
  superseded pointers for Git history.
- Rejected options: delete the competing files, treat a handoff as the workflow
  source of truth, or execute its unsourced roadmap.
- Rationale: `workflow/spec.md` and the existing skill contracts remain the
  canonical owners; the review should remove ambiguity without erasing origin.
- Consequences: the review has one active decision surface and no new route.

### Credit only comparable harness evidence

- Context: proposal and rejection events existed, but no accepted event linked
  baseline and candidate results over inspectably identical populations.
- Choice: require stable population identifiers and matching totals within
  held-in and held-out, then enforce strict held-in improvement plus held-out
  non-regression for `accepted`.
- Rejected options: equal totals without population identity, qualitative
  scores forced into counts, or acceptance from held-in evidence alone.
- Rationale: deterministic credit must distinguish a real comparable treatment
  from two same-sized but different samples.
- Consequences: non-comparable evidence stays on the existing proposal and
  rejection events rather than producing a false delta.

### Preserve missing evidence in metrics

- Context: an early implementation listed only validated candidates, so an
  unvalidated proposal disappeared from the candidate array despite remaining
  in the coverage denominator.
- Choice: build candidate rows from the union of proposals and validations;
  leave validation fields `null` until a comparative event exists and report
  orphan validations separately.
- Rejected options: omit incomplete proposals, synthesize zero deltas, or
  average percentages across different suites.
- Rationale: absence of evidence must stay visible and must not look like a
  zero-effect measurement.
- Consequences: the current ledger reports one proposal, zero validations,
  zero coverage, and one candidate row with null comparative fields.

## Accepted Drift

- Original plan/spec: the comparison required the same population and valid
  counts, but did not initially define a mechanical population identity.
- Implemented reality: every result names a non-empty stable population ID;
  baseline and candidate IDs and totals must match inside each split.
- Why accepted: fresh-context review proved that equal totals alone allow two
  different samples to pass as comparable.

- Original plan/spec: metrics required `null` when evidence was unavailable.
- Implemented reality: the candidate union and tests explicitly preserve an
  unvalidated proposal with null verdict, reason, deltas, checks, and evidence.
- Why accepted: the first implementation satisfied aggregate coverage but hid
  the incomplete candidate at row level.

## Validation Evidence

- `bash tests/workflow-event-smoke.sh`:
  - result: PASS; accepted/rejected comparisons plus population mismatch,
    total mismatch, zero total, fractional counts, invalid counts, false gain,
    and held-out regression are pinned.
- `bash tests/workflow-metrics-smoke.sh`:
  - result: PASS; deduplicated proposals, latest validation, orphan validation,
    coverage, deltas, and unvalidated null fields are pinned.
- `bash tests/workflow-docs-smoke.sh`:
  - result: PASS.
- `scripts/answer-quality-check --mode handoff
  docs/handoffs/20260719-etabli-war-machine-handoff.md`:
  - result: PASS.
- `scripts/research-proof-check
  docs/handoffs/20260719-etabli-war-machine-handoff.md`:
  - result: PASS.
- `scripts/verify-agentic-infra all`:
  - result: PASS; 219 Pi tests, 610 expectations, 32/32 router fixtures, and
    shell, docs, skill lock, links, install, and Nvim groups green.
  - note: the real CLI smoke remained opt-in and the live browser capture was
    not applicable; deterministic checks passed.
- Fresh-context reviewer `/root/war_machine_fresh_review`:
  - first result: `BLOCK`; five findings were accepted and fixed.
  - final result: implementation review `GO` and code-diff adversary `GO`, with
    no actionable finding remaining.
- `git diff --check`:
  - result: PASS.

## Follow-up State

- Remaining risks: historical runs have no comparative validation events;
  token telemetry still has no measured successful outcome, so
  `tokens_per_successful_outcome` remains `null`; recent preprint results do
  not establish a performance gain for Etabli.
- Parking lot: exercise the new event only when a real candidate has stable
  held-in and held-out populations; improve token capture only from measured
  runtime evidence; revisit parked UI/factory ideas only after reproducible
  recurring failures.
- Superseded docs/specs: `docs/handoff.md`,
  `docs/handoff-etabli-machine-de-guerre-20260719.md`, and
  `docs/handoffs/20260719-etabli-machine-de-guerre-handoff.md` now point to the
  canonical audited handoff.
- Next links: `docs/handoffs/20260719-etabli-war-machine-handoff.md`,
  `workflow/skills/self-improvement-loop.md`, `workflow/events.md`,
  `scripts/workflow-event`, and `scripts/workflow-metrics`.
