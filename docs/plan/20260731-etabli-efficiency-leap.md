# Implemented: Etabli efficiency leap (token, determinism, context, cross-agent)

## Meta
- Date: 2026-07-31
- Source: goal « Etabli leap — token efficiency, harness determinism, context
  management, cross-agent/cross-loop efficiency, with before/after benchmarks »
- Route: `plan-implement` (self-improvement of etabli on etabli; ADR-0011 scope)
- Analysis: workflow `etabli-leap-analysis` (8 agents, 498K tokens, 228 tool
  calls) + independent cross-check (numbers validated, no hallucination)
- Status: implemented + validated; archived. Root `PLAN.md` deleted post-archive.

## Goal
Measurably improve the four efficiency dimensions with **before/after benchmarks**
reusing the shipped offline metering stack. The "−50 % minimum" request was
reframed honestly (see Decision Log): 50 % is realistic only for narrowly-scoped
sub-metrics, NOT as a blanket per-dimension cut without harming routing/discovery
quality (the repo's own "maps not manuals" rule).

## Changes (slices delivered 7/8; T3 de-scoped with reasoning)
- **C1** [Context] Retired the `kb/_index.md` full-read mandate; reconciled
  `workflow/answer-quality.md` with the bounded-CLI contract already preferred in
  `workflow/skills/obvault-memory.md`. **Touches the external `obvault` repo**
  (`AGENTS.md`, `CLAUDE.md`) — user-approved.
- **H1** [Determinism] Cross-validated the `claude-hooks` fixtures against the Pi
  classifier via a fixtures-as-cases adapter: new
  `tests/router-evals/claude-hooks-sync.json` (21 dual-validation cases).
  Closes the silent Pi↔Claude classifier drift hole.
- **T4** [Token] Relocated the 25 dead tanstack/adonisjs skill suites (25 suites /
  57 `.md` files / ~188 KB) from `pi/skills/` to `pi/skills-archive/` (dormant);
  removed the 25 corresponding `skill-surface.tsv` rows. Added `skills-archive/README.md`.
- **H3** [Determinism] Surfaced E2E transient-error retries as a structured
  `RETRIED=<n> kind=<k>` stderr metric + JSONL ledger feed (`emit_retry_metric`
  helper, 6 branch sites in `tests/workflow-real-agent-scenarios.sh`).
- **X2** [Cross-agent] Closed the loop outcome-measurement gap: additive OPTIONAL
  typed `outcome_metric` fields (`runtime`, `turn_count`, `auto_continue_count`,
  `token_estimate`, `wall_clock_ms`) in `scripts/lib/workflow-event-detail.jq`,
  documented in `workflow/events.md`, with positive/negative smoke fixtures.
- **T2** [Context] Removed the always-on `_index` mandate pointer from
  `workflow/answer-quality.md` (the bounded CLI already owns context capping).
- **T1** [Token] Split `workflow/spec.md` into a leaner map: moved the Human
  checkpoints table to `workflow/contract-details.md` § Human checkpoints (detail);
  trimmed the Runtime surfaces index to lean refs + pointer. Preserves the 3 refs
  the smokes pin (`claude/settings.workflow-hooks.json`, `workflow/plan-archive.md`,
  `workflow/project-autonomy-envelope.md`).
- **T3** [DE-SCOPED] ADR index dedup. Reasoning: the always-on ADR index
  (~1 300 chars) is **generated** (`renderIndex` in `scripts/apply-adr.mjs`),
  **specified** (`docs/adr/ADR-FORMAT.md`), and **asserted** in 5+ smokes — it is
  a protected navigation *map*, not low-risk prose, so it is covered by "maps not
  manuals". De-scope is intentional; the always-on `<7 500` target is not met
  (8 231) for this principled reason.

## Non-goals preserved
- No new harness tree / third runtime; no `PLAN.md` dual-write; no framework
  rewrite; no consolidation of the two classifiers into one (the dual-classifier
  alignment guard IS the design).
- No telemetry/dashboard expansion; no auto-apply of harness/kb patches.
- No blanket relabel of the 5 `unknown` capabilities (only an offline proxy proof
  would move them).
- No live-model token-COST measurement (stays honestly blocked behind
  `LIVE_EVAL_BUDGET_USD`). Footprint deltas are the honest proxy; cost savings
  are NOT fabricated.

## Validation (final gate — all green simultaneously)
| Command | Result |
| --- | --- |
| `scripts/verify-agentic-infra core` | EXIT 0 |
| `cd pi && bun test ./extensions/__tests__/` | EXIT 0 (224 pass) |
| `node scripts/router-eval.mjs --require-alignment --json` | total=53 accuracy=1 alignmentRate=1 |
| `bash tests/router-eval-smoke.sh` | EXIT 0 (total=53) |
| `bash tests/workflow-efficiency-report-smoke.sh` | EXIT 0 |
| `bash tests/claude-hooks-smoke.sh` | EXIT 0 |
| `bash tests/workflow-docs-smoke.sh` | EXIT 0 |
| `bash tests/runtime-capabilities-smoke.sh` | EXIT 0 |
| `bash tests/workflow-event-smoke.sh` | EXIT 0 |
| `bash tests/workflow-metrics-smoke.sh` | EXIT 0 |
| `bash tests/dual-runtime-guard-matrix-smoke.sh` | EXIT 0 |
| `bash tests/answer-quality-check-smoke.sh` | EXIT 0 |
| `bash tests/plan-check-freeze-smoke.sh` | EXIT 0 |

## Benchmark BEFORE / AFTER (offline meters)
Footprint deltas are labeled as **footprint** (not runtime token-COST, which stays
blocked behind the live budget).

### Token
| Metric | Before | After | Delta |
| --- | ---:| ---:| --- |
| `spec.md` chars (read by 11 route loaders) | 12 412 | 9 337 | **−24,8 %** |
| adapter files scanned (`find pi/skills`) | 126 | 69 | **−57** (25 suites archived out of autoload scan path) |
| adapter total lines | 12 639 | 6 817 | −46,1 % |
| dead-skill files under `pi/skills/` | 57 (25 suites) | **0** | removed from autoload scan |
| always-on floor (4 files: `CLAUDE.md`+`AGENTS.md`+`pi/AGENTS.md`+`claude/CLAUDE.md`) | 8 301 | 8 231 | −0,8 % (cible <7 500 non atteinte — index ADR généré+testé) |
| instruction budget ratio (`scripts/workflow-efficiency-report`) | 0.165 | 0.1646 | inchangé (aucune édition de chemin budget) |

> Les 25 suites archivées n'étaient **pas** dans le always-on load — leur
> déplacement nettoie le **scan path** adaptateur (−57 fichiers scannés) et la
> maintenance de `skill-surface.tsv`, mais ne sauve pas de tokens per-turn.

### Determinism
| Metric | Before | After | Delta |
| --- | ---:| ---:| --- |
| router-eval golden cases | 32 | 53 | +21 (sync dual-validation) |
| router-eval accuracy | 1.0 | 1.0 | preserved |
| router-eval alignmentRate (Pi↔Claude) | 1.0 | 1.0 | preserved (drift hole closed via H1) |
| dual-validated scenario count | 32 | **53** | +66 % |
| E2E retry visibility | hidden (3 loops) | `RETRIED=<n> kind=<k>` + JSONL feed | surfaced (H3) |

### Context
| Metric | Before | After |
| --- | --- | --- |
| `_index` mandate in `answer-quality.md` | 1 (forced 37 558-char read) | **0** (bounded CLI owns capping) |
| obvault answer chain | transitive `kb/_index.md` read (~51 KB) | bounded `context`/`session` CLI |

### Cross-agent / cross-loop
| Metric | Before | After |
| --- | --- | --- |
| `outcome_metric` additive typed fields | 0 | **5** (`runtime`,`turn_count`,`auto_continue_count`,`token_estimate`,`wall_clock_ms`) |
| source-of-truth conflicts | 0 | 0 (preserved) |
| exact-duplicate pairs | 7 | 7 (all are `tests/fixtures/adr-validation/` test fixtures, not always-on) |

## Fresh-context review
Workflow `efficiency-leap-diff-review` (4 dimensions → adversarial verify per
finding; 7 agents, ~367K tokens, ~7,5 min): **3 raw findings → 1 confirmed**.

| Dimension | Raw | Confirmed |
| --- | ---:| ---:|
| contract-integrity (spec↔contract-details split) | 1 | 0 — refuted: cosmetic "(detail)" suffix variance in a § pointer; resolves unambiguously, no gate depends on it |
| logic-correctness (jq schema, retry helper, sync fixtures) | 0 | 0 — clean |
| safety / writegates (obvault bridge, gate weakening, secrets) | 0 | 0 — clean (bridge stays verifiable-only, no gate weakened) |
| completeness-consistency | 2 | **1** |

Confirmed (low severity, **fixed**): `emit_retry_metric` comment claimed its JSONL
line "matches the tests/adr-skill-stress.sh metrics convention", but the schemas
are incompatible (`{label,cost,duration_ms}` vs `{metric,kind,retries}`). No
functional impact; comment corrected to describe the shared append-only ledger
pattern with a distinct schema. Refuted sibling: `skills-archive/README.md`
locked=1 restore nit — the runtime gate (`verify-skills-lock.mjs`) already
self-diagnoses with the exact remediation command.

## Decision Log (preserved from PLAN)
- 2026-07-31: `check_freeze_demote` — replaced the completed+committed
  council-migration PLAN (commits 090c299/9c7a635/753a9aa/f07edc8; 224/224 unit +
  15/15 core green; Phase 2-E2E deferred by user) with this efficiency-leap plan.
  User-authorized overwrite. Council work is fully reconstructable from git history.
- 2026-07-31: Reframed "−50 % per dimension" to honest sub-metric targets after the
  measured baseline showed entrypoint budget already at −80 % (9455→1556) and
  offline determinism near-ceiling. Blanket 50 % would require cutting
  routing/discovery content the "maps not manuals" rule protects.
- 2026-07-31: User authorized P0+P1 (8 slices) including obvault + shared-contract
  edits.

## Notes
- **Commit status**: nothing committed in this run. `obvault` (C1) is an external
  write to durable memory requiring explicit approval; per the safety rule,
  commits/pushes happen only on explicit user ask. The etabli diff + the obvault
  diff await the user's commit decision (per-slice vs batch).
- The 5 `unknown` capabilities are NOT blanket-relabeled (non-goal); only
  offline-proxy proofs would move them.
- Council-migration E2E follow-up (`tests/multi-model-real-smoke.mjs` real run once
  xai auth) remains tracked in prior commits; not blocked by this plan.

## Archive
This file is the distilled archive for the goal slice.
