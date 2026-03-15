# Claude

This folder contains Claude Code-specific artifacts and documents.

## Shared workflow

Default flow across Pi + Claude:

- learn
- plan
- implement
- review
- handoff

## Commands

- `commands/plan-create.md` is the tracked source for `/plan` and creates or refreshes `PLAN.md` from `PLAN_TEMPLATE.md` with `Status: DRAFT`
- `commands/plan-review.md` reviews `PLAN.md`, hardens it in place, and marks it `CHALLENGED` or `READY`
- `commands/implement.md` is the direct continuation command after review and implements only from an existing `READY` `PLAN.md`
- `commands/plan-loop.md` chains `plan` then `plan-review` in a single interactive loop
- `commands/plan-implement.md` runs `plan-loop`, stops on `CHALLENGED`, and implements only from a `READY` `PLAN.md`
- `commands/review.md` runs a focused review against uncommitted changes, a branch diff, or a commit using the shared review rubric
- `commands/handoff.md` writes or refreshes `.pi/handoff.md` for session continuation using the shared handoff template
- `commands/handoff-implement.md` writes or refreshes `.pi/handoff-implement.md` for implementation continuation from an existing `READY` `PLAN.md`

## Shared docs

- `review-rubric.md` is the shared review source of truth used by Pi/Claude review flows
- `handoff-template.md` is the shared continuation template used by Pi/Claude handoff flows

`verify` is no longer part of this workflow.

## Repo worktree helper

The repo-native worktree/tmux helper lives at the root as `scripts/cw` with `scripts/cw-clean` for batch cleanup.

Preferred command surface:

- `cw new <repo> <task> [prefix]`
- `cw open <repo> [branch|path|name]`
- `cw ls <repo>`
- `cw attach <repo> [branch|path|name]`
- `cw merge <repo> [branch|path|name] --yes`
- `cw rm <repo> [branch|path|name] --yes`
- `cw pick <repo>` for the thin `fzf` / `fzf-tmux` UI
- `cw-clean <repo> --yes` for batch cleanup

There is no separate `cw ui` command; `cw pick` is the lightweight UI entrypoint.

Because `PLAN.md` is gitignored and macOS filesystems are often case-insensitive, the repo does not track `commands/plan.md` directly. Installation maps `commands/plan-create.md` to `~/.claude/commands/plan.md`.
