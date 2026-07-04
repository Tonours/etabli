---
name: linear-project-setup
description: Turn a tech spec into a Linear Project plus its prioritized Epics, following Forest's Project->Epic conventions. Use when the user asks to set up a Linear project from a spec, create a project with epics, or stand up the backlog for a new initiative.
---

# Linear Project Setup

Read and follow the shared contract in
`workflow/skills/linear-project-setup.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy:
   `workflow/skills/linear-project-setup.md`.
2. If missing, fall back to the Pi agent shared copy:
   `../../workflow/skills/linear-project-setup.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../../workflow/skills/linear-project-setup.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/linear-project-setup.md`.

Rules:
- Use Linear MCP only.
- Confirm with the user before creating the Project or any Epic.
- Use `linear-ticket-create` instead for one isolated ticket.
