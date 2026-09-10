---
name: plan-implement
description: Plan, review, then implement only a READY PLAN.md.
---

# Plan Implement

Follow `workflow/spec.md` and the shared contract in
`workflow/skills/implementation-loop.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Run `workflow/skills/plan-loop.md` when a task is provided, then follow
`workflow/skills/implementation-loop.md`. Load a domain suite only when the
brief clearly matches one.

If the task is self-improvement of Etabli itself, also read
`workflow/skills/self-improvement-loop.md`. If the task is an ambitious or
A-to-Z project, also read `workflow/skills/ambitious-project-loop.md`. These
contracts add evidence and slicing requirements; they do not replace the
`READY` gate.

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
- After focused checks, run implementation-loop 12b on this diff and record
  `simplify: clean` or `simplify: removed N`. Then run 12c (`code-quality` when
  exposed, else the narrowest domain skill or 1-3 local siblings). Record
  `quality: unavailable` and stop before completion if neither exists.
