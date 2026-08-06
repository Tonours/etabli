---
description: Work from an existing Linear ticket through Linear MCP
argument-hint: [Linear issue URL/key or task]
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion]
---

# Linear Work

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/linear-work.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/linear-work.md`.
2. If missing, fall back to the Claude shared copy:
   `../workflow/skills/linear-work.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../workflow/skills/linear-work.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/linear-work.md`.

Rules:

- Use Linear MCP as the source of truth.
- If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`.
- Never implement from a `DRAFT` or `CHALLENGED` plan.
