# AGENTS.md — etabli

Repo-specific instructions for this dotfiles repo.

## Architecture

- `.github/workflows/` — CI workflows
- `claude/` — Claude Code commands and local instructions
- `docs/` — focused user docs
- `mcp/` — sanitized shared MCP server template (see `docs/mcp-strategy.md`); repo `.mcp.json` is empty
- `vendor/` — vendored upstream skills (`vendor/sources.tsv`; mattpocock is the shared pack, migrated to vendoring after the pstack port move)
- `skills-lock.json` — skill-tree integrity lock
- `workflow-scaffold/templates/` — deployable project workflow scaffold files
- `pi/` — Pi config, extensions, skills, themes
- `pi/extensions/` — Pi extensions
- `pi/extensions/lib/` — shared extension utilities
- `pi/extensions/__tests__/` — extension tests
- `pi/agent/settings.json` — Pi agent bootstrap settings
- `pi/settings.json` — Pi root settings
- `pi/models.json` — custom model definitions
- `pi/skills/` — local Pi skills
- `pi/themes/` — Pi themes
- `scripts/` — installer, `deploy-agent-workflow`, and validation helpers
- `tests/` — smoke tests
- [`dotfiles`](https://github.com/Tonours/dotfiles) — Neovim, Ghostty, tmux and Herdr config (separate repo)
- `workflow/` — canonical workflow contract

## Symlink layout

Full layout, scopes and managed surfaces: `docs/symlink-layout.md`.

- do not create `~/.pi/extensions/`; it causes double-loading
- do not commit `pi/extensions/herdr-agent-state.ts` (installed/overwritten by `herdr integration install pi`)

## Workflow

- Shared agent rules (code, review, git, memory, answers): `pi/AGENTS.md`
- Human guide + schemas: `README.md` (docs consolidated there; see commit 9466974)
- Agent one-pager: `workflow/agent-quick-card.md`
- Canonical workflow map (open on demand; wins on conflict): `workflow/spec.md`
- Long rules / commands: `workflow/contract-details.md`
- Default plan: `PLAN_TEMPLATE.md`
- Full plan for risky work: `PLAN_TEMPLATE_FULL.md`
- Review rubric: `workflow/review-rubric.md`
- Memory: consult the vault per `workflow/skills/obvault-memory.md` (work -> `~/work/brain`, else `~/work/obvault`).

## Code

- Keep extension files small and explicit.
- No broad refactor while changing unrelated config.

## Testing

```bash
scripts/verify-agentic-infra core
bun test pi/extensions/__tests__/
```

## Git

Branch names and commit messages: `workflow/git-contract.md` (summary in `pi/AGENTS.md`).
