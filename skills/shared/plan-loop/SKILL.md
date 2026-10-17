---
name: plan-loop
description: Creates or reviews a PLAN.md, stopping at CHALLENGED or READY. Use when starting planned work, drafting, hardening, or reviewing a draft plan; not for implementing or for unplanned questions.
argument-hint: <task description>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Skill]
---

# Plan Loop

Read and follow the shared contract in `workflow/skills/plan-loop.md`.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
