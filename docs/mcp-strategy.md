# MCP Strategy

Etabli documents MCP servers by name, portable command and placeholder. It
deploys no live MCP configuration and stores no credentials. The repository's
own `.mcp.json` is `{"mcpServers": {}}` on purpose.

## Ownership and scope

1. **Live configuration stays runtime-local.** Each runtime keeps its servers
   in its own store (Claude `~/.claude.json`, Pi `~/.pi/agent/mcp.json`) and
   declares only the servers it needs. Etabli never merges or overwrites those
   files, and no runtime imports another's scope.
2. **`mcp/servers.template.json` is sanitized reference data.** Server names,
   portable commands, public endpoints and `${VAR}` placeholders only. Copy the
   one entry a runtime needs; never link the file wholesale.
3. **Memory vaults are served by the alambic engine.** `alambic-brain` serves
   `~/work/brain` and `alambic-obvault` serves `~/work/obvault`;
   `ALAMBIC_ROOT` pins the vault and `ALAMBIC_STATE_DIR` its state. The engine
   runs from the vault's own `_meta/` copy or from a `~/work/alambic` checkout.
   From the vault, `_meta/alambic setup --name <vault>` registers the MCP entry
   and the CLI shim. From the checkout, add `--mcp`, or no MCP entry is
   written, and `--vault <path>` on the first setup of a name, or the entry
   points at the checkout. Etabli deploys none of it. The project's GitHub remote
   organization picks the vault, not the machine scope: repos of an org listed
   in `~/.config/etabli/work-orgs` use `alambic-brain`, every other project
   `alambic-obvault` (`workflow/skills/obvault-memory.md`). A machine registers
   only the vaults it has checked out.
4. **No runtime-wide availability claim.** A skill that needs a server stops
   when its current runtime exposes no tools for it; one runtime's
   availability says nothing about another's.
5. **Project-specific MCP stays with the project**, in that repository's
   `.mcp.json` or native equivalent.
6. **Prefer CLIs when they are the source of truth.** GitHub uses `gh`; each
   vault keeps its own local CLI and validator.

## Linear MCP gap

Linear commands stop with `LINEAR_MCP_UNAVAILABLE` when the runtime exposes no
Linear tools. To enable them, register the public endpoint
`https://mcp.linear.app/mcp` (HTTP) in that runtime's own store, then complete
the OAuth flow the runtime offers (Claude: `/mcp`). No token goes in the repo.

## Security boundary

Never commit or print OAuth material, API keys, auth headers, cookies, project
trust state or full live configuration. Placeholders such as `${HOME}` are
resolved only in local runtime config. Datadog and Linear authentication stays
runtime-managed.

## Drift control

Inspect names only; never dump complete live files:

```bash
jq -r '.mcpServers | keys[]' "${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
jq -r '.mcpServers | keys[]' ~/.pi/agent/mcp.json
jq -r '.mcpServers | keys[]' .mcp.json mcp/servers.template.json
```

When a vault returns nothing, check its engine before blaming a skill
(`vault_health` through the MCP, or the vault's own validator). When the
intended server set changes, update the template and this doc together and run
the repository secret scan:
`.githooks/scan-secrets "$(git rev-parse origin/main)" "--all --full-history --diff-merges=first-parent"`,
with the published `origin/main` as the trusted base for exclusions. The
`.githooks/pre-push` hook and the `agentic-infra` CI job run the same script
(`SECURITY.md` § Secret-scan policy). A local mismatch
alone never authorizes copying a live file into Git.
