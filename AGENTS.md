# AGENTS.md — etabli

Repo-specific instructions for this agent workflow repo.

## Architecture

- `.github/workflows/` — CI workflows
- `claude/` — Claude Code instructions, agents, hooks, scripts and settings fragments
- `docs/` — focused user docs
- `mcp/` — sanitized shared MCP server template (see `docs/mcp-strategy.md`); repo `.mcp.json` is empty
- `vendor/` — vendored upstream skills (`vendor/sources.tsv`; update with `scripts/update-vendor-skills`)
- `skills/<scope>/` — first-party skills served to both Claude and Pi (`workflow/runtime/skill-surface.tsv`)
- `skills-lock.json` — skill-tree integrity lock
- `workflow-scaffold/templates/` — deployable project workflow scaffold files
- `pi/` — Pi config, extensions, themes
- `pi/extensions/` — Pi extensions
- `pi/extensions/lib/` — shared extension utilities
- `pi/extensions/__tests__/` — extension tests
- `pi/agent/settings.json` — Pi agent bootstrap settings
- `pi/settings.json` — Pi root settings
- `pi/models.json` — custom model definitions
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

- Shared agent rules (code, review, git, memory, answers): `workflow/agent-rules.md`
- Human guide + schemas: `README.md`
- Workflow entry and canonical map (wins on conflict): `workflow/spec.md`
- Long rules / commands: `workflow/contract-details.md`
- Default plan: `PLAN_TEMPLATE.md`
- Full plan for risky work: `PLAN_TEMPLATE_FULL.md`
- Review rubric: `workflow/review-rubric.md`
- Memory: `~/work/brain` for ForestAdmin repos, `~/work/obvault` otherwise; see `workflow/skills/obvault-memory.md`.

## Growth

- Add a surface (skill, hook, script, extension, check) only for something used
  weekly; the ADR-0035 census set this bar.
- Measure first: a throwaway script of about 50 lines shows the need before any
  subsystem is built.
- A new subsystem's ADR records a review date; still unused at that date, it is
  deleted.
- When deleting and adding both fix a problem, delete.

## Code

- Keep extension files small and explicit.
- No broad refactor while changing unrelated config.

## Testing

```bash
scripts/verify-agentic-infra core
bun test pi/extensions/__tests__/
```

## Git

Branch names and commit messages: `workflow/git-contract.md` (summary in `workflow/agent-rules.md`).
