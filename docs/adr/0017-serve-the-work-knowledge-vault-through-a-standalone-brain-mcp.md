---
status: accepted
date: 2026-08-17
tags: [mcp, work-scope, brain, obvault, claude, pi, codex]
affected_components: [mcp, docs/mcp-strategy.md, .mcp.json]
---

# Serve the work knowledge vault through a standalone brain MCP

`brain` (`~/work/brain`) is the work knowledge vault and is served by its own
vendored engine at `~/work/brain/_meta/mcp/server.mjs`. It depends on no other
vault checkout. The personal `obvault` vault keeps its own engine and is not
registered on a work machine.

The engine exposes four read-only tools — `vault_search`, `vault_context`,
`vault_read`, `vault_health` — with allowlisted `kb/` and `ref/` reads, opt-in
`docs/`, and refusals for traversal, `_meta/`, and `.git/`. Writes never go
through MCP; they stay behind the vault's own contract and `_meta/validate-kb.sh`.

`OBVAULT_ROOT` and `OBVAULT_ENGINE_PATH` keep their historical names so the
vault's existing smoke contract stays valid. They pin the served root, not the
vault's identity.

This extends ADR-0016 rather than replacing it: live MCP configuration stays
runtime-local, the tracked template stays sanitized reference data, and the
inventory stays deliberately asymmetric. ADR-0016's example server lists predate
`brain`; `docs/mcp-strategy.md` holds the current table.

Claude receives `brain` project-scoped through this repository's `.mcp.json`,
which requires a one-time user approval. Pi and Codex declare it in their own
user-scope stores. Grok still receives no MCP server.

## Considered options

- **Vendor the engine into `brain` (chosen).** Makes the work vault serve itself
  with no personal-vault dependency, which matches the work/personal split and
  survives `obvault` being absent, moved, or private.
- **Point `brain` at the `obvault` engine with `OBVAULT_ROOT` overridden.**
  Rejected: it made a work-scope surface depend on the personal vault, and the
  live wiring was already broken because it carried another machine's absolute
  paths.
- **Extract one shared engine into `etabli` consumed by both vaults.** Rejected
  for now: it removes duplication but couples the two vaults' release cadence and
  puts personal-vault retrieval logic in the work dotfiles repo.

## Consequences

- Good: the work vault answers with `obvault` absent; no personal path is read.
- Good: server identity is `brain`, so tool listings and error envelopes name the
  vault actually being served.
- Good: `_meta/mcp-smoke.test.sh` runs standalone and no longer probes a sibling
  checkout.
- Bad: the engine and its five libraries are duplicated between the two vaults.
  A future engine change must be applied twice, and no test detects the drift.
- Bad: `brain` now carries `package.json` and `node_modules`, so the vault needs
  an install step it did not need before.
