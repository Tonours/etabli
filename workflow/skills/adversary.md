# Adversary Review Contract

Shared contract for adversarial review of the active root `PLAN.md` and of
implementation diffs (code-diff mode).

Runtime adapters may add tool syntax or source-resolution details. They must not
change the review gate.

## Purpose

Stress-test an implementation-bound plan before editing, and the implementation
diff after review. The adversary pass catches blockers, weak assumptions, missing
checks, edge cases, plan drift, and simpler or safer routes.

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

## Code diff mode

The same adversarial gate applies to the implementation diff, not only the
plan. After the fresh-context review (break-first + plan-fit):

1. Input: the implementation diff against the branch base (`git diff <base>...HEAD`
   when shipping), plus the active `PLAN.md` (or acceptance criteria if archived).
2. **Runner independence (hard gate):**
   - **Default:** cross-model, read-only. Name `adversary_model` in the handoff.
   - **Acceptable substitute** when no other family is available: **double-sample**
     — two fresh same-family reviewers, independent contexts, merged findings;
     record `same-family-pass: double-sample` and both run ids.
   - **Forbidden:** a single same-family pass presented as independent review.
     Stop as `blocked` (autonomous **and** supervised — full autonomy policy).
3. Hunt for: correctness bugs, regressions, unhandled edge cases, acceptance
   criteria not actually met, silent scope drift, unrequested abstraction or
   new dependency, reinvented stdlib/native feature, and simpler or safer
   implementations that were overlooked (same rungs as implementation-loop 12b).
4. **Arbitration of findings:**
   - `low` / `medium`: implementer may accept or reject with concrete evidence.
   - `high`: accept/reject via a **cross-model** pass (or the second sample in a
     double-sample). The implementer alone must not close a high finding.
   - Record decisions in Decision Log / handoff.
5. Fold accepted findings as fixes; re-run checks after any fix.
6. Verdict: `GO`, `GO WITH NOTES`, or `BLOCK`. A surviving blocker stops the
   run as `blocked`.
