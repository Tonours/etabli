# Codex Organization

Tracked Codex operating surface for this machine.

## Contents

- `AGENTS.md` - global Codex instructions.
- `config.managed.toml` - safe shared defaults; not a replacement for local `config.toml`.
- `hooks.json` - sanitized hook commands that use `$HOME`.
- `workflow/` - workflow triggers and ticket template.
- `prompts/` - reusable prompt entry points.
- `automations/` - sanitized automation templates and durable conventions.
- `thread-organization/` - deterministic thread organization source and docs.
- `skills/` - personal maintained skills, excluding system/bundled caches and dependencies.

## Local-only Surface

Keep these outside Git:

- `config.toml`
- `auth.json`
- SQLite databases and WAL/SHM files
- sessions, archived sessions, shell snapshots, logs, plugin caches
- `thread-organization/generated/`, backups, indexes, and last-run JSON
- raw thread IDs, titles, queues, and automation memories
- skill dependencies such as `node_modules/`

Use `scripts/audit-codex-organization` before deploying or adding new files here.
