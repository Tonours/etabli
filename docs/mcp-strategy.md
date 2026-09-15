# MCP Strategy

How Etabli records the sanitized MCP inventory for the active `work` scope.
The repository documents portable names and endpoints; it does not deploy live
MCP configuration or credentials.

## Current work inventory

Verified from the tracked template and this repository's `.mcp.json` on
2026-08-28. Live user-scope names below match the last name-only inventory
(2026-08-17), except Claude project `.mcp.json`, which is now empty.

| Runtime | Live store | Active servers |
| --- | --- | --- |
| Claude | `~/.claude.json` → `mcpServers` | `chrome-devtools`, `brain` |
| Pi | `~/.pi/agent/mcp.json` → `mcpServers` | `brain` |
| Codex | `~/.codex/config.toml` → `mcp_servers.*` | `chrome-devtools`, `datadog`, `linear`, `brain` |
| Grok | Grok user configuration | none |

This repository's `.mcp.json` is `{"mcpServers": {}}` on purpose. A
project-scoped `brain` entry was dropped in `9ac3e10` after the local engine
failed to start from etabli. Claude, Pi, and Codex declare `brain` in their
own user-scope stores.

`mcp/servers.template.json` is the sanitized union plus this runtime assignment
matrix. It is reference data, not a file to symlink wholesale into each
runtime. Each runtime declares only the servers it needs; none imports another
runtime's complete user scope.

## Ownership and scope

1. **Live configuration stays runtime-local.** Claude, Pi, Codex, and Grok may
   use different native shapes and authentication flows. Etabli does not merge
   or overwrite those files.
2. **The tracked template is sanitized inventory.** It contains server names,
   portable commands, public endpoints, and environment-variable placeholders
   only.
3. **`work` means `shared + work`.** `chrome-devtools` is shared local tooling. The current Datadog and Linear endpoints are work-scoped and
   enabled only in Codex.
4. **No runtime-wide availability claim.** A skill that needs Linear must still
   stop with `LINEAR_MCP_UNAVAILABLE` when its current runtime exposes no Linear
   tools. The current public endpoint is `https://mcp.linear.app/mcp`; Codex
   availability does not imply Claude, Pi, or Grok availability.
5. **Project-specific MCP stays with the project.** Sanitized project servers
   belong in that repository's `.mcp.json` or native equivalent, not in this
   user-scope inventory. Etabli itself declares none.
6. **Prefer CLIs when they are the source of truth.** GitHub uses `gh`; each
   vault also keeps its bounded local CLI and validator.
7. **`brain` is the work knowledge vault, and it is standalone.** It serves
   `~/work/brain` through its own vendored engine at
   `~/work/brain/_meta/mcp/server.mjs`, with no dependency on the personal
   `obvault` checkout. It exposes four read-only tools (`vault_search`,
   `vault_context`, `vault_read`, `vault_health`); writes go through the vault's
   own contract, never through MCP. `OBVAULT_ROOT` keeps its historical name and
   pins the served vault root.
8. **The personal `obvault` MCP is out of scope here.** A work machine does not
   register it. Do not add it to this inventory or to any runtime store.

## Security boundary

Never commit or print OAuth material, API keys, auth headers, cookies, project
trust state, or full live configuration. `${HOME}` and other placeholders in
the template are resolved only in local runtime config.
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
jq -r '.mcpServers | keys[]' .mcp.json
jq -r '.mcpServers | keys[]' ~/.pi/agent/mcp.json
sed -n 's/^\[mcp_servers\.\([^]]*\)\]$/\1/p' ~/.codex/config.toml | tr -d '"'
grok mcp list --json | jq -r '.[].name'
jq -r '.runtimeAssignments | to_entries[] | "\(.key):\(.value | join(","))"' \
  mcp/servers.template.json
```

An empty `.mcp.json` key list is expected. Check that the `brain` engine
answers in the user-scope store before blaming a skill for empty recall:

```bash
cd ~/work/brain && _meta/mcp-smoke.test.sh && _meta/validate-kb.sh
```

When the intended name set changes, update the template, this table, and the
ownership ADR together. Validate JSON and run the repository secret scan. A
local mismatch alone does not authorize copying the live file into Git.
