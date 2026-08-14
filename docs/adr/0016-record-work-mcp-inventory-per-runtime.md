---
status: accepted
date: 2026-08-12
tags: [mcp, work-scope, codex, claude, pi, grok, security]
affected_components: [mcp, docs/mcp-strategy.md, scripts/deploy-agent-workflow]
---

# Record the work MCP inventory per runtime

Etabli records a sanitized, work-scoped MCP inventory with explicit runtime
assignments while keeping every live MCP configuration file local. The tracked
template contains only portable commands, public endpoints, and environment
variable placeholders. It is reference data and is not deployed wholesale.

The active setup is intentionally asymmetric: Claude exposes
`chrome-devtools` and `lean-ctx`; Pi exposes `lean-ctx` directly; Codex exposes
`chrome-devtools`, `lean-ctx`, `datadog`, and `linear`; Grok exposes none. A
server available in one runtime must not be assumed available in another.

This decision narrows and replaces only ADR-0011's MCP single-definition-store
claim. ADR-0011's removal of full Codex/Grok harness trees remains accepted, as
does ADR-0015's Codex skill-link-only managed surface. Etabli gains no Codex or
Grok config deployer and never tracks auth, trust, session, plugin, or project
state.

The related scope-convergence invariant is explicit: every runtime surface that
receives repo-managed vendor skill links must also participate in exact-target
cleanup when that vendor scope becomes inactive. Today those surfaces are Pi,
Claude, Codex, and Grok's shared `~/.agents` directory. Cleanup never follows
or canonicalizes a link before deciding ownership, so an equivalent-looking
external target remains user-owned.

## Considered options

- **Sanitized union plus runtime assignments (chosen).** Matches the working
  setup without copying secrets or pretending the native config formats are
  interchangeable.
- **Keep Claude as the single definition store.** Rejected because the live Pi
  setup no longer imports Claude and Codex has work-only Datadog/Linear entries.
- **Generate tracked files from live configuration.** Rejected because parsing
  and serializing complete user configs expands the secret and private-path
  boundary for little benefit. Name-only introspection is sufficient.
- **Restore tracked Codex/Grok harness trees.** Rejected by ADR-0011 and
  unnecessary for a reference inventory and managed skill links.

## Consequences

- Good: documentation can state exactly which runtime exposes which server.
- Good: `LINEAR_MCP_UNAVAILABLE` remains an honest runtime-specific fallback.
- Good: no deploy command can overwrite live MCP auth or user preferences.
- Bad: intended inventory changes require a manual, reviewed update across the
  template, strategy table, and ADR history.
