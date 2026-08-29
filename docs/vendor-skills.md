# Vendored skill suites

Three upstream suites feed etabli's managed skill surface. All ship
verbatim (`vendor/<name>/skills/**`); adaptation lives here, never in the
vendored files.

| Suite | Upstream | Scope | Skills |
| --- | --- | --- | --- |
| pstack (Lauren Tan) | **migrated** to `@zenspc/pi-pstack` npm port (ADR-0023) | Pi via pi install | 45 — see `docs/pstack-strategy.md` |
| mattpocock (Matt Pocock) | `mattpocock/skills` @ `skills/engineering/` | shared | 14 (below) |
| ember-skills / adonisjs-skills | Tonours forks | work / personal | domain suites |

## mattpocock engineering tier (14)

`ask-matt` (router over the suite), `codebase-design`,
`diagnosing-bugs`, `domain-modeling`, `grill-with-docs`,
`improve-codebase-architecture`, `prototype`, `research`,
`resolving-merge-conflicts`, `to-spec`, `to-tickets`, `triage`,
`wayfinder`, `wizard`.

### Skipped on purpose — name collisions (one canonical owner per name)

- `engineering/code-review` → etabli's `code-review` stays canonical.
- `engineering/implement` → etabli's `implement` stays canonical.
- `engineering/tdd` → pstack's `tdd` stays canonical.
- `engineering/setup-matt-pocock-skills` → configures the suite's own
  installer conventions (issue tracker, triage labels, doc layout); etabli's
  vendoring replaces that setup, so the skill has no target here.

### Degradation under etabli

- Suite-internal references to the skipped names resolve to the etabli /
  pstack equivalents — same intent, different prose.
- The suite assumes its own repo conventions where etabli has Linear +
  `workflow/`; skills degrade to the local contract.
- `research` delegates reading to a background agent — parent-only Pi
  degrades it to sequential reads in the main thread.

## Research dispatch — which surface answers which need

Three research surfaces coexist; route by the question:

| Need | Surface | Why |
| --- | --- | --- |
| Investigate a topic against external primary sources, leave a cited file in the repo | mattpocock `research` (deploys as `research`) | background-agent reading legwork; pairs with `grill-with-docs` |
| How does this codebase subsystem work / ownership / layering | pstack `how` | runtime tracing, critique mode |
| Why was this built this way (history, intent) | pstack `why` | 7-category evidence via configured MCPs |
| Learn a concept using the current directory | pstack `teach` weaves how+why into one explanation; mattpocock `teach` uses the dir as a stateful workspace over sessions | two complementary takes on teaching |
| Source-grounded repo research under the etabli contract | `workflow/skills/investigation.md` route + `scripts/research-proof-check` | the ambient contract stays canonical |

Overlap rule: the etabli routes own gating and evidence; the vendored
skills are task-level entry points invoked explicitly or when a runtime
exposes them.

## Update procedure (all suites)

1. Edit `vendor/sources.tsv` (skills list; optional `subpath` column).
2. `scripts/sync-vendor-skills <name>` — fails closed on missing upstream
   skills or a dirty vendor tree; nested skill names (`engineering/foo`)
   are supported.
3. Review the diff, commit `vendor/<name>/**` with the new `UPSTREAM_SHA`.
4. Catalog rows + `cd pi && bun run update:skills-lock` when adding skills.
