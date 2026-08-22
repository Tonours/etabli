---
name: bug-check
description: Analyze a bug from a Linear issue with adversarial root-cause rigor. Use when the user asks to analyze, investigate, diagnose, or understand a bug from a Linear URL or issue key without implementing the fix.
---

# bug-check

Follow the shared contract in `workflow/skills/bug-check.md`.

On Claude, read the Linear issue through the available Linear MCP tools
(`get_issue`, comments, attachments). Stop with `LINEAR_MCP_UNAVAILABLE` if
they cannot run.

Rules:
- Read-only. No `PLAN.md`, no file edits, no Linear comments, no implementation.
