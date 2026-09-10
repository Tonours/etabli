---
description: Create/review PLAN.md and stop at CHALLENGED or READY
argument-hint: <task description>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Skill]
---

# Plan Loop

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/plan-loop.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
