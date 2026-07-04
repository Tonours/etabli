---
name: linear-ticket-create
description: Create Linear tickets from rough context, bug reports, feature ideas, roadmap notes, or user requests. Use when the user asks to create, draft, split, write, or open Linear tickets/issues.
---

# Linear Ticket Create

Read and follow the shared contract in
`workflow/skills/linear-ticket-create.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy:
   `workflow/skills/linear-ticket-create.md`.
2. If missing, fall back to the Pi agent shared copy:
   `../../workflow/skills/linear-ticket-create.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../../workflow/skills/linear-ticket-create.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/linear-ticket-create.md`.

Rules:
- Use Linear MCP as the Linear integration.
- If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`
  unless the user explicitly asked for a draft only.
- One ticket equals one behavior equals one PR.
