---
description: Work from an existing Linear ticket through Linear MCP
argument-hint: [Linear issue URL/key or task]
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion]
---

# Linear Work

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/linear-work.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:

- Use Linear MCP as the source of truth.
- If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`.
- Never implement from a `DRAFT` or `CHALLENGED` plan.
