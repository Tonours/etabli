# Codex Organization

Tracked Codex operating surface for this machine.

## Contents

- `AGENTS.md` - global Codex instructions.
- `config.managed.toml` - safe shared defaults; not a replacement for local `config.toml`.
- `hooks.json` - sanitized hook commands that use `$HOME`.
- `workflow/team-orchestration.md` - Codex-only automatic team configuration.
- `workflow/` - workflow triggers and ticket template.
- `prompts/` - reusable prompt entry points.
- `automations/` - sanitized automation templates and durable conventions.
- `skills/` - personal maintained skills, excluding system/bundled caches and dependencies.

`workflow/team-orchestration.md` is the sole Codex owner for activation,
models, context, sidecar behavior, messaging, write ownership, and council
fallback. `codex-dynamic-workflows` is its ambient execution adapter. Every
request is automatically classified as parent-only, scout, council, or
fresh-review; users do not need to invoke the skill or mention delegation.
Non-trivial eligible work with a useful independent packet receives a read-only
scout when the active runtime exposes a visible `collaboration` runner.
Otherwise the workflow honestly remains parent-only or falls back to simulated
`.workflow/<slug>/` packets when a durable run requires them.

## Local-only Surface

Keep these outside Git:

- `config.toml`
- `auth.json`
- SQLite databases and WAL/SHM files
- sessions, archived sessions, shell snapshots, logs, plugin caches
- raw thread IDs, titles, queues, and automation memories
- skill dependencies such as `node_modules/`

Use `scripts/audit-codex-organization` before deploying or adding new files here.
