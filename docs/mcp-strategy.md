# MCP Strategy

How Etabli records the sanitized MCP inventory for the active `work` scope.
The repository documents portable names and endpoints; it does not deploy live
MCP configuration or credentials.

## Current work inventory

Verified from name-only local introspection on 2026-08-12:

| Runtime | Live store | Active servers |
| --- | --- | --- |
| Claude | `~/.claude.json` → `mcpServers` | `chrome-devtools`, `lean-ctx` |
| Pi | `~/.pi/agent/mcp.json` → `mcpServers` | `lean-ctx` |
| Codex | `~/.codex/config.toml` → `mcp_servers.*` | `chrome-devtools`, `lean-ctx`, `datadog`, `linear` |
| Grok | Grok user configuration | none |

`mcp/servers.template.json` is the sanitized union plus this runtime assignment
matrix. It is reference data, not a file to symlink wholesale into each
runtime. In particular, Pi's direct `lean-ctx` definition is intentional; it no
longer imports the complete Claude user scope.

## Ownership and scope

1. **Live configuration stays runtime-local.** Claude, Pi, Codex, and Grok may
   use different native shapes and authentication flows. Etabli does not merge
   or overwrite those files.
2. **The tracked template is sanitized inventory.** It contains server names,
   portable commands, public endpoints, and environment-variable placeholders
   only.
3. **`work` means `shared + work`.** `chrome-devtools` and `lean-ctx` are shared
   local tooling. The current Datadog and Linear endpoints are work-scoped and
   enabled only in Codex.
4. **No runtime-wide availability claim.** A skill that needs Linear must still
   stop with `LINEAR_MCP_UNAVAILABLE` when its current runtime exposes no Linear
   tools. The current public endpoint is `https://mcp.linear.app/mcp`; Codex
   availability does not imply Claude, Pi, or Grok availability.
5. **Project-specific MCP stays with the project.** Sanitized project servers
   belong in that repository's `.mcp.json` or native equivalent, not in this
   user-scope inventory.
6. **Prefer CLIs when they are the source of truth.** GitHub uses `gh`; obvault
   uses its bounded local CLI. The optional read-only obvault MCP remains
   opt-in and is not part of this inventory.

## Security boundary

Never commit or print OAuth material, API keys, auth headers, cookies, project
trust state, or full live configuration. `${HOME}`, `${LEAN_CTX_DATA_DIR}`, and
other placeholders in the template are resolved only in local runtime config.
Datadog and Linear authentication remains runtime-managed.

The following stay local and untracked:

- `~/.claude.json` beyond name-only inspection;
- `~/.pi/agent/mcp.json`;
- `~/.codex/config.toml`;
- Grok's user configuration, auth, session, and plugin state.

## Drift control

Inspect names only; do not dump complete live files:

```bash
jq -r '.mcpServers | keys[]' ~/.claude.json
jq -r '.mcpServers | keys[]' ~/.pi/agent/mcp.json
sed -n 's/^\[mcp_servers\.\([^]]*\)\]$/\1/p' ~/.codex/config.toml | tr -d '"'
grok mcp list --json | jq -r '.[].name'
jq -r '.runtimeAssignments | to_entries[] | "\(.key):\(.value | join(","))"' \
  mcp/servers.template.json
```

When the intended name set changes, update the template, this table, and the
ownership ADR together. Validate JSON and run the repository secret scan. A
local mismatch alone does not authorize copying the live file into Git.
