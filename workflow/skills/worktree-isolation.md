# Worktree Isolation Contract

Shared isolation rules for any route that mutates code on a dedicated branch.

Referenced by `workflow/skills/ship.md` and `workflow/skills/sec-pr.md`.
Runtime adapters may differ in the mechanics used to create and remove the
worktree. They must not weaken the preconditions, the isolation rules, or the
cleanup reporting rule.

## Preconditions

1. Confirm the base worktree is clean before creating or entering a dedicated
   worktree:

   ```bash
   git status --short
   ```

2. Stop if the base worktree has uncommitted or untracked changes that are not
   explicitly owned by this run.
3. Create or select exactly one worktree and branch for the run. Name the
   branch per `workflow/git-contract.md`: `<type>/<ticket-id>-<short-slug>`,
   slug 3 words max, whole name under 50 characters.
4. Record the worktree path, branch, and base SHA before the first edit.

## Isolation Rules

- One run, one worktree, one branch.
- Do not touch the default branch except for read-only comparison.
- Do not edit sibling worktrees.
- Do not borrow unstaged changes from the base worktree.
- Do not mix work for several targets in the same branch or worktree.
- The root `PLAN.md` of a run lives in that run's worktree. Never read or write
  another worktree's `PLAN.md`.

## Environment Boundary

A worktree isolates tracked files, not the machine. Before running builds,
servers, or end-to-end checks inside a dedicated worktree, confirm that
dependencies are installed for that worktree and that any fixed port, database,
or external fixture the checks need is not already held by another run. Stop as
`blocked` on contention rather than reusing a sibling run's environment.

## Cleanup

Remove the worktree explicitly when the run ends, including on error. If it is
kept, the final report names the path and the reason.
