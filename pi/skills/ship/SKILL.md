---
name: ship
description: Deliver one task A to Z - plan, implement, review, commit, push, PR, CI green.
disable-model-invocation: true
---

# Ship

Follow `workflow/spec.md` and the shared contract in `workflow/skills/ship.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Pi specifics:

- Skill selection: load the narrowest matching skill Pi actually exposes, such
  as `frontend-css-ui-ux`, an exposed project skill, or a task-shaped one such
  as `bug-check`, `pr-qa`, or `sec-pr`. If none is exposed, use the route
  contract's local-source fallback. Name the skill(s) used, or `none`, in the
  handoff.
- Isolation: Pi exposes no native worktree tool, so use
  `git worktree add ../<repo>-ship-<slug> -b <branch>` and `git worktree remove`
  at the end. Preconditions, isolation rules, and cleanup reporting come from
  `workflow/skills/worktree-isolation.md`; every later phase runs with the
  worktree as cwd.
- The autonomous chain phases are described in `plan-implement`; reuse them
  verbatim, including the fresh-context reviewer subagent and the
  non-interactive adversary pass. Resolve its model through the shared frontier
  policy and exclude the implementation author's effective family; merely
  running through Pi does not prove cross-model independence. Name
  `adversary_model` per `workflow/skills/adversary.md`.
- Use `gh` for push status, PR creation, and CI checks.

Rules:
- Explicit invocation is consent for the feature-branch push and PR creation
  only; every other human-checkpoint category still stops the run.
- Creating and removing the run's own worktree is part of that consent;
  touching a sibling worktree is not.
- Never plain `--force`.
- Do not create `REVIEW.md`.
- After focused checks, run implementation-loop 12b on this diff and record
  `simplify: clean` or `simplify: removed N`. Then run 12c (`code-quality` when
  exposed, else the narrowest domain skill or 1-3 local siblings). Record
  `quality: unavailable` and stop before completion if neither exists.
