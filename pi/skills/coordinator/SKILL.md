---
name: coordinator
description: Coordinate parallel worker sessions using worktrees, assign scoped tasks, and consolidate GO/BLOCK decisions before commit.
---

# Coordinator

Use this skill when orchestrating multiple Pi worker sessions for the same project.

## Objectives

1. Split work into independent slices.
2. Keep each slice in a dedicated worktree/branch.
3. Track status and risks per worker.
4. Merge only after verify + review are green.

## Setup

```bash
agent-fanout init
# edit ~/.local/state/pi-agentic/workers.md
agent-fanout run --tasks ~/.local/state/pi-agentic/workers.md
```

## Worker Task Rules

For each worker:
- one clear goal
- one branch
- explicit verify command set
- no hidden scope creep

## Coordination Protocol

For every worker result, capture:
- `workerId`
- `branch`
- `status`: `GO | BLOCK`
- `verify`: pass/fail
- `risks`: short bullet list
- `nextAction`

## Final Integration Checklist

1. Ensure each worker branch has `/skill:verify` and `/skill:review` complete.
2. Run cross-branch integration checks (API compatibility, migrations, shared contracts).
3. Resolve conflicts with minimal diffs.
4. Produce final verdict:
   - `GO` when ready to commit/merge
   - `BLOCK` with explicit blockers and owners

## Reporting Template

```md
## Worker <id>
- branch: <branch>
- status: GO|BLOCK
- verify: pass|fail
- risks:
  - ...
- next: ...
```
