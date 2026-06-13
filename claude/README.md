# Claude

Claude Code-specific files for `etabli`.

## Installed surface

`scripts/install.sh` links:

- `CLAUDE.md` -> `~/.claude/CLAUDE.md`
- `../PLAN_TEMPLATE.md` -> `~/.claude/PLAN_TEMPLATE.md`
- `../PLAN_TEMPLATE_FULL.md` -> `~/.claude/PLAN_TEMPLATE_FULL.md`
- `../workflow/` -> `~/.claude/workflow`
- `commands/*.md` -> `~/.claude/commands/`
- selected shared docs from `../workflow/` -> `~/.claude/`

## Workflow

Canonical contract: `../workflow/spec.md`.

Claude commands are thin wrappers over that contract:

- `/plan` from `commands/plan-create.md`
- `/plan-loop`
- `/plan-implement`
- `/implement`
- `/review`

Rules:

- one execution artifact: `PLAN.md`
- implement only from `Status: READY`
- no `REVIEW.md`
- review with `../workflow/review-rubric.md`

## Notes

`commands/plan-create.md` installs as `/plan` because `PLAN.md` is gitignored and case-insensitive filesystems are common.
