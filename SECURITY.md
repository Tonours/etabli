# Security and public-repo hygiene

You can push this public repository without leaking a credential as long as
every live secret stays out of its history and out of the tracked tree.

## What stays local

| Surface | Location | Notes |
|---------|----------|--------|
| MCP OAuth and API tokens | `~/.claude.json`, shell env | Template only: `mcp/servers.template.json` with `${VAR}` |
| Provider API keys | shell or host secret store | Not in tracked config |
| Copilot and editor auth DBs | `github-copilot/`, `*.db` | Gitignored |
| Workflow runtime state | `.workflow/`, `.pi/` | Gitignored |
| Private settings overlays | `*.local.json`, `settings.local.json` | Gitignored |

## Before every push

- No `.env`, `*.pem`, real `Bearer` tokens, or `ghp_`, `github_pat_` or
  `sk-ant-` values in tracked files.
- MCP stays sanitized: only `mcp/servers.template.json` placeholders, and the
  repo `.mcp.json` stays empty ([`docs/mcp-strategy.md`](docs/mcp-strategy.md)).
- Production tokens never go in `scripts/` or CI YAML. Use GitHub Actions
  secrets if CI ever needs one.

## Secret-scan policy

CI and the pre-push hook both run `.githooks/scan-secrets`: an isolated bare
Git mirror, explicit built-in gitleaks rules, and `--ignore-gitleaks-allow`.
Candidate `.gitleaksignore`, `.gitleaks.toml` and inline allow comments cannot
suppress findings. The checkout and its files stay untouched.

The pre-push hook is active once `scripts/install.sh` sets
`core.hooksPath=.githooks`. It blocks the push when gitleaks is not installed.
CI pins gitleaks by version and checksum, pins every action by SHA, and runs
with `contents: read`.

Only `.gitleaksignore` from the trusted base applies: the PR base SHA in CI,
the previous main SHA on a main push, or the advertised remote commit for an
existing pushed ref. Initial scans and new refs without a trusted base apply no
suppressions. When the remote commit of a pushed ref is missing locally, the
pre-push hook scans the whole pushed history with no suppressions. Called
directly, `.githooks/scan-secrets` fails closed on a base it cannot find, so
fetch it and retry.

> **Warning:** a false-positive fingerprint added in the same push as the
> secret does not unblock that push. It has to reach the trusted base through
> review first. Workflow and scanner changes also need trusted branch review.

## Reporting

If you find a credential in this repository, revoke or rotate it at the
provider first, then open an issue or contact the maintainer.
