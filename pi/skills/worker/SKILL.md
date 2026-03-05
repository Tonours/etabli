---
name: worker
description: Execute one scoped implementation slice in a dedicated worktree, then run verify/review and return a concise GO/BLOCK report.
---

# Worker

Use this skill in a single worker session with one well-defined task.

## Constraints

- Stay within the assigned scope.
- Do not change unrelated files.
- Prefer minimal, reversible diffs.
- Explicitly handle errors.

## Execution Flow

1. Confirm the assigned goal and branch.
2. Implement in small increments.
3. Run `/skill:verify`.
4. Run `/skill:review`.
5. Record decision in your response.

## Response Contract

Return this summary to the coordinator:

```md
status: GO|BLOCK
branch: <branch>
changes:
- ...
verify:
- pass|fail + command
risks:
- ...
```

## Escalation

If blocked by architecture, migrations, or unknown side effects:
- stop implementation
- record `BLOCK`
- provide the smallest reproducer and proposed next step
