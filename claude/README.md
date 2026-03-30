# Claude

This folder contains Claude Code-specific artifacts and documents.

## Shared workflow

Canonical sources:
- `../workflow/spec.md`
- `../workflow/operating-model.md`
- `../workflow/statuses.md`
- `../workflow/review-rubric.md`
- `../workflow/handoff-template.md`
- `../profiles/README.md`
- `../docs/profiles.md`
- `../memory/projects/README.md`

Default flow across Pi + Claude:

- learn
- phase-0 measure
- plan
- implement
- review
- handoff

Shared contract reminders:
- `PLAN.md` is the single execution contract across Claude and Pi
- the measurement contract, execution slices, implementation tracking, and review checkpoints all live inside `PLAN.md`
- implementation starts only from `READY`
- daily execution modes (`simple`, `standard`, `option-compare`) live in `../workflow/operating-model.md`

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

- `~/.claude/review-rubric.md` is installed from `../workflow/review-rubric.md`
- `~/.claude/handoff-template.md` is installed from `../workflow/handoff-template.md`
- `claude/review-rubric.md` and `claude/handoff-template.md` stay only as compatibility pointers inside the repo

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
- `scripts/cw-mode <simple|standard|option-compare> <repo|path> "<task>"`
- `source scripts/cw-mode-aliases.sh` for `cws`, `cwstd`, `cwcmp`, and `cwtmux`
- `cw-clean <repo> --yes` for batch cleanup

There is no separate `cw ui` command; `cw pick` is the lightweight UI entrypoint.

Because `PLAN.md` is gitignored and macOS filesystems are often case-insensitive, the repo does not track `commands/plan.md` directly. Installation maps `commands/plan-create.md` to `~/.claude/commands/plan.md`.

## Profile fit

- `../profiles/work/` is the default fit for Claude work-facing usage.
- `../docs/profiles.md` is the user-facing guide for choosing between `personal` and `work`.
- The workflow contract stays shared; profiles do not define a different status model.

## Deferred after Phase 1

- `scripts/doctor`
- workflow test / CI hardening
- repo modularity split (`core` / `optional` / `legacy` / `experimental`)
- `workflow/roles.md`
