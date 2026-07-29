# MCP Strategy

How Etabli consolidates Model Context Protocol configuration after the
2026-07-28 harness recenter (Pi + Claude only).

## Sources of truth

| Surface | Role | Tracked in git |
| --- | --- | --- |
| `mcp/servers.template.json` | Sanitized reference inventory of the shared server set (`${VAR}` placeholders) | yes |
| `~/.claude.json` `mcpServers` | Live user-scope server definitions, holds real tokens | no |
| `~/.pi/agent/mcp.json` | Pi entrypoint: `{ "mcpServers": {}, "imports": ["claude-code"] }` | no |
| Project `.mcp.json` | Project-scope servers for one repo, committable when sanitized | per project |

Rules:

1. **Claude user scope is the single definition store.** The seven shared
   servers (`chrome-devtools`, `mobbin`, `uidotsh`, `web-reader`,
   `web-search-prime`, `zai-mcp-server`, `zread`) live only in `~/.claude.json`.
2. **Pi imports, never duplicates.** `~/.pi/agent/mcp.json` keeps
   `mcpServers: {}` and `imports: ["claude-code"]`. A server that must be
   Pi-only is the documented exception, not the default.
3. **No secrets in this repo.** `mcp/servers.template.json` uses `${VAR}`
   placeholders only. Live tokens stay in the local Claude config or the shell
   environment.
4. **Project scope for project-specific servers.** Servers that only make
   sense inside one repo (for example `context7`, `next-devtools`,
   `playwright`) belong in that repo's `.mcp.json`, with `${VAR}`
   placeholders, one entry per project — not duplicated across user scope.
5. **Prefer CLIs where they exist.** GitHub work goes through `gh`, not a
   GitHub MCP server, unless explicitly overridden. obvault access is the CLI;
   the optional read-only stdio obvault MCP (`vault_*` tools) is opt-in per
   `workflow/skills/obvault-memory.md` and is never part of a managed config.
6. **`~/.agents` consumers read the CLI surfaces**, not MCP; nothing to deploy
   there.

## Linear MCP gap (option A — enable when needed)

`workflow/skills/linear-*.md` and the matching Pi/Claude skills **do not claim
Linear is preconfigured**. If no Linear MCP tool is available at runtime, they
must stop with `LINEAR_MCP_UNAVAILABLE` (never invent issues or use the REST API
with guessed tokens). Linear is intentionally absent from the template's active
set because OAuth and workspace choice are user actions.

### Enable Linear MCP (secret-free path)

1. Open Claude Code user MCP config (`~/.claude.json` → `mcpServers`).
2. Add this entry (no tokens in the repo; OAuth is handled by the host):

```json
"linear": {
  "type": "http",
  "url": "https://mcp.linear.app/mcp"
}
```

3. Restart Claude Code (or reload MCP servers) and complete the Linear OAuth
   consent for the target workspace when prompted by the host.
4. Confirm tools appear (e.g. list MCP tools / call a harmless Linear read).
5. Pi needs **zero extra config** if `~/.pi/agent/mcp.json` already has
   `"imports": ["claude-code"]` — it imports Claude user-scope servers.

Template reminder: `mcp/servers.template.json` → `$linear_gap`. Do not commit
OAuth tokens, API keys, or workspace secrets. To leave Linear disabled, keep
the entry absent; skills continue to degrade to `LINEAR_MCP_UNAVAILABLE`.

## Drift control

- Run `jq '.mcpServers | keys' ~/.claude.json` and diff against the template
  when the set changes; update the template in the same commit as the strategy
  doc if the inventory changes.
- Do not re-introduce per-harness MCP copies. Historical Codex/Kimi surfaces
  were removed in the 2026-07-28 recenter (see `docs/adr/0011-*.md`).
