# Discarded: Grok TUI surface hygiene — shrink plugin/skill catalog, enable memory, fix dead MCP, pin pstack models

## Metadata

- Discarded: 2026-08-28
- Source plan: `PLAN.md`
- Status: DISCARDED
- Reason: blocked-grok-plugin-gate
- Prior status: READY

## Note

Root PLAN.md was discarded because it did not match the current request.
This is not an implemented-plan archive.

## What was implemented before the block (verified live 2026-08-28)

- `~/.grok/config.toml`: memory on, marketplace auto-install off, plugins
  enabled `pstack` only, nine noise names disabled, paper MCP off.
- `~/.cursor/rules/pstack-models.mdc`: 18 roles, all `inherit-parent`.
- MEMORY.md herdr chantier corrected; standing poteto-mode sentence present
  there and in `~/.grok/agents/tonours.md`.
- Branch `chore/grok-surface-hygiene` (worktree `/private/tmp/etabli-grok-hygiene`)
  carries `9ac3e10` (brain server removed from etabli `.mcp.json`); **not
  merged into main**.

## Blocker

`grok inspect --json` still lists all nine Claude-compat noise plugins with
`enabled: true` after `[plugins].disabled` (re-verified 2026-08-28);
`grok plugin disable` returns `Plugin not found`. Blocked on Grok CLI
  behavior, not repo state.

## Resume path

1. After a Grok update, re-check `grok inspect --json`; if the disabled list
   is honored, all remaining checks pass.
2. Merge `chore/grok-surface-hygiene` into main (`.mcp.json` brain removal).
