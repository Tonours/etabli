# pstack strategy — migrated to the Pi port

How etabli consumes pstack (Lauren Tan's engineering skill set). History:
ADR-0020/0021/0022 built a vendored multi-runtime layer; ADR-0023 migrated
Pi to the `@zenspc/pi-pstack` npm port after comparing both — the port's
Pi-native advantages (subagents, context toggle, model roles, working
recall) outweighed Claude/Codex coverage, which the user deprioritized.

## Current state (since 2026-08-28)

- **Runtime**: `@zenspc/pi-pstack` 0.3.0 + `pi-subagents` peer, tracked in
  `pi/agent/settings.json` (bare pstack entry; pi-subagents entry with
  `skills: []` so its extension stays active for fan-out) and pushed to the
  live settings by `scripts/deploy-agent-workflow` through
  `scripts/lib/pi-agent-settings-sync.mjs`. 45 skills, `poteto-agent` and
  `comment-sicko` subagents, an extension, and the `orch`/`watch-pr`
  scripts (bun).
- **Claude / Codex**: no pstack skills (user decision; reversible —
  restore the catalog rows and vendor tree from git history per
  ADR-0023).
- The etabli vendoring mechanism stays (serves mattpocock); pstack rows
  are gone from `vendor/sources.tsv` and the catalog.

## Operating the port

- First run: `/setup-pstack` to pick per-role models (optional; roles
  inherit the parent session model otherwise). Config:
  `~/.pi/agent/pstack/models.json`.
- Context economy: `/pstack on|off|status` — `off` hides the ~40 pstack
  skill descriptions from the system prompt and persists; `/skill:<name>`
  keeps working. The repo pins `off` as the standing state
  (`skillsEnabled: false` in `~/.pi/agent/pstack/models.json`);
  `scripts/pi-skill-load-check` fails when pstack entries render without
  that pin in effect and budgets them out of the model-facing block only
  while it holds.
- Slash syntax is `/skill:<name>` (e.g. `/skill:poteto-mode`), not
  `/name`.
- Subagent fan-out (`arena`, `swarm`, `interrogate` panels, `no-comments`)
  requires the `pi-subagents` package — installed.
- `recall` reads Pi session transcripts (`$PI_SESSION_FILE`, grouped by
  cwd slug).
- Model-role injection happens every turn via the port's extension —
  accepted risk (ADR-0023), assess during real use.

## Etabli contract interactions

- The ambient workflow contract stays canonical; pstack skills are
  task-level entry points.
- `/ship` step 9's `unslop` reference resolves via the port on Pi.
- `/ship` phase 6's thermo-nuclear skill is etabli-native (`pi/skills`),
  unaffected.
- `/create-verification-skill` on the port writes to its own Pi-appropriate
  location (the port removed the `.cursor` paths at the source).

## History: the vendored waves (2026-08-28, same day)

Wave 1 (8 skills) → wave 2 (+poteto-mode, 21 principles) → wave 3 (+6
closing skills) → path adaptation (ADR-0022) → migration (ADR-0023). The
full lineage and the comparison that drove the migration live in the ADRs
and `docs/vendor-skills.md`.
