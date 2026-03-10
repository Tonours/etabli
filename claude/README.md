# Claude

This folder contains Claude Code-specific artifacts and documents.

## Commands

- `commands/plan-create.md` is the tracked source for `/plan` and creates or refreshes `PLAN.md` from `PLAN_TEMPLATE.md` with `Status: DRAFT`
- `commands/plan-review.md` reviews `PLAN.md`, hardens it in place, and marks it `CHALLENGED` or `READY`
- `commands/plan-loop.md` chains `plan` then `plan-review` in a single interactive loop
- `commands/plan-implement.md` runs `plan-loop`, stops on `CHALLENGED`, and implements only from a `READY` `PLAN.md`

`verify` is no longer part of this workflow.

Because `PLAN.md` is gitignored and macOS filesystems are often case-insensitive, the repo does not track `commands/plan.md` directly. Installation maps `commands/plan-create.md` to `~/.claude/commands/plan.md`.
