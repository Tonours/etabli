# Self-Improvement Loop Contract

Shared contract for improving Etabli itself from observed workflow evidence.

The loop is local-first and reviewed. It turns recurring failures into safer
workflow changes without bypassing `PLAN.md`, validation, or human checkpoints.
The model may propose harness changes, but evaluator and permission controls
stay outside the mutation loop.

## Inputs

Use evidence that can be inspected again:

- `.workflow/<slug>/events.jsonl`;
- implemented plan archives in `docs/plan/`;
- validation failures and no-progress events;
- accepted adversary or review findings;
- router misses and guard failures;
- dogfood blockers;
- runtime capability overclaims;
- harness failure records with terminal cause, causal status, mechanism,
  verifier, and trace links.

Do not use vibes, stale memory, or a single anecdote as enough proof for a
workflow invariant.

## Harness Improvement Loop

Use a Self-Harness-style loop when the improvement target is the workflow,
router, memory, permissions, checks, or harness code:

1. Weakness mining: cluster failures into verifier-grounded patterns. Record
   the terminal verifier-level cause, whether the agent behavior is actually
   causal, the exposed harness mechanism, and the traces that prove it.
2. Bounded proposal: propose narrow edits from an explicit context containing
   editable surfaces, mined failure patterns, passing behaviors to preserve,
   and previously attempted edits.
3. Proposal validation: accept only candidates that resolve the held-in failure
   evidence and do not regress held-out router, docs, event, or workflow smoke
   checks. When baseline and candidate use the same comparable population,
   record `harness_validation_completed` with the same stable population
   identifier on both sides, integer pass counts, checks, and evidence. An
   accepted comparison needs a strict held-in gain and held-out non-regression.
4. Rejection logging: record rejected candidates and negative results with the
   reason, regressions, and evidence so future runs do not repeat them.

Do not collapse unrelated candidate suites into one harness-improvement
average. Report proposal coverage, verdicts, and percentage-point deltas per
candidate; unavailable or non-comparable evidence remains `null` or uses the
non-comparative candidate events.

## Candidate Outcomes

Each candidate ends as one of:

- `no_op`: evidence is weak, isolated, stale, or already covered;
- `recommendation`: useful but not yet implementation-ready;
- `router_fixture`: a prompt/route pair that prevents a real routing miss;
- `contract_patch`: a bounded update to `workflow/spec.md` or
  `workflow/skills/`;
- `mechanical_check`: hook, smoke assertion, fixture, lint, or helper test;
- `rejected`: candidate failed validation, overfit the evaluator, weakened
  permission boundaries, or lacked ownership.

`workflow-retrospect` may report candidates, but it never applies patches,
pushes, posts, deploys, or changes external systems.

## Required Sequence

1. Inspect current repo state and relevant evidence sources.
2. Run or consult `scripts/workflow-retrospect` when recurring evidence is the
   question.
3. Classify each candidate with source paths, confidence, proposed outcome, and
   held-in / held-out validation surfaces.
4. Reject candidates without repeatable evidence, clear ownership, or a
   validation surface.
5. Reject candidates that would reward-hack a narrow test, hide negative
   results, collapse diversity into the same proposal, or move oversight inside
   the evolving harness.
6. For accepted candidates, create or refresh `PLAN.md`; implementation starts
   only from `Status: READY`.
7. Implement the smallest reviewed change that closes the evidence-backed gap.
8. Add or update a mechanical check whenever the change creates a transverse
   invariant.
9. Run focused checks and record results in the event ledger when the run is
   autonomous.
10. Archive the implemented plan only after validation, then delete the root
   `PLAN.md`.

## Safety Gates

- Never weaken checks to make self-improvement pass.
- Never auto-apply `workflow-retrospect` output.
- Never accept a candidate on held-in evidence alone when a relevant held-out
  smoke, fixture, or review surface exists.
- Never convert `proxy_supported`, `blocked`, or `unknown` runtime capability
  labels into `confirmed` without the proof command.
- Never create external write-back, deploy, push, merge, billing, production,
  or secret-touching behavior without an explicit command contract.

## Completion Evidence

A self-improvement run is complete only when the final handoff names:

- evidence sources inspected;
- candidates accepted and rejected;
- files changed;
- mechanical checks added or deliberately not needed;
- validation commands and results;
- archive path or explicit blocker.
