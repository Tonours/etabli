---
description: Implement the existing READY PLAN.md without rerunning planning
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Agent]
---

# Implement

Follow `workflow/spec.md` and the shared contract in
`workflow/skills/implementation-loop.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:

- Do not rerun full planning.
- Do not create `REVIEW.md`.
- After focused checks, run implementation-loop 12b on this diff and record
  `simplify: clean` or `simplify: removed N`.
