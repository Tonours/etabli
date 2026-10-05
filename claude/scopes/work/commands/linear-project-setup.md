---
description: Create a Linear Project plus its prioritized Epics from a spec
argument-hint: [spec URL or path + project context]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Linear Project Setup

User request: $ARGUMENTS

Read and follow the shared contract in
`workflow/skills/linear-project-setup.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use Linear MCP only.
- Confirm with the user before creating the Project or any Epic.
- Use `linear-ticket-create` instead for one isolated ticket.
