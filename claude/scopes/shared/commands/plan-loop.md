---
description: Create or review a PLAN.md, stopping at CHALLENGED or READY. Use when starting planned work, drafting, hardening, or reviewing a draft plan; not for implementing.
argument-hint: <task description>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Skill]
---
<!-- GENERATED:adapter-sync:start -->
skill: plan-loop
harness: claude
canonical: workflow/skills/plan-loop.md
description: Create or review a PLAN.md, stopping at CHALLENGED or READY. Use when starting planned work, drafting, hardening, or reviewing a draft plan; not for implementing.
pointer: Adapter for the `plan-loop` skill. Read and follow the shared contract in `workflow/skills/plan-loop.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Plan Loop

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/plan-loop.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
