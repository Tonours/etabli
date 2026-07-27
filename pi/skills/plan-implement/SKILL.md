---
name: plan-implement
description: Plan, review, then implement only when PLAN.md is READY
---

# Plan Implement

Follow `workflow/spec.md` and the shared contract in
`workflow/skills/implementation-loop.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order.
Try each path with a direct read; do not stop at the first miss.

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/plan-archive.md`
   - `workflow/skills/implementation-loop.md`
   - `workflow/skills/adversary.md`
   - `PLAN_TEMPLATE.md`
   - `PLAN_TEMPLATE_FULL.md`
2. Prefer absolute installed home copies (stable when skill paths are realpath'd):
   - `~/.pi/agent/PLAN_TEMPLATE.md`, `~/.pi/agent/PLAN_TEMPLATE_FULL.md`
   - `~/.claude/PLAN_TEMPLATE.md`, `~/.claude/PLAN_TEMPLATE_FULL.md`
   - `~/.agents/PLAN_TEMPLATE.md`, `~/.agents/PLAN_TEMPLATE_FULL.md`
   - and matching workflow files under each of those roots:
     - `workflow/spec.md`, `workflow/plan-archive.md`
     - `workflow/skills/implementation-loop.md`, `workflow/skills/adversary.md`
3. Relative install-surface fallbacks (logical path only; do not realpath the skill dir first):
   - From `~/.pi/agent/skills/<skill>` or `~/.agents/skills/<skill>`:
     - `../../PLAN_TEMPLATE.md`, `../../PLAN_TEMPLATE_FULL.md`
     - `../../workflow/spec.md`, `../../workflow/plan-archive.md`
     - `../../workflow/skills/implementation-loop.md`, `../../workflow/skills/adversary.md`
4. Relative Etabli-repo fallbacks after realpath into `pi/skills/<skill>`:
   - `../../../PLAN_TEMPLATE.md`, `../../../PLAN_TEMPLATE_FULL.md`
   - `../../../workflow/spec.md`, `../../../workflow/plan-archive.md`
   - `../../../workflow/skills/implementation-loop.md`, `../../../workflow/skills/adversary.md`
5. If any fallback file exists, read it and continue. Do not tell the user the template/spec is missing.
6. If archive instructions are missing after all lookups, still implement only from `READY`; skip archiving with a warning instead of inventing an archive format.

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
