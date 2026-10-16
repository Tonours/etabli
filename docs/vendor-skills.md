# Vendored skill suites

Three upstream suites feed etabli's managed skill surface. All ship
verbatim (`vendor/<name>/skills/**`); adaptation lives here, never in the
vendored files.

| Suite | Upstream | Scope | Skills |
| --- | --- | --- | --- |
| mattpocock (Matt Pocock) | `mattpocock/skills` @ `skills/engineering/` | shared | 7 (below) |
| petergyang | `petergyang/no-ai-slop` | `skill-surface.tsv` row `0 1`; `user-invocable-only` on Claude | 1 (`no-ai-slop`) |
| typesafe-ai | `typesafe-ai/skills` | shared, `user-invocable-only` on Claude | 1 (`typesafe-ai`) |

## mattpocock engineering tier (7)

`codebase-design`, `domain-modeling`, `grill-with-docs`,
`improve-codebase-architecture`, `prototype`, `research`, `wizard`.

Pruned 2026-10-16 (ADR-0033): `ask-matt`, `diagnosing-bugs`,
`resolving-merge-conflicts`, `to-spec`, `to-tickets`, `triage`, `wayfinder`.

### Skipped on purpose — name collisions (one canonical owner per name)

- `engineering/code-review` → etabli's `review` route (`workflow/skills/review.md`) stays canonical.
- `engineering/implement` → etabli's `implement` stays canonical.
- `engineering/setup-matt-pocock-skills` → configures the suite's own
  installer conventions (issue tracker, triage labels, doc layout); etabli's
  vendoring replaces that setup, so the skill has no target here.

### Degradation under etabli

- Suite-internal references to skipped or pruned names resolve to the etabli
  equivalents — same intent, different prose.
- The suite assumes its own repo conventions where etabli has Linear +
  `workflow/`; skills degrade to the local contract.
- `research` delegates reading to a background agent — parent-only Pi
  degrades it to sequential reads in the main thread.

## Research dispatch — which surface answers which need

| Need | Surface | Why |
| --- | --- | --- |
| Investigate a topic against external primary sources, leave a cited file in the repo | mattpocock `research` | background-agent reading legwork; pairs with `grill-with-docs` |
| Source-grounded repo research under the etabli contract | `workflow/skills/investigation.md` route + `scripts/research-proof-check` | the ambient contract stays canonical |

Overlap rule: the etabli routes own gating and evidence; the vendored
skills are task-level entry points invoked explicitly or when a runtime
exposes them.

## Update procedure

- Refresh from upstream: `scripts/update-vendor-skills [--commit] [vendor]`.
  It syncs, refreshes `skills-lock.json`, runs the skill checks, and prints
  each moved vendor with its GitHub compare link. See `vendor/README.md`.
- Add or drop a skill: edit `vendor/sources.tsv` (skills list; optional
  `subpath` column) and the `workflow/runtime/skill-surface.tsv` rows, then
  run the same command.
