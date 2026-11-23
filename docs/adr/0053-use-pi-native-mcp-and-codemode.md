---
status: accepted
date: 2026-11-23
tags: [pi, mcp, codemode, settings]
affected_components: [pi/agent/settings.json, scripts/lib/pi-agent-settings-sync.mjs, scripts/deploy-agent-workflow, docs/mcp-strategy.md, docs/symlink-layout.md]
---

# Use Pi native MCP and codemode by default

Pi now runs with its built-in `builtin:mcp` and `builtin:codemode` extensions instead of the third-party `npm:pi-mcp-adapter@5.2.0` package, and `pi/agent/settings.json` tracks `"defaultTools": ["+codemode"]` (keeping `codemode.mode` at its default `"on"`).

The earlier hold recorded in `docs/plan/20261021-research-alignment.md` (R4) kept `pi-mcp-adapter` because older Pi lacked project MCP config, OAuth, and per-tool exposure controls, and the adapter had written `"-builtin:mcp"` into local Pi settings. Pi 1.5.0+ (pinned in `pi/package.json`) natively provides `~/.pi/agent/mcp.json`, project `.pi/mcp.json` (gated on project trust), OAuth (`~/.pi/agent/mcp-auth.json` via `/mcp login`), per-server/per-tool `exposure` and `toolExposure`, and QuickJS `codemode` whose nested tool calls still run `pi.on("tool_call", ...)` guards (`no-comments.ts`, `pr-body.ts`). Deleting the redundant third-party adapter removes a duplicate MCP layer while giving Pi scripts parallel `bash`/`read`/MCP composition and local output filtering.

`scripts/lib/pi-agent-settings-sync.mjs` retires `npm:pi-mcp-adapter` (pinned or unpinned), strips stale exact `"-builtin:mcp"` entries from local `extensions` in the same run that removes `npm:pi-mcp-adapter` (preserving all other entries such as `"+builtin:mcp"` and custom paths, deleting `extensions` when emptied, and honoring any later deliberate `"-builtin:mcp"` opt-out written by `pi config`), and merges tracked additive `defaultTools` (`+tool`) into unset, delta, or non-empty plain allowlists without overwriting local custom tools, explicit `"-codemode"` opt-outs, existing `"codemode"` entries, or an explicit empty `[]` allowlist (which disables all built-in tools in Pi). Both local and tracked touched keys fail closed on invalid JSON shapes before any backup or write. An optional `check` mode lets `scripts/deploy-agent-workflow --check` report Pi settings drift (including missing files and pending symlink detachments) read-only without calling `seedPiSettings`.

Rejected: switching `codemode.mode` to `"only"` (hides direct tools and `load_workflow_tools` behind JS on `zai/glm-5.3` before usage is measured), and automating live MCP file migration (`~/.pi/agent/mcp-adapter.json`, Keychain OAuth, or project `.mcp.json` -> `.pi/mcp.json`) because live MCP config and credentials stay outside Etabli automation (`docs/mcp-strategy.md`).

## Consequences

- Hosts with servers defined only in `~/.pi/agent/mcp-adapter.json` or project `.mcp.json`, or authenticated via adapter Keychain OAuth, need a one-time manual copy into `~/.pi/agent/mcp.json` or `.pi/mcp.json` (plus Pi project trust) and `/mcp login`.
- Review date: 2026-12-23. Check Pi session transcripts after 30 days; if `codemode` goes unused on `zai/glm-5.3`, remove `"+codemode"` from `pi/agent/settings.json` and either drop it from deployed hosts' local `~/.pi/agent/settings.json` or add an explicit retirement step in `scripts/lib/pi-agent-settings-sync.mjs` (the additive merge alone preserves existing local entries), while keeping native `builtin:mcp`.
