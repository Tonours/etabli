---
name: linear-work
description: Work from an existing Linear issue through its acceptance criteria. Use when starting or continuing ticketed work; not for creating tickets, deploying, releasing, or unticketed exploration.
---
<!-- GENERATED:adapter-sync:start -->
skill: linear-work
harness: pi
canonical: workflow/skills/linear-work.md
name: linear-work
description: Work from an existing Linear issue through its acceptance criteria. Use when starting or continuing ticketed work; not for creating tickets, deploying, releasing, or unticketed exploration.
pointer: Adapter for the `linear-work` skill. Read and follow the shared contract in `workflow/skills/linear-work.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Linear Work

Read and follow the shared contract in `workflow/skills/linear-work.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use Linear MCP as the source of truth.
- If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`.
- Never implement from a `DRAFT` or `CHALLENGED` plan.
