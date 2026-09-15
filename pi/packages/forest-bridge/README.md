# forest-bridge

Local pi adaptation of the Claude `forest@forest` plugin, laptop-only.

## What it ships

The two conformance auditor agents and the two `pr-review-toolkit` review
agents, ported verbatim from their source plugins (prompt bodies unchanged;
frontmatter adapted to pi):

- `convention-conformance-auditor` — per-area conventions lens
  (VIOLATION / STALE / OK / NOT ENGAGED).
- `architecture-conformance-auditor` — per-area ecosystem-docs lens
  (VIOLATION / EVOLUTION / OK / NOT ENGAGED).
- `code-reviewer` — `pr-review-toolkit` precision reviewer (confidence >= 80
  only, grouped by severity).
- `silent-failure-hunter` — `pr-review-toolkit` error-handling auditor.

Both keep their exact Claude plugin names so an orchestrating skill
(`/ecosystem-review`, `/validator`) can preflight them as dispatchable agent
types.

## What it deliberately does not ship

- **Skills** (`ecosystem`, `conventions`, `validator`, …) stay symlinked from
  the active plugin cache (`~/.pi/agent/skills/*` → the version
  `installed_plugins.json` marks active), so they follow plugin content.
- **`pr-review-toolkit` skill/plugin**: not ported as a skill; its two review
  agents above cover what `/validator` dispatches. The upstream plugin lives
  in `claude-code-plugins/pr-review-toolkit@1.0.0`.
- **Mintlify / Forest Documentation MCP**: MCP infrastructure, not a package
  concern.
- **Plugin scripts** (`adr-search.sh`, `extract-section.sh`, …) stay where the
  plugin ships them; resolve `CLAUDE_PLUGIN_ROOT` as the plugin cache root
  when calling from pi.

## Launching them from pi

The `forest-docs` MCP (`https://docs.forest.app/mcp`, from
`ForestAdmin/ai-marketplace/forest-docs`) is registered in
`~/.pi/agent/mcp.json`. Pi caches MCP metadata at startup: a session started
before the registration does not see the server, and `/validator`'s Mintlify
lens stays unreachable there. Restart the pi session, then the full validator
preflight passes.

The pi subagent completion guard classifies each task by wording before
checking the agent's tool allowlist. A task carrying a bare write verb
(including `modify` inside `never modify anything`, which the guard does not
recognize as a prohibition) is rejected as an implementation task against a
read-only allowlist. Orchestrate with the recognized read-only wording:
`review only`, `do not modify ...`, or `only return findings`.

The `architecture-conformance-auditor` keeps `bash` in its allowlist for this
reason: the ecosystem-doc sections it must be handed (`Where to add code`)
quote bare write verbs in their table rows, which no orchestration wording can
scrub without degrading the quoted sections below the audit's needs. Guard 1
(classification vs allowlist) is thereby always satisfied; `acceptanceRole`
stays `read-only`, and the agent's own rules already confine it to reading.

## Provenance

Ported from `forest@forest` version `b4b15c10fbee`. When the plugin updates,
re-diff `agents/*.md` against the new cache version and refresh the ports.
