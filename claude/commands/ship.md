---
description: Deliver one task A to Z - plan, implement, review, commit, push, PR, CI green
argument-hint: [task description]
allowed-tools: [Read, Glob, Grep, Bash, Edit, MultiEdit, Write, AskUserQuestion, Task]
---

# Ship

User request: $ARGUMENTS

Follow the shared contract in `workflow/skills/ship.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/skills/ship.md`
   - `workflow/skills/worktree-isolation.md`
   - `workflow/skills/implementation-loop.md`
   - `workflow/skills/ci-fix.md`
   - `workflow/spec.md`
2. If missing, fall back to the Claude shared copies when this command is loaded through `~/.claude/commands`:
   - `../workflow/skills/ship.md`
   - `../workflow/skills/worktree-isolation.md`
   - `../workflow/skills/implementation-loop.md`
   - `../workflow/skills/ci-fix.md`
   - `../workflow/spec.md`
3. If those are unavailable, fall back to the Etabli repo copies when this command is loaded from the repo target path:
   - `../../workflow/skills/ship.md`
   - `../../workflow/skills/worktree-isolation.md`
   - `../../workflow/skills/implementation-loop.md`
   - `../../workflow/skills/ci-fix.md`
   - `../../workflow/spec.md`
4. If any fallback files exist, read them and continue. Do not tell the user the contract is missing.

Claude specifics:

- Isolation: use the native `EnterWorktree` / `ExitWorktree` tools when the
  runtime exposes them; otherwise `git worktree add ../<repo>-ship-<slug>
  -b <branch>` and `git worktree remove` at the end. Either way the
  preconditions, isolation rules, and cleanup reporting come from
  `workflow/skills/worktree-isolation.md`, and every later phase runs with the
  worktree as cwd.
- The autonomous chain phases are described in `/plan-implement`; reuse them
  verbatim, including the fresh-context reviewer subagent and the
  non-interactive cross-model adversary pass. Run that pass via `pi -p` when a
  non-Claude runner is available; when a machine-local rule disables it,
  substitute a fresh-context read-only Claude reviewer and record the pass as
  same-family, never as cross-model.
- Use `gh` for push status, PR creation, and CI checks.
- Explicit invocation of `/ship` is consent for the feature-branch push and PR
  creation only; every other human-checkpoint category still stops the run.
  Creating and removing the run's own worktree is part of that consent;
  touching a sibling worktree is not.
