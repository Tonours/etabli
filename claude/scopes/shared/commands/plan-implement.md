---
description: Plan, review, then implement, shipping only when PLAN.md is READY. Use only when explicitly invoked; not for single-step tasks.
disable-model-invocation: true
argument-hint: [task description]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Agent, Skill]
---
<!-- GENERATED:adapter-sync:start -->
skill: plan-implement
harness: claude
canonical: pi/skills/plan-implement/SKILL.md
description: Plan, review, then implement, shipping only when PLAN.md is READY. Use only when explicitly invoked; not for single-step tasks.
pointer: Adapter for the `plan-implement` skill. Read and follow the shared contract in `pi/skills/plan-implement/SKILL.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Plan Implement

User request: $ARGUMENTS

Follow the shared contract in `workflow/skills/implementation-loop.md`. The
routing map `workflow/spec.md` wins on conflict; open it only when the route or
a gate is in doubt.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Run `workflow/skills/plan-loop.md` when a task is provided, then follow
`workflow/skills/implementation-loop.md`. Load a domain suite only when the
brief clearly matches one.

If the task is an ambitious or A-to-Z project, also read
`workflow/skills/ambitious-project-loop.md`. It adds evidence and slicing
requirements; it does not replace the `READY` gate.

Rules:

- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
- After focused checks, run implementation-loop 12b on this diff and record
  `simplify: clean` or `simplify: removed N`. Then run 12c (`code-quality` when
  exposed, else the narrowest domain skill or 1-3 local siblings). Record
  `quality: unavailable` and stop before completion if neither exists.
