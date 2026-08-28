# Security and public-repo hygiene

This repository is designed to be shareable. Live credentials never belong in
git history or the working tree that is pushed.

## What stays local (do not commit)

| Surface | Location | Notes |
|---------|----------|--------|
| MCP OAuth / API tokens | `~/.claude.json`, shell env | Template only: `mcp/servers.template.json` with `${VAR}` |
| Provider API keys | shell / host secret store | Not in tracked config |
| Copilot / editor auth DBs | `github-copilot/`, `*.db` | Gitignored |
| Workflow ledgers / runtime state | `.workflow/`, `.pi/` | Gitignored |
| Private settings overlays | `*.local.json`, `settings.local.json` | Gitignored |
| Optional local LLM weights | host only (not tracked) | Use `pi/models.local.example.json` as a starting point if needed |

## Before flipping the GitHub repo to public

1. **Working tree scan** — no `.env`, `*.pem`, real `Bearer` tokens, or `ghp_` / `github_pat_` / `sk-ant-` values in tracked files.
2. **MCP** — only `mcp/servers.template.json` (placeholders). Repo `.mcp.json`
   is empty on purpose. See `docs/mcp-strategy.md`.
3. **Install secrets** — never put production tokens in `scripts/` or CI YAML; use GitHub Actions secrets if needed later.
4. **Optional history review** — if you ever committed a real token (none expected), rotate it and rewrite history before going public.

## Reporting

If you find a credential in this repository, revoke/rotate it at the provider
first, then open an issue or contact the maintainer.
