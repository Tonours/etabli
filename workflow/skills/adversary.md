# Adversary Plan Review Contract

Shared contract for adversarial review of the active root `PLAN.md`.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the review gate.

## Purpose

Stress-test an implementation-bound plan before editing. The adversary pass
catches blockers, weak assumptions, missing checks, edge cases, plan drift, and
simpler or safer routes.

## Required Behavior

1. Inspect repo state enough to judge plan drift.
2. Read the actual root `PLAN.md`.
3. Stop if `PLAN.md` is missing.
4. Review for:
   - blockers;
   - weak or unstated assumptions;
   - missing validation or weak required evidence;
   - edge cases;
   - plan drift against current repo state;
   - simpler or safer approaches.
5. Do not implement.
6. Do not create `REVIEW.md` or any secondary active artifact.
7. Decide each finding as accepted or rejected with concrete evidence.
8. Fold accepted findings into `PLAN.md`.
9. Keep `Status: READY` only if no blocker or high-severity issue remains.
10. Otherwise set `Status: CHALLENGED`.
11. Record the pass in `Decision Log`, `Review Changes`, or `Notes / Handoff`.
12. Return accepted findings, rejected findings, final plan status, and next
    route.

## Completion Evidence

An implementation loop can count the adversary pass as complete only when the
final handoff names:

- adversary result;
- accepted findings;
- rejected findings;
- final `PLAN.md` status;
- whether implementation may continue.
