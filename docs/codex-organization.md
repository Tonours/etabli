# Codex Organization

Etabli now tracks the durable Codex organization surface under `codex/`.

## Source of Truth

- `codex/AGENTS.md`: global Codex behavior and workflow rules.
- `codex/config.managed.toml`: non-secret shared defaults only.
- `codex/hooks.json`: hook events with `$HOME`-relative commands.
- `codex/workflow/`: dynamic workflow triggers and ticket template.
- `codex/prompts/`: reusable operational prompts.
- `codex/automations/`: sanitized automation templates and durable conventions.
- `codex/skills/`: personal maintained skills.

## Deployment

Preview the install:

```bash
scripts/deploy-codex --dry-run
```

Install into `~/.codex`:

```bash
scripts/deploy-codex --apply
```

The deploy script links tracked files into `~/.codex` and refuses to overwrite
conflicts unless `--force` is provided. It deploys `config.managed.toml` instead
of `config.toml`; merge settings manually when needed.

## Audit

Run:

```bash
scripts/audit-codex-organization
```

The audit rejects tracked runtime outputs, SQLite backups, generated thread
indexes, raw thread IDs, local absolute paths, local project trust state, hook
trusted hashes, and common credential patterns.

## Local-only Files

These stay outside Git:

- `~/.codex/config.toml`
- `~/.codex/auth.json`
- `~/.codex/*.sqlite*`
- `~/.codex/sessions/`, `archived_sessions/`, `shell_snapshots/`, `log/`
- `~/.codex/plugins/` and remote plugin caches
- raw automation memories and live automation definitions with local paths

The repository tracks conventions and reusable source, not live Codex state.
