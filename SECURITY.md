# Security and public-repo hygiene

This repository is public. Live credentials never belong in its history or in
the working tree that is pushed.

## What stays local (never commit)

| Surface | Location | Notes |
|---------|----------|--------|
| MCP OAuth / API tokens | `~/.claude.json`, shell env | Template only: `mcp/servers.template.json` with `${VAR}` |
| Provider API keys | shell / host secret store | Not in tracked config |
| Copilot / editor auth DBs | `github-copilot/`, `*.db` | Gitignored |
| Workflow runtime state | `.workflow/`, `.pi/` | Gitignored |
| Private settings overlays | `*.local.json`, `settings.local.json` | Gitignored |

## Before every push

- No `.env`, `*.pem`, real `Bearer` tokens, or `ghp_` / `github_pat_` /
  `sk-ant-` values in tracked files.
- MCP stays sanitized: only `mcp/servers.template.json` placeholders, and the
  repo `.mcp.json` stays empty (`docs/mcp-strategy.md`).
- Production tokens never go in `scripts/` or CI YAML; use GitHub Actions
  secrets if CI ever needs one.

## Reporting

If you find a credential in this repository, revoke or rotate it at the
provider first, then open an issue or contact the maintainer.
