# AGENTS.md — etabli

Repo-specific instructions for this dotfiles repo.

## Architecture

- `pi/extensions/` — Pi extensions
- `pi/extensions/lib/` — shared extension utilities
- `pi/extensions/__tests__/` — extension tests
- `pi/agent/settings.json` — Pi agent bootstrap settings
- `pi/settings.json` — Pi root settings
- `pi/models.json` — custom model definitions
- `pi/skills/` — local Pi skills
- `pi/themes/` — Pi themes
- `claude/` — Claude Code commands and local instructions
- `workflow/` — canonical workflow contract
- `ghostty/` — Ghostty config
- `scripts/` — installer and dev scripts

## Symlink layout

- `~/.pi/agent/extensions/` -> `pi/extensions/`
- `~/.pi/agent/settings.json` stays local, bootstrapped from `pi/agent/settings.json`
- `~/.pi/agent/models.json` -> `pi/models.json`
- `~/.pi/agent/AGENTS.md` -> `pi/AGENTS.md`
- `~/.pi/settings.json` -> `pi/settings.json`
- `~/.pi/themes/` -> `pi/themes/`
- `~/.config/ghostty/config` -> `ghostty/config`
- do not create `~/.pi/extensions/`; it causes double-loading

## Workflow

- Canonical workflow: `workflow/spec.md`
- Default plan: `PLAN_TEMPLATE.md`
- Full plan for risky work: `PLAN_TEMPLATE_FULL.md`
- Review rubric: `workflow/review-rubric.md`

## Code

- TypeScript strict, no `any`, ES modules.
- Keep extension files small and explicit.
- No broad refactor while changing unrelated config.

## Testing

```bash
bun test pi/extensions/__tests__/
```

## Commit

`feat|fix|refactor|test|docs|chore(scope): description`
