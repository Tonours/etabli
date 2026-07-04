# Implementation Loop Contract

Shared contract for implementation from `PLAN.md`.

Pi skills and Claude commands are runtime adapters over this file. Keep harness
details in the adapters; keep the phase order and completion evidence here.

## Required Sequence

1. If a task is provided, run the `plan-loop` behavior first.
2. If no task is provided, read the existing root `PLAN.md`.
3. Continue only when the actual root `PLAN.md` has `Status: READY`; prompt
   wording such as "PLAN.md ready" is not proof.
4. Stop from `DRAFT`, `CHALLENGED`, missing `PLAN.md`, or missing concrete
   checks/required evidence.
5. Run the adversary contract in `workflow/skills/adversary.md` before editing.
6. Fold accepted adversary findings into `PLAN.md`.
7. If blockers remain, set `Status: CHALLENGED` and stop.
8. Implement the still-`READY` plan steps in order with minimal, scoped changes.
9. Update `PLAN.md` only for progress or newly discovered facts.
10. If facts materially invalidate route, scope, checks, or required evidence,
    stop as `plan drift detected`; update `PLAN.md` and do not continue until it
    is refreshed to `READY`.
11. Run focused checks from the plan.
12. Review the diff against `PLAN.md`. In an autonomous run, this review comes
    from a fresh context (subagent reviewer or cross-model) per
    `workflow/spec.md`; without one, stop as `blocked` requesting external
    review.
13. Archive the final implemented plan in `docs/plan/YYYYMMDD-short-slug.md`
    using `workflow/plan-archive.md`; distill it as memory, do not raw-copy
    `PLAN.md`.
14. After archive and validation succeed, delete only the current workspace root
    `PLAN.md`.
15. If archiving is skipped or fails, keep `PLAN.md` and report why.
16. Return files changed, adversary result, validation, review result, risks,
    archive path, deleted `PLAN.md` status, remaining risks, next action if any,
    and final status.

## Completion Evidence

Autonomous implementation loops are complete only when the final state contains
evidence for all of:

- adversary plan review;
- focused validation;
- event ledger per `workflow/events.md` (mandatory for autonomous runs);
- diff/code review;
- implemented-plan archive under `docs/plan/`;
- root `PLAN.md` cleanup after successful archive and validation.
