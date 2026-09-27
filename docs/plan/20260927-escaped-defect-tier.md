# Implemented: escaped defects and ship metrics carry the tier

## Metadata
- Archived: 2026-09-27
- Source plan: `PLAN.md` — Suite audit 4 — enregistrer le tier avec les défauts échappés et les métriques de ship, pour mesurer le taux de défauts échappés par tier
- Source plan SHA-256: `e6ae98607f9aead0af7b3b9ac0fca7d46dcbc759990928a7c429433962abb321`
- Status: IMPLEMENTED
- Commit / branch: `feat/escaped-defect-tier`, stacked on `docs/accepted-risks-tools` (base `7daebfb`); not pushed
- Workflow initiative: `escaped-tier` (completed at F1)

## Outcome
- The measured population is ship runs: one row per run in `.workflow/ship-metrics/<run-slug>.json`. Rate per tier = Σ `escaped_later` / number of rows, per `tier`; `unknown` rows are reported apart, and runs without ship are outside the population.
- `scripts/workflow-ship-metrics` validates an optional `tier` (`small`, `standard`, `high-risk`, `unknown`).
  - An absent tier is accepted.
  - An explicit `null` or any other value is refused, leaving the row unchanged or not created.
  - Once set, the tier cannot change, except to replace `unknown`.
  - Rows without a tier stay valid.
- `workflow/templates/escaped-defect.md` gains `tier`: the recorded tier of the reviewed change, or `unknown` when no reliable source gives one.
- `workflow/skills/ship.md` step 12 lists `tier` in the row schema. It is set at the first upsert from the plan or archive `Tier` (or the report `tier:`), else `unknown`; afterwards only `unknown` may be replaced.
- `workflow/self-improvement/review-metrics.md` defines the rate in prose; the 5-column table is unchanged.

## Context
- No data exists yet: 0 escaped-defect records, no registry, no `Tier` line in the archives. This suite ships the instrumentation, not a join.

## Decisions
### Registry rows as the only population
- Context: plan pass R1 showed that archived runs are not reviewed units, and that small runs have no archive.
- Choice: the ship registry carries both `escaped_later` and `tier`.
- Rejected options: a tier in plan archives as the denominator, a `tier` column in the public table (step 15 format, pin, generated-records schema check).

### Set-once tier
- Context: T1 Logic showed that a later upsert could reclassify a row and silently move its `escaped_later` to another tier.
- Choice: refuse any change once set, except replacing `unknown`.

## Accepted Drift
- None

## Validation Evidence
- command: `bash tests/ship-order-smoke.sh`
  - result: ok. The fixtures cover a valid tier stored; invalid and null tiers refused on a set row, a fresh row (no creation) and an `unknown` row (unchanged); reclassification refused; the same tier re-sent; `unknown` replaced. Removing the enum check or the set-once check each fails the smoke.
- command: `scripts/workflow-context-budget`, `scripts/workflow-ref-linter --target all`, `bash tests/workflow-docs-smoke.sh`
  - result: ok
- command: `scripts/verify-agentic-infra core` and `full`
  - result: 27/27 and 81/81
- Reviews:
  - Plan: 5 cross-family passes via `scripts/pi-review-hunter` (`openai-codex/gpt-6-astra`), the last one READY.
  - Code: T1 findings (set-once), T2 findings (masked fixtures), D1 clean, F1 clean (Logic GO, Spec GO, pi GO, capture `162859e8`).
