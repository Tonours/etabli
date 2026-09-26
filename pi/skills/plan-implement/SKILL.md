---
name: plan-implement
description: Plan, review, then implement, shipping only a READY PLAN.md. Use only when explicitly asked via /skill:plan-implement; not for single-step tasks or plan-free fixes.
disable-model-invocation: true
---
<!-- GENERATED:adapter-sync:start -->
skill: plan-implement
harness: pi
canonical: pi/skills/plan-implement/SKILL.md
name: plan-implement
description: Plan, review, then implement, shipping only a READY PLAN.md. Use only when explicitly asked via /skill:plan-implement; not for single-step tasks or plan-free fixes.
pointer: Adapter for the `plan-implement` skill. Read and follow the shared contract in `pi/skills/plan-implement/SKILL.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Plan Implement

Follow the shared contract in `workflow/skills/implementation-loop.md`. The
routing map `workflow/spec.md` wins on conflict; open it only when the route or
a gate is in doubt.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Run `workflow/skills/plan-loop.md` first when a task is provided. Load a
domain suite only when the brief clearly matches one.

If the task is ambitious/A-to-Z, also read
`workflow/skills/ambitious-project-loop.md`. It adds evidence and slicing
requirements; it does not replace the `READY` gate.

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
- After focused checks, run implementation-loop 12b on this diff and record
  `simplify: clean` or `simplify: removed N`. Then run 12c (`code-quality` when
  exposed, else the narrowest domain skill or 1-3 local siblings) and append
  `quality_completed` (`status: pass`, or `status: unavailable` and stop
  before completion if no pass exists).
