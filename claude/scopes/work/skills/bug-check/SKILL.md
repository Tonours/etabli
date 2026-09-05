---
name: bug-check
description: Diagnose a Linear bug from its URL or issue key with adversarial root-cause analysis; no implementation.
---

# bug-check

Follow the shared contract in `workflow/skills/bug-check.md`.

On Claude, read the Linear issue through the available Linear MCP tools
(`get_issue`, comments, attachments). Stop with `LINEAR_MCP_UNAVAILABLE` if
they cannot run.

Rules:
- Read-only. No `PLAN.md`, no file edits, no Linear comments, no implementation.
