---
name: plan-implement
description: Plan, review, then implement only when PLAN.md is READY
---

# Plan Implement

Follow `workflow/spec.md` and the shared contract in
`workflow/skills/implementation-loop.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/plan-archive.md`
   - `workflow/skills/implementation-loop.md`
   - `workflow/skills/adversary.md`
   - `PLAN_TEMPLATE.md`
   - `PLAN_TEMPLATE_FULL.md`
2. If one of those files is missing in the current workspace, fall back to the Pi agent shared copies when this skill is loaded through `~/.pi/agent/skills`:
   - `../../workflow/spec.md`
   - `../../workflow/plan-archive.md`
   - `../../workflow/skills/implementation-loop.md`
   - `../../workflow/skills/adversary.md`
   - `../../PLAN_TEMPLATE.md`
   - `../../PLAN_TEMPLATE_FULL.md`
3. If those are unavailable, fall back to the Etabli repo copies when this skill is loaded from the repo target path:
   - `../../../workflow/spec.md`
   - `../../../workflow/plan-archive.md`
   - `../../../workflow/skills/implementation-loop.md`
   - `../../../workflow/skills/adversary.md`
   - `../../../PLAN_TEMPLATE.md`
   - `../../../PLAN_TEMPLATE_FULL.md`
4. If any fallback files exist, read them and continue. Do not tell the user the template/spec is missing.
5. If archive instructions are missing after all lookups, still implement only from `READY`; skip archiving with a warning instead of inventing an archive format.

Run `plan-loop` behavior when a task is provided, then follow
`workflow/skills/implementation-loop.md`.

If the task is self-improvement of Etabli itself, also read
`workflow/skills/self-improvement-loop.md`. If the task is an ambitious or
A-to-Z project, also read `workflow/skills/ambitious-project-loop.md`. These
contracts add evidence and slicing requirements; they do not replace the
`READY` gate.

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
