# AGENTS.md — etabli

Repo-specific instructions for this dotfiles repo.

## Architecture

- `.github/workflows/` — CI workflows
- `claude/` — Claude Code commands and local instructions
- `codex/` — Codex organization, prompts, automations, hooks, and personal skills
- `docs/` — focused user docs
- `ghostty/` — Ghostty config
- `workflow-scaffold/templates/` — deployable project workflow scaffold files
- `nvim/` — Neovim config
- `pi/` — Pi config, extensions, skills, themes
- `pi/extensions/` — Pi extensions
- `pi/extensions/lib/` — shared extension utilities
- `pi/extensions/__tests__/` — extension tests
- `pi/agent/settings.json` — Pi agent bootstrap settings
- `pi/settings.json` — Pi root settings
- `pi/models.json` — custom model definitions
- `pi/skills/` — local Pi skills
- `pi/themes/` — Pi themes
- `scripts/` — installer and dev scripts
- `tests/` — smoke tests
- `tmux.conf` — tmux config
- `workflow/` — canonical workflow contract

## Symlink layout

- `~/.pi/agent/extensions/` -> `pi/extensions/`
- `~/.pi/agent/settings.json` stays local, bootstrapped from `pi/agent/settings.json`
- `~/.pi/agent/models.json` -> `pi/models.json`
- `~/.pi/agent/AGENTS.md` -> `pi/AGENTS.md`
- `~/.pi/settings.json` -> `pi/settings.json`
- `~/.pi/themes/` -> `pi/themes/`
- `~/.config/ghostty/config` -> `ghostty/config`
- `~/.codex/` receives managed Codex files via `scripts/deploy-codex --apply`
- do not create `~/.pi/extensions/`; it causes double-loading

## Workflow

- Canonical workflow: `workflow/spec.md`
- Default plan: `PLAN_TEMPLATE.md`
- Full plan for risky work: `PLAN_TEMPLATE_FULL.md`
- Review rubric: `workflow/review-rubric.md`
- Codex organization: `docs/codex-organization.md`
- Ambient activation: when a project contains `workflow/spec.md`, agents should
  use the Etabli workflow automatically. Users should not need to write "use the
  Etabli workflow" in ordinary prompts.
- Answer quality: `workflow/answer-quality.md`; use
  `scripts/answer-quality-check` for durable answer/research/handoff artifacts.
- Final answers: apply the live gate in `workflow/answer-quality.md`; answer
  the newest request, name unverified gaps, and do not promise a perfect score.

## Code

- TypeScript strict, no `any`, ES modules.
- Keep extension files small and explicit.
- No broad refactor while changing unrelated config.

## Testing

```bash
bash tests/codex-organization-smoke.sh
bun test pi/extensions/__tests__/
```

## Commit

`feat|fix|refactor|test|docs|chore(scope): description`
