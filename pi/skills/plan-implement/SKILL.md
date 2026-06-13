---
name: plan-implement
description: Plan, review, then implement only when PLAN.md is READY
---

# Plan Implement

Follow `workflow/spec.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/plan-archive.md`
   - `PLAN_TEMPLATE.md`
   - `PLAN_TEMPLATE_FULL.md`
2. If one of those files is missing in the current workspace, fall back to the Pi agent shared copies when this skill is loaded through `~/.pi/agent/skills`:
   - `../../workflow/spec.md`
   - `../../workflow/plan-archive.md`
   - `../../PLAN_TEMPLATE.md`
   - `../../PLAN_TEMPLATE_FULL.md`
3. If those are unavailable, fall back to the Etabli repo copies when this skill is loaded from the repo target path:
   - `../../../workflow/spec.md`
   - `../../../workflow/plan-archive.md`
   - `../../../PLAN_TEMPLATE.md`
   - `../../../PLAN_TEMPLATE_FULL.md`
4. If any fallback files exist, read them and continue. Do not tell the user the template/spec is missing.
5. If archive instructions are missing after all lookups, still implement only from `READY`; skip archiving with a warning instead of inventing an archive format.

1. If a task is provided, run the `plan-loop` behavior first.
2. If no task is provided, read existing `PLAN.md`.
3. Never implement from `DRAFT` or `CHALLENGED`.
4. If the plan is not `READY`, stop with blockers and next action.
5. If the plan is `READY`, implement its steps in order.
6. Keep changes minimal and scope-bound.
7. If facts invalidate the plan, update `PLAN.md` before continuing.
8. Run focused checks from the plan.
9. If implementation and checks completed, archive the final plan in `docs/plan/YYYYMMDD-short-slug.md` using `workflow/plan-archive.md`; distill it as memory, do not raw-copy `PLAN.md`.
10. Return files changed, validation, risks, archive path, and final status.

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
