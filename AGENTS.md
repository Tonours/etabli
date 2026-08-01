# AGENTS.md — etabli

Repo-specific instructions for this dotfiles repo.

## Architecture

- `.github/workflows/` — CI workflows
- `claude/` — Claude Code commands and local instructions
- `docs/` — focused user docs
- `ghostty/` — Ghostty config
- `mcp/` — sanitized shared MCP server template (see `docs/mcp-strategy.md`)
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
- `~/.pi/agent/PLAN_TEMPLATE.md` / `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.pi/agent/workflow/` -> `workflow/`
- `~/.pi/settings.json` -> `pi/settings.json`
- `~/.pi/themes/` -> `pi/themes/`
- `~/.claude/PLAN_TEMPLATE.md` / `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.claude/workflow/` -> `workflow/`
- `~/.agents/PLAN_TEMPLATE.md` / `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.agents/workflow/` -> `workflow/`
- `~/.config/ghostty/config` -> `ghostty/config`
- do not create `~/.pi/extensions/`; it causes double-loading

## Workflow

- Human guide + schemas: `docs/workflow-guide.md`
- Agent one-pager: `workflow/agent-quick-card.md`
- Canonical workflow map: `workflow/spec.md`
- Long rules / commands: `workflow/contract-details.md`
- Default plan: `PLAN_TEMPLATE.md`
- Full plan for risky work: `PLAN_TEMPLATE_FULL.md`
- Review rubric: `workflow/review-rubric.md`
- Ambient activation: when a project contains `workflow/spec.md`, agents should
  use the Etabli workflow automatically. Users should not need to write "use the
  Etabli workflow" in ordinary prompts.
- Final answers: apply the live gate in `workflow/answer-quality.md` (answer
  the newest request, name unverified gaps, do not promise a perfect score);
  use `scripts/answer-quality-check` only for durable artifacts.

## Knowledge Base

- Before answering or planning anything that depends on prior research,
  decisions, conventions, preferences, or recurring incidents, consult the
  canonical `obvault` knowledge base; do not wait for the user to mention it.
- Follow `workflow/skills/obvault-memory.md` with `~/work/obvault`; read the
  vault `AGENTS.md` entrypoint before querying or proposing a durable write.

## Code

- TypeScript strict, no `any`, ES modules.
- Keep extension files small and explicit.
- No broad refactor while changing unrelated config.

## Testing

```bash
scripts/verify-agentic-infra core
bun test pi/extensions/__tests__/
```

## Commit

`feat|fix|refactor|test|docs|chore(scope): description`

Commit messages are short, a single line max, no body: subject only in the
conventional-commit format above. Keep the subject under ~72 characters.
Do not rewrite, amend, or force-push history unless explicitly requested.
