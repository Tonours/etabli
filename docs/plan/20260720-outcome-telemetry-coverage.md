# Implemented: Source-verified historical outcome telemetry

## Metadata

- Archived: 2026-07-20
- Source plan: Porter la couverture historique de télémétrie des outcomes à au
  moins 80 % sans données synthétiques
- Status: IMPLEMENTED LOCALLY
- Commit / branch: uncommitted worktree on `main` at baseline `44634326`
- External state: no commit, push, deploy, PR, or GitHub setting mutation
  performed by this run

## Outcome

- Raised actual historical token-usage coverage from 0/40 (0 %) to 37/40
  (92.5 %) on the fixed population
  `terminal-runs-v1-55c1fdc2120b99b9`.
- Made `tokens_per_successful_outcome` non-null from 35 source-verified
  successful historical outcomes while retaining three explicitly unmeasured
  runs whose ledger windows are under 60 seconds.
- Kept the former generic evidence visible: four historical outcomes carried a
  `measured:true` flag, but none had token totals and therefore none counted as
  baseline usage coverage.
- Added a local dry-run/apply extractor that persists only run slugs, hashes,
  timestamps, counts, and token/tool aggregates. It does not persist prompts,
  responses, reasoning, raw session IDs, session paths, or secrets.
- Preserved every historical terminal ledger unchanged. Population and import
  events live only in the current local append-only run ledger.

## Context

- `scripts/workflow-telemetry-recover`: scans only Codex session envelopes,
  cumulative token counters, user-message boundaries, and tool-call types.
- `scripts/workflow-measurement-integrity`: binds the population to current
  target ledger, terminal, outcome, and baseline-measurement fingerprints.
- `scripts/workflow-event` and `scripts/lib/workflow-event-detail.jq`: enforce
  strict population/import shapes, membership, uniqueness, and immutable
  target evidence.
- `scripts/workflow-metrics`: distinguishes native, recovered, legacy, and
  unmeasured outcomes and exposes `usage_measurement_coverage` independently
  from the generic measured flag.
- `.workflow/outcome-telemetry-coverage/events.jsonl`: local population,
  imports, review, validation, and completion evidence.

## Decisions

### Recover evidence without rewriting history

- Context: schema-v2 terminal ledgers cannot accept post-terminal events, and
  rewriting older ledgers would destroy their evidentiary value.
- Choice: pin the exact 40-run population in the current active ledger and add
  one separate import event per recoverable target.
- Rejected options: append to terminal ledgers, rewrite timestamps, treat
  missing values as zero, or change the denominator.
- Rationale: the overlay remains inspectable, reversible at aggregation time,
  and leaves historical source bytes unchanged.
- Consequences: 37 imports are stored locally; the three exclusions remain
  visible rather than being synthesized.

### Require conservative and exclusive token windows

- Context: cumulative session counters can over-attribute work when a run has
  no close baseline, a counter reset, an ambiguous enclosing session, a later
  user message, or an overlapping accepted slice.
- Choice: require a primary session that fully encloses the run, a run window
  of at least 60 seconds, a baseline no older than 120 seconds, a sample inside
  the window, a final sample within 120 seconds, monotone counters, no
  post-terminal user message before the final sample, and non-overlapping
  accepted token slices.
- Rejected options: nearest-session heuristics without bounds and proportional
  estimates from session totals.
- Rationale: every accepted aggregate is a direct counter delta with explicit
  temporal bounds.
- Consequences: short, missing, stale, reset, concurrent, or ambiguous evidence
  remains unmeasured with a machine-readable reason.

### Recompute sources before counting recovered usage

- Context: the first fresh review found that a structurally valid manual import
  could otherwise raise the KPI and that stale target fingerprints required a
  separate validation command to be noticed.
- Choice: `workflow-metrics` reruns the canonical extractor read-only and
  overlays only imports whose full detail exactly matches current local source
  evidence and the pinned manifest.
- Rejected options: trust event shape alone, trust an opaque import ID, or cache
  a verification result indefinitely.
- Rationale: forged aggregates, missing sessions, and target drift fail closed
  as unmeasured.
- Consequences: metric reads cost one bounded local extraction when a
  population exists; outputs expose source-verified and unverified counts.

## Accepted Drift

- Original plan/spec: reconnaissance predicted 33 recoverable outcomes and
  seven exclusions.
- Implemented reality: the deterministic complete scan found 37 admissible
  outcomes and three exclusions, all for windows under 60 seconds.
- Why accepted: the larger set passes the same guards, is reproduced on every
  metric read, and does not relax the fixed population or privacy boundary.

## Validation Evidence

- `bash tests/workflow-telemetry-recover-smoke.sh`:
  - result: PASS; 0/5 to 4/5 held-in recovery, explicit dry-run privacy,
    idempotence, stale-baseline rejection, forged-import rejection, and stale
    target invalidation.
- `bash tests/workflow-event-smoke.sh` and
  `bash tests/workflow-metrics-smoke.sh`:
  - result: PASS; strict event membership/uniqueness plus unchanged native,
    legacy, unmeasured, runtime-usage, and harness behavior.
- `scripts/verify-agentic-infra all`:
  - result: PASS after source-verification fixes; all deterministic shell,
    documentation, workflow, Pi, audit, router, install, and Nvim groups green,
    including 219 Pi tests and 32/32 router cases. The real-agent CLI probe
    remained intentionally opt-in and reported its contractual skip.
- `scripts/workflow-metrics --sessions-dir ~/.codex/sessions --json`:
  - result before current-run terminal: 40 historical terminal outcomes, 37
    recovered/source-verified, zero unverified, duplicate, or unmatched import,
    `usage_measurement_coverage=0.925`, 35 measured successes, and
    `tokens_per_successful_outcome=8123398.628571428`.
  - result after the current measured outcome: 38/41 usage-measured outcomes,
    `usage_measurement_coverage=0.926829268292683`, 36 measured successes, and
    `tokens_per_successful_outcome=8318058.583333333`.
- Fresh-context Terra review:
  - result: first `BLOCK` accepted three findings; final `GO` confirmed their
    fixes and reported no remaining actionable defect.
- Code-diff adversary:
  - result: final `GO`.
- `git diff --check`:
  - result: PASS.

## Follow-up State

- Remaining risks: recovered costs cover only the selected primary Codex
  session, not historical sidecars that cannot be attributed; local session
  pruning intentionally turns affected imports back into unmeasured evidence.
- Parking lot: consider a display-only `native_flag_only` label for historical
  `measured:true` outcomes without tokens; it does not affect current coverage.
- Superseded docs/specs: none.
- Next links: `workflow/events.md`,
  `workflow/skills/self-improvement-loop.md`,
  `scripts/workflow-telemetry-recover`, and
  `tests/workflow-telemetry-recover-smoke.sh`.
