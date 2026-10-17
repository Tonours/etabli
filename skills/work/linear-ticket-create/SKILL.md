---
name: linear-ticket-create
description: Creates or splits Linear tickets from rough requests. Use when new Linear tickets are needed; not for working tickets or Linear project setup.
argument-hint: [ticket context]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Linear Ticket Create

Read and follow the shared contract in
`workflow/skills/linear-ticket-create.md`.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Rules:
- Use Linear MCP as the Linear integration.
- If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`
  unless the user explicitly asked for a draft only.
- One ticket equals one behavior equals one PR.
