---
name: plan-implement
description: Plan, review, then implement only when PLAN.md is READY
---

# Plan Implement

Follow `workflow/spec.md`.

1. If a task is provided, run the `plan-loop` behavior first.
2. If no task is provided, read existing `PLAN.md`.
3. Never implement from `DRAFT` or `CHALLENGED`.
4. If the plan is not `READY`, stop with blockers and next action.
5. If the plan is `READY`, implement its steps in order.
6. Keep changes minimal and scope-bound.
7. If facts invalidate the plan, update `PLAN.md` before continuing.
8. Run focused checks from the plan.
9. Return files changed, validation, risks, and final status.

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
