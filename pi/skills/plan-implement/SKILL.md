---
name: plan-implement
description: Plan, review, then implement only a READY PLAN.md.
---

# Plan Implement

Follow the shared contract in `workflow/skills/implementation-loop.md`. The
routing map `workflow/spec.md` wins on conflict; open it only when the route or
a gate is in doubt.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Run `workflow/skills/plan-loop.md` first when a task is provided. Load a
domain suite only when the brief clearly matches one.

If the task is self-improvement of Etabli itself, also read
`workflow/skills/self-improvement-loop.md`; if ambitious/A-to-Z,
`workflow/skills/ambitious-project-loop.md`. Both add evidence and slicing
requirements; neither replaces the `READY` gate.

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
- After focused checks, run implementation-loop 12b on this diff and record
  `simplify: clean` or `simplify: removed N`. Then run 12c (`code-quality` when
  exposed, else the narrowest domain skill or 1-3 local siblings). Record
  `quality: unavailable` and stop before completion if neither exists.
