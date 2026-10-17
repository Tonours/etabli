---
name: verify-workflow
description: Verifies or retests a claim without editing anything. Use when evidence must confirm or reject a stated claim; not for fixing, implementing, or open-ended research.
argument-hint: [target claim or checks]
allowed-tools: [Read, Glob, Grep, AskUserQuestion]
---

# Verify Workflow

Read and follow the shared contract in `workflow/skills/verify.md`.

The name is `verify-workflow`, not `verify`, because Claude Code ships a
native `/verify` skill for running and checking apps.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
