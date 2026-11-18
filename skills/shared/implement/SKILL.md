---
name: implement
description: Implements an existing READY PLAN.md without replanning. Use when a READY plan should be built; not for planning, design or unplanned fixes.
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Agent]
---

# Implement

Follow the shared contract in `workflow/skills/implementation-loop.md`. The
routing map `workflow/spec.md` wins on conflict; open it only when the route or
a gate is in doubt.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Rules:
- Do not rerun full planning.
- Do not create `REVIEW.md`.
- The READY plan must cover the requested task; if the request names another
  task, run plan-loop first (implementation-loop.md steps 1–2).
