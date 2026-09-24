# AGENTS.md — etabli

Repo-specific instructions for this dotfiles repo.

## Architecture

- `.github/workflows/` — CI workflows
- `claude/` — Claude Code commands and local instructions
- `docs/` — focused user docs
- `ghostty/` — Ghostty config
- `herdr/` — Herdr config, layouts, skills, multihost docs, etabli-obvault plugin
- `mcp/` — sanitized shared MCP server template (see `docs/mcp-strategy.md`); repo `.mcp.json` is empty
- `vendor/` — vendored upstream skills (`vendor/sources.tsv`; mattpocock is the shared pack, migrated to vendoring after the pstack port move)
- `skills-lock.json` — skill-tree integrity lock
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
- `scripts/` — installer, `deploy-agent-workflow`, and validation helpers
- `tests/` — smoke tests
- `tmux.conf` — tmux config
- `workflow/` — canonical workflow contract

## Symlink layout

Full layout, scopes and managed surfaces: `docs/symlink-layout.md`.

- do not create `~/.pi/extensions/`; it causes double-loading
- do not commit `pi/extensions/herdr-agent-state.ts` (installed/overwritten by `herdr integration install pi`)

## Workflow

- Human guide + schemas: `README.md` (docs consolidated there; see commit 9466974)
- Agent one-pager: `workflow/agent-quick-card.md`
- Canonical workflow map (open on demand; wins on conflict): `workflow/spec.md`
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
  canonical `obvault` knowledge base (MCP/skill `alambic-brain` in work scope,
  `alambic-obvault` in personal); do not wait for the user to mention it.
- Follow `workflow/skills/obvault-memory.md`; the vault root is resolved per
  scope (`workflow/runtime/obvault-topic-resolver.mjs`: work -> `~/work/brain`
  when present, else `~/work/obvault`; personal -> `~/work/obvault`); read the
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

## Git

Branch names and commit messages: `workflow/git-contract.md`.

- Branch: `<type>/<ticket-id>-<short-slug>`, slug 3 words max, whole name under
  50 characters.
- Commit: `<type>(<scope>): <description>`, subject only, no body, no trailers,
  lowercase imperative under 72 characters.
- Do not rewrite, amend, or force-push history unless explicitly requested.
