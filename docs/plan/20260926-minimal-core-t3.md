# Implemented: Minimal core T3 — ledger reduced to its core vocabulary, non-core contracts shelved, maps trimmed

## Metadata
- Archived: 2026-09-26
- Source plan: `PLAN.md` — Recentrage minimal — Tranche 3 : ledger au vocabulaire cœur, contrats hors cœur rangés, cartes allégées
- Source plan SHA-256: `82be964abedd8b511bccc408569cc3d050116af3d8c4d8d70d860027e26c0134`
- Status: IMPLEMENTED
- Commit / branch: `refactor/minimal-core-routes` (single tranche commit on top of `c148b72`; not pushed)
- Workflow initiative: `minimal-core-t3`

## Outcome
- 24 retired event types (self-improvement, harness ×4, project slices ×2, program ×7, runtime attach/receipt, multi-execution, outcome measurement ×2, outcome metric, dogfood ×4) are refused on append (`retired event type`) and stay readable in history; a retired line must still carry an object detail. One retired list per language: `RETIRED_EVENTS` (`scripts/workflow-event`), `retired_events` (`scripts/lib/workflow-event-detail.jq`), `RETIRED_WORKFLOW_EVENTS` (`scripts/lib/workflow-events.mjs`, read by `ledger-integrity.mjs`).
- `autonomous-completed` and `ship-completed` no longer require `outcome_metric`; `autonomous-completed-strict` removed.
- Removed: `workflow-measurement-integrity` (and its per-validate call), `workflow-supersession-check`, `workflow-receipts.mjs` and Pi receipt emission, Pi `workflow-run-binding` and `trace-observation.schema.json`, the program/slice projection of `session-handoff`, the dead `shouldDenyMutationForNoProgress`, the program-event append cache, and four dedicated smokes. `workflow-event-detail.jq` 701 → 277 lines, `workflow-event-smoke` 861 → ~640.
- `product-dogfood`, `ambitious-project-loop`, `recurring-run`, `pr-maintenance-loop` moved to `extras/contracts/` (never deployed); every pointer redirected or removed.
- `events.md` 139 → 98 lines, `events-validator.md` 177 → 41; `spec.md`/`contract-details.md` cleaned; line caps lowered (205/284) and added (101/44).
- Context ceilings ratcheted: ship 90138 → 87525 (below pre-T1 89633), implement 62476 → 57657, plan-implement 68268 → 63181, spec-map 34668 → 29875.

## Context
- The allowlist gated reading as well as writing in all three validators; a retired type needed its own list, not a deletion.
- `workflow-event validate` called `workflow-measurement-integrity` on every run, so the script and its call sites had to go together.
- Six ledgers were quarantined only for `multi_execution_completed` detail drift; with retired details unchecked they validate again and their inventory entries were removed.
- The READY gate, check-freeze and `plan-ready-guard` never read the ledger; the hooks only import the ledger chain for the escape-hatch matcher.

## Decisions
### Reduce the ledger, do not delete it
- Context: `ship`, the handoff and `plan-cleanup` consume the ledger.
- Choice: core vocabulary plus a read-only retired list.
- Rejected options: deleting the ledger (breaks ship and resumption); dropping retired names outright (145 local ledgers would turn invalid).
- Rationale: minimal surface without rewriting history.
- Consequences: new retirements append to the three lists.

### Keep an object check on retired lines
- Context: skipping all detail checks let `detail:null` pass bash/jq while the JS reader rejected it.
- Choice: retired lines skip their schema but must carry an object detail.
- Rejected options: keeping full retired schemas (the bulk being removed).
- Rationale: CLI, jq and JS readers stay in agreement.
- Consequences: covered by a regression test in `workflow-event-smoke`.

## Accepted Drift
- Original plan/spec: AC1 batch mode receives `--argjson retired`; AC7 ceilings ≤ measured +2%.
- Implemented reality: `def retired_events` inside the jq file; ceilings from `workflow-context-budget --ratchet` (×1.03).
- Why accepted: one list per language with no caller change; reuse of the repo's ratchet rule. Both logged in the plan Decision Log.

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: 27/27 PASS
- command: per-check `full` runner (`/tmp/t1-full-each.sh`)
  - result: 51/51 exit 0
- command: `bun test pi/extensions/__tests__/`; `bash tests/pi-typecheck-smoke.sh`
  - result: 349/349; no type errors
- command: ledger census before/after (`scripts/workflow-event validate` per local ledger)
  - result: 99 OK / 18 FAIL → 105 OK / 12 FAIL, only the 6 planned quarantined→valid flips; `workflow-ledger-check` ok=105 quarantined=12 stale=0 failed=0
- command: `scripts/router-eval`; `scripts/workflow-router-parity`
  - result: 0 misses; `clean (8 routes)`
- command: `scripts/workflow-adapter-sync --check`; lock verify; `scripts/workflow-ref-linter`; `scripts/workflow-context-budget`
  - result: clean; 80 hashes; clean; 8 surfaces within ceiling
- command: `scripts/deploy-agent-workflow --apply`; `scripts/check-fix-symlinks.sh`; `scripts/claude-hooks-check`
  - result: ok; 0 issues; hooks wired
- command: reviews
  - result: reviewer Logic GO, reviewer Spec GO WITH NOTES, plan adversary R1 CHALLENGED → READY, Codex `gpt-6-astra` BLOCK → GO WITH NOTES (no finding); every finding folded

## Follow-up State
- Remaining risks: projects scaffolded before T3 keep a stale `scripts/workflow-measurement-integrity` copy (still git-excluded, never called).
- Parking lot: `PLAN_TEMPLATE_FULL.md` slimming; the 46 personal skills outside the Claude profile in `$CLAUDE_CONFIG_DIR` (user decision).
- Superseded docs/specs: the removed sections of `events.md` and `events-validator.md`.
- Next links: none — T1–T3 close the minimal-core program.
