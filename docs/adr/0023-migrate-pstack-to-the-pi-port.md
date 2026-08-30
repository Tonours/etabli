---
status: accepted
date: 2026-08-28
tags: [tooling, skills, pstack, policy, pi]
affected_components: [vendor/sources.tsv, workflow/runtime/skill-surface.tsv, docs/pstack-strategy.md, docs/vendor-skills.md, README.md]
---

# Migrate pstack to the @zenspc/pi-pstack port, Pi-only

## Context

ADR-0020/0021/0022 built a governed vendored pstack layer: 37 skills
synced from the canonical Cursor monorepo, catalog-flagged, lock-pinned,
path-adapted, deployed to Pi, Claude, and Codex. A comparison with
`@zenspc/pi-pstack` (v0.3.0, 249 downloads/month, MIT) showed the port
delivers what vendoring structurally cannot on Pi alone: real subagents
(`pi-subagents` peer — `poteto-agent`, `comment-sicko`, working
`arena`/`swarm` fan-out), a context-economy toggle (`/pstack off` hides ~40
skill descriptions), per-role model injection (`pstack/models.json`), and a
working `recall` against Pi session transcripts. The user compared both
approaches and directed the migration, explicitly deprioritizing
Claude/Codex pstack coverage for now.

## Decision

Uninstall the vendored pstack surface (manifest row, vendor tree, 37
catalog rows, live links on all three runtimes) and install
`@zenspc/pi-pstack` with its `pi-subagents` peer on Pi. The vendoring
mechanism itself (`sync-vendor-skills`, subpath support, the ADR-0022
adaptation table) stays — it serves the mattpocock suite and any future
adoption. This supersedes the pstack-specific deployment decisions of
ADR-0020/0021/0022; their governance rules (collision ownership, waves,
adaptation policy) remain in force for what is still vendored.

## Rejected alternatives

1. **Keep both** — the port loads its skills by the same names; running
   both duplicates descriptions and doubles catalog noise.
2. **Dormant vendor tree on disk** — stale lock surface; git history is
   the rollback.
3. **Stay vendored** — keeps multi-runtime coverage but forgoes subagents,
   the context toggle, model roles, and recall on the primary runtime;
   the user judged the trade not worth it.

## Consequences

- Pi gains the full 45-skill port with subagent fan-out; Claude and Codex
  lose pstack skills entirely (user-accepted; reversible by restoring the
  catalog rows and re-syncing).
- The port ships unreviewed extension code that injects a role table every
  turn — accepted risk, to be assessed during the user's test period.
- Port skills may self-trigger (no `disable-model-invocation`); `/pstack
  off` is the designed relief.
- The catalog drops to ~80 rows; the workflow-docs baselines have ample
  headroom.
- Ship contract references survive: `unslop` now arrives via the port,
  `thermo-nuclear` and `write-direct` are etabli-native.
- Wave-4 deliberations (arena/swarm deferral) are superseded — the port
  ships them.

## Amendment (2026-08-30): install half shipped

The migration's install half is now repo-tracked instead of a manual
`pi install`:

- `pi/agent/settings.json` carries a bare `{ "source": "npm:@zenspc/pi-pstack" }`
  entry (loads all port resources) and `{ "source": "npm:pi-subagents",
  "skills": [] }` for the required peer (extension stays active for fan-out,
  its two prompt skills hidden).
- The standing context state is `/pstack off` (`skillsEnabled: false` in
  `~/.pi/agent/pstack/models.json`): port skill descriptions stay out of the
  system prompt while `/skill:<name>` keeps working — the designed relief,
  now pinned and asserted by `scripts/pi-skill-load-check` (fails when pstack
  entries render without the pin; budgets them out of the model-facing
  block only while it holds).
- `scripts/deploy-agent-workflow` and `install.sh` converge live settings
  through the shared `scripts/lib/pi-agent-settings-sync.mjs`; pi-subagents
  left the legacy purge list to keep the peer.
