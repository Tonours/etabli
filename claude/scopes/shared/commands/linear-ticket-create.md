---
description: Create Linear tickets through Linear MCP
argument-hint: [ticket context]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Linear Ticket Create

User request: $ARGUMENTS

Read and follow the shared contract in
`workflow/skills/linear-ticket-create.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy:
   `workflow/skills/linear-ticket-create.md`.
2. If missing, fall back to the Claude shared copy:
   `../workflow/skills/linear-ticket-create.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../workflow/skills/linear-ticket-create.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/linear-ticket-create.md`.

Rules:
- Use Linear MCP as the Linear integration.
- If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`
  unless the user explicitly asked for a draft only.
- One ticket equals one behavior equals one PR.
