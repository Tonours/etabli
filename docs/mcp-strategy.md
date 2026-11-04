# MCP strategy

You get MCP servers documented by name, portable command and placeholder, and
nothing live: etabli deploys no MCP configuration and stores no credentials.
The repository's own `.mcp.json` is `{"mcpServers": {}}` on purpose.

## Ownership and scope

1. **Live configuration stays runtime-local.** Each runtime keeps its servers
   in its own store (Claude `~/.claude.json`, Pi `~/.pi/agent/mcp.json`) and
   declares only the servers it needs. Etabli never merges or overwrites those
   files, and no runtime imports another's scope.
2. **`mcp/servers.template.json` is sanitized reference data.** It holds
   `chrome-devtools`, `alambic-brain`, `alambic-obvault`, `datadog` and
   `linear`, with server names, portable commands, public endpoints and
   `${VAR}` placeholders only. Copy the one entry a runtime needs; never link
   the file wholesale.
3. **Memory vaults are served by the alambic engine.** `alambic-brain` serves
   `~/work/brain` and `alambic-obvault` serves `~/work/obvault`.
   `ALAMBIC_ROOT` pins the vault and `ALAMBIC_STATE_DIR` its state. The engine
   runs from the vault's own `_meta/` copy or from a `~/work/alambic` checkout.
   From the vault, `_meta/alambic setup --name <vault>` registers the MCP entry
   and the CLI shim. From the checkout, add `--mcp`, or no MCP entry is
   written, and `--vault <path>` on the first setup of a name, or the entry
   points at the checkout. Etabli deploys none of it, and a machine registers
   only the vaults it has checked out.
4. **The GitHub remote picks the vault, not the machine.** `OBVAULT_ROOT`,
   when set, overrides everything. Otherwise repos of an org listed in
   `~/.config/etabli/work-orgs` use `alambic-brain`, and every other project
   `alambic-obvault`. A missing, unreadable or invalid list means no vault at
   all, never a fallback to the personal one
   (`workflow/skills/obvault-memory.md`).
5. **No runtime-wide availability claim.** A skill that needs a server stops
   when its current runtime exposes no tools for it. One runtime's
   availability says nothing about another's.
6. **Project-specific MCP stays with the project**, in that repository's
   `.mcp.json` or native equivalent.
7. **Prefer CLIs when they are the source of truth.** GitHub uses `gh`, and
   each vault keeps its own local CLI and validator.

## Linear MCP gap

Linear commands stop with `LINEAR_MCP_UNAVAILABLE` when the runtime exposes no
Linear tools. Register the public endpoint `https://mcp.linear.app/mcp` (HTTP)
in that runtime's own store, then complete the OAuth flow the runtime offers
(Claude: `/mcp`). Datadog follows the same path from its `datadog` template
entry, and its authentication also stays with the runtime. No token goes in the
repo.

## Security boundary

Never commit or print OAuth material, API keys, auth headers, cookies, project
trust state or full live configuration. Placeholders such as `${HOME}` are
resolved only in local runtime config.

## Drift control

Inspect names only, never complete live files:

```bash
jq -r '.mcpServers | keys[]' "${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
jq -r '.mcpServers | keys[]' ~/.pi/agent/mcp.json
jq -r '.mcpServers | keys[]' .mcp.json mcp/servers.template.json
```

When a vault returns nothing, check its engine before blaming a skill
(`vault_health` through the MCP, or the vault's own validator).

When the intended server set changes, update the template and this guide
together, then run the repository secret scan with the published `origin/main`
as the trusted base:

```bash
.githooks/scan-secrets "$(git rev-parse origin/main)" "--all --full-history --diff-merges=first-parent"
```

The `.githooks/pre-push` hook and the `agentic-infra` CI job run the same
script.

> **Warning:** a mismatch between your live config and the template never
> authorizes copying a live file into Git. Live files hold tokens.

## What's next

[`SECURITY.md`](../SECURITY.md) § Secret-scan policy explains which
suppressions the scan honours.
