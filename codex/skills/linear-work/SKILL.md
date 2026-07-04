---
name: linear-work
description: Work from existing Linear tickets for bug fixes, feature development, implementation tasks, or ticket-driven maintenance. Use when the user asks to fix, implement, develop, investigate, or complete work described in a Linear issue.
---

# Linear Work

Read and follow the shared contract in `workflow/skills/linear-work.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/linear-work.md`.
2. If missing, fall back to the deployed Codex workflow copy:
   `$CODEX_HOME/workflow/skills/linear-work.md`.
3. If this skill is loaded from a deployed or repo Codex skill directory, also
   check `../../workflow/skills/linear-work.md`.
4. If loaded from the Etabli repo target path, fall back to
   `../../../workflow/skills/linear-work.md`.
5. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/linear-work.md`.

Rules:
- Use Linear MCP as the source of truth.
- If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`.
- Never implement from a `DRAFT` or `CHALLENGED` plan.
