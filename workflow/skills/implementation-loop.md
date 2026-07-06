# Implementation Loop Contract

Shared contract for implementation from `PLAN.md`.

Pi skills and Claude commands are runtime adapters over this file. Keep harness
details in the adapters; keep the phase order and completion evidence here.

## Required Sequence

0. Understand before planning: run a scoped recon of the affected area —
   subagent scouts when available so the main context stays lean — and carry
   sourced findings (file:line) into the plan. Scale it down to a quick read
   for small tasks; never skip it entirely.
1. If a task is provided, run the `plan-loop` behavior first.
2. If no task is provided, read the existing root `PLAN.md`.
3. Continue only when the actual root `PLAN.md` has `Status: READY`; prompt
   wording such as "PLAN.md ready" is not proof.
4. Stop from `DRAFT`, `CHALLENGED`, missing `PLAN.md`, or missing concrete
   checks/required evidence.
5. Run the adversary contract in `workflow/skills/adversary.md` before editing.
6. Fold accepted adversary findings into `PLAN.md`.
7. If blockers remain, set `Status: CHALLENGED` and stop.
8. Implement the still-`READY` plan steps in order with minimal, scoped
   changes. A code behavior change ships with its tests per
   `workflow/spec.md`; a bug fix starts from a failing test that reproduces
   the issue.
9. Update `PLAN.md` only for progress or newly discovered facts.
10. If facts materially invalidate route, scope, checks, or required evidence,
    stop as `plan drift detected`; update `PLAN.md` and do not continue until it
    is refreshed to `READY`.
11. For material user-facing product-flow changes, or any explicit dogfood
    request, run the product dogfood contract in
    `workflow/skills/product-dogfood.md`: map flows, derive the scenario matrix,
    execute the strongest available observable surface, record blocked external
    legs honestly, and re-run failed plus adjacent scenarios after each
    accepted fix. If the plan omitted dogfood evidence for such a change, stop
    as plan drift and strengthen the checks before continuing.
12. Run focused checks from the plan after dogfood and after any accepted
    dogfood fix, so readiness is never based on checks that predate the latest
    product-flow edit.
12b. Simplification pass once checks are green: remove needless abstraction,
    dead branches, and duplication introduced by the change, without behavior
    change; re-run the focused checks if it edited anything.
13. Review the diff against `PLAN.md`. In an autonomous run, this review comes
    from a fresh context (subagent reviewer or cross-model) per
    `workflow/spec.md`; without one, stop as `blocked` requesting external
    review.
13b. In an autonomous run, follow with the adversary Code diff mode
    (`workflow/skills/adversary.md`): cross-model, read-only, on the
    implementation diff; fold accepted findings and re-run checks.
14. Archive the final implemented plan in `docs/plan/YYYYMMDD-short-slug.md`
    using `workflow/plan-archive.md`; distill it as memory, do not raw-copy
    `PLAN.md`.
15. After archive and validation succeed, delete only the current workspace root
    `PLAN.md`.
16. If archiving is skipped or fails, keep `PLAN.md` and report why.
17. Return files changed, adversary result, validation, review result, risks,
    archive path, deleted `PLAN.md` status, remaining risks, next action if any,
    and final status.

## Completion Evidence

Autonomous implementation loops are complete only when the final state contains
evidence for all of:

- adversary plan review;
- adversary code-diff review in autonomous runs;
- focused validation;
- product dogfood scenario evidence when required by the plan;
- event ledger per `workflow/events.md` (mandatory for autonomous runs);
- diff/code review;
- implemented-plan archive under `docs/plan/`;
- root `PLAN.md` cleanup after successful archive and validation.
