---
status: accepted
date: 2026-09-15
tags: [mcp, lean-profile, benchmark, cleanup]
affected_components: [mcp/servers.template.json, claude/profiles, scripts/lib/claude-profile.mjs, scripts/lib/claude-bench-arms.mjs, docs/mcp-strategy.md, docs/adr/0016]
---

# Remove lean-ctx from every tracked surface

lean-ctx was uninstalled from this machine on 2026-09-11, but the repo kept carrying it: the sanitized MCP inventory, the lean Claude profile and its renderer, the benchmark tool surface, and two docs all still declared a binary that no longer exists. Those declarations are now removed rather than left disabled, so the tracked inventory matches what a runtime can actually start.

The alternative was keeping a disabled entry as documentation of the former setup. Rejected: an MCP entry pointing at ${HOME}/.local/bin/lean-ctx fails at launch with no useful error, and a template whose servers cannot start is worse than an absent one. The history stays readable through ADR-0016 and this record.

This does not supersede ADR-0016: recording a per-runtime MCP inventory remains the practice. Only the inventory's contents change.
