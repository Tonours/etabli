---
description: Deliver one task A to Z - plan, implement, review, commit, push, PR, CI green
disable-model-invocation: true
argument-hint: [task description]
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion, Agent, Skill]
---

# Ship

User request: $ARGUMENTS

Follow the shared contract in `workflow/skills/ship.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Claude specifics:

- Skill selection: load the narrowest matching skill that Claude actually
  exposes, such as `frontend-css-ui-ux`,
  `ember-employer-suite` when the work scope is active, an exposed project
  skill, or a task-shaped one
  such as `bug-check`, `pr-qa`, or `sec-pr`. If none is exposed, use the route
  contract's local-source fallback. Name the skill(s) used, or `none`, in the
  handoff.
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
