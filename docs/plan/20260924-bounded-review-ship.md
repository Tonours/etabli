# Implemented: Bounded review loop + ordered /ship — T/D/FD/F machine, two ledgers, registry, F12 fallback

## Metadata
- Archived: 2026-09-25
- Source plan: `PLAN.md` — Tranche 5 — Boucle de review bornée + ordre de /ship (T5, F12, événements ship, métriques)
- Source plan SHA-256: `804941194fc9fd2bd3299fe974c566431559ef5d734baf45f556c9e43f3aba6e`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main` (base `3db5e40`)
- Workflow initiative: bounded-review-ship
- Filename note: `20260924-` slug per the plan stop condition (chain day); archived 2026-09-25 past midnight UTC.

## Outcome
- **AC1 bounded machine EXHAUSTIVE + positional.** T1/T2/D1/D2/F1/F2 positional (first/second round of kind spent), FD post-F1 delta round (tag `FD`, consumes one D, exits F2/`blocked`, never F1/D2/T), F SHA-bound, D-adversary severity-gated, limit cases a–e, T6-enforcement sentence. Last review always covers the full delivery diff; `blocked` explicit at every ceiling.
- **AC2 ship order 4<5<6<7.** Pre-commit → thermo → cumulative review on the FINAL diff → closed sweep; single shared T/D/F counter transferred via a `file_changed` carrier (`consumed`/`remaining`, FD counts as D); post-sweep code entry = next unspent F (normally F2); archive immutable + hash re-check (`ls-tree` presence + `git show | shasum`).
- **AC3 delta exact.** Ancestry + two-dot numstat `-z` ×3 + staged/unstaged unreadable→full + untracked-impl closed exclusions + recompute rule; >50/surfaces/rebase→full; generated-records exception with per-source recompute + negative pin + `jq -S` parsed values + globs; porcelain gate at push.
- **AC4 two ledgers + `ship_completed`.** Loop + `ship-<branch-slug>` (sanitized, collision `-2…`, `branch` recorded, no `route_decided`); vocab + strict dual-form jq (8/8 keys, `...HEAD @ ...` record with value after `@`, `findings:<n>-folded`, matrix coupling) + legacy unconstrained; profiles `ship-completed` (success form + latest-per-command freshness) / `ship-stopped` (negated success form — exhaustive split — terminal `blocked` after `ship_completed`); CLI/batch/ledger-integrity mirrors agree incl. version-gated legacy counting; activate/pointer ship-aware. SANS retrospect by design.
- **AC5 metrics.** `scripts/workflow-ship-metrics` registry (lockf/flock/shlock, upsert/show/find-pr, `escaped_later` count for `Σ escaped_per_go`), aggregate row lifecycle in-diff, CI segments with global t0+45min + attempts ≤5 + pre-loop gate, post-cleanup conservation e2e, `metrics_record` harmonized.
- **AC6 F12 partial + verifiable T7 entry.** Per-harness matrix (Pi/Claude prose, Codex detect), `pr_body_style` chain mapping, T7 criterion (skill + load-check + detect pin + receipt).
- **Gates.** `ship-order-smoke.sh` new (order/transfer/archive/delta/registry/F12/census, core manifest row) + T5 vocab block in `workflow-event-smoke.sh` (dual form, 5 number rejects, 3 matrix rejects + 4 valid cells, profiles, batch, legacy×2, L1, H5, e2e); core 26/26; bun 361/361; census 0 flips (v1→v2 110/110, live diff exit 0, own-ledger CROISSANCE only); freeze-smoke green + gate byte-identical; context budget green after reviewed raise.

## Context
- Roadmap slice: §12 tranche 5, tier high-risk (validator vocab + census gate + behavioral ship reorder); 12 plan-adversary rounds (R12 READY, 0 findings).
- Census instrument: `scripts/workflow-ledger-census` (versioned) — per-slug `validate` → OK else pin → QUAR/FAIL + sha256 + size; 4-field TSV; CROISSANCE requires byte-prefix else REWRITE rc=1; AJOUTÉ QUAR → rc=1; hash.sh + fail-hard; `CENSUS_PINS_FILE` override for tests. Baselines `.workflow/bounded-review-ship/census-baseline{-v1,}.tsv`.
- `blocked` appendable after `ship_completed` ONLY (all four validators agree; nothing follows `blocked`).
- Author blind spot found twice: `.Detail`/`.detail` and `"Detail"`/`"detail"` typed identically by eye — fixtures now codepoint-checked; the smoke caught both.
- Protected skills stay visible: `alambic-brain`, `alambic-obvault`, `typesafe-ai` (untouched by this tranche).

## Decisions
### Arrêt = negated success form, not the non-green subset
- Context: AC4/Appendix letter said arrêt `ci_state ∈ {capped,blocked,not-run}`, but `-open` routing + green+PR✓ matrix cell require green+`-open`+`blocked` to be representable (honest receipt for known-unfixed findings with green CI).
- Choice: arrêt ⟺ ¬success-form (≥1 marker), single-sourced (`SHIP_SUCCESS_FORM` / `ship_success_detail`); stops before CI still carry non-green ci_state; AC4 + Appendix amended with Decision Log errata.
- Rejected options: strict non-green (leaves green+open in NEITHER form — a hole — or forces early stop, an invented behavior), pure-presence ship-stopped (accepts success content + blocked — Codex H).
- Rationale: profiles own an exhaustive split; text amended to coherent behavior, not behavior to text.
- Consequences: `t5-open` valid stopped; `t5-greenstop` rejected on CLI + batch; joint-matrix reading documented.

### Positional rounds + FD instead of absolute D1/D2 reuse
- Context: post-F1 D-round exits and widening re-entry were undefined/contradictory (Logic H2).
- Choice: rounds positional per kind; FD special round (→F2/`blocked`, no T re-entry); D1-widening → next unspent T.
- Rejected options: reusing D1/D2 semantics post-F1 (exit ambiguity), absolute round identities (re-entry undefined).
- Rationale: EXHAUSTIVE was the AC1 bar; every entry consumes budget or blocks.
- Consequences: transfer counting rule names FD; limit case (e) added.

### Census prefix rule + QUAR-add failure
- Context: rewrite-blindness (same-verdict rewrite listed as growth) and silent QUAR reappearance (Logic M8, Codex C5).
- Choice: 4-field TSV (size), prefix-verified CROISSANCE else REWRITE rc=1, AJOUTÉ QUAR rc=1, stale-format guard, v1 baseline kept + v2 retaken (0 verdict flips over 110 slugs).
- Rejected options: verdict-only diff (blind), failing on new OK slugs (normal mid-run growth).
- Rationale: ledgers are append-only; the gate must prove it, and Checks demand 0 QUAR nouveau.
- Consequences: live diff proves the rule on the own ledger (prefix-verified CROISSANCE, exit 0).

### Vocab fixtures live in workflow-event-smoke (Checks-literal)
- Context: PLAN Checks assign ship vocab/profile/legacy/e2e to `workflow-event-smoke.sh`; ship-order owns order/transfer/archive/delta/registry/F12/census.
- Choice: moved the T5 block (fixtures, rejects, matrix valid cells, batch, legacy×2, L1, H5) to event-smoke; ship-order keeps the transfer carrier + pointer comment.
- Rejected options: duplication across smokes (thermo), leaving all in ship-order (Checks violation — Spec H3).
- Rationale: one home per contract line; both smokes green independently.
- Consequences: event-smoke ~850 lines (engine coverage), ship-order ~250 (integration).

### Profiles judge the LAST receipt (multi-receipt parity)
- Context: CLI matched ANY `ship_completed` line while batch judged the last — disagreeing on degenerate multi-receipt legacy ledgers (Codex T3 MED).
- Choice: CLI uses `-s … | last` for both form checks; batch already used last.
- Rejected options: any-match everywhere (a stale receipt could decide), first-match (terminal-adjacent receipt is the operative one).
- Rationale: mirror parity is a T5 invariant; the last receipt is nearest the terminal.
- Consequences: pinned both directions (success-then-garbage rejects completed; garbage-then-success rejects stopped, CLI + batch); pins proven red on any-match.

### Incidents declared, not hidden
- Context: mid-tour `.Detail` (capital-D) predicate silently matched every receipt under ship-stopped; `"Detail"` fixtures passed vacuously under legacy lenience.
- Choice: fixed + reproduced + pinned; codepoint-check habit noted; vacuous-pass analysis (legacy `true` accepts even null detail) recorded.
- Rejected options: silent fix (pattern worth remembering), weakening the smoke to pass.
- Rationale: every deviation identified with a reason string (T3 rule).
- Consequences: T5 block asserts exact event counts + messages; legacy pins use real lowercase details.

## Review record
- Logic BLOCK (B1 + 6 HIGH + 8 MED + 6 LOW) → tour 1 folded → Logic R2 GO WITH NOTES (1 LOW: FD in counting rule — folded).
- Spec BLOCK (3 HIGH + 8 MED + 5 LOW) → tour 2 folded → Spec R2 GO WITH NOTES (4 LOWs: counts, t5-inc acceptance, header, degenerate-cell refute — folded/refuted).
- Codex BLOCK (3 HIGH + 2 MED) → tour 1 → Codex T2 BLOCK (1 MED + 1 LOW) → tour 2 → Codex T3 BLOCK (1 MED: CLI-vs-batch any-vs-last receipt) → fixed + pinned, accepted on lead proof (pins proven red on old semantics). Overrun declared (3 tours, precedent T2/T3/T4).
- Thermo SHIP WITH NOTES (shlock stale-lock bug fixed, predicate single-sourcing, smoke dedup; notes: shared lock lib future, workflow-event 960-line proximity).

## Accepted Drift
- Original plan/spec: AC4 arrêt `ci_state ∈ {capped,blocked,not-run}`; census 3-field TSV; 4 number-rejects + 2 matrix-rejects; ledger opened at "step 1".
- Implemented reality: arrêt = negated success-form (green+`-open` valid); census 4-field + REWRITE + QUAR-add rc=1; 5 number-rejects + 3 matrix-rejects; ledger opened step 2 with sanitized slug.
- Why accepted: each drift is a reviewed erratum (coherence > letter), recorded in the Decision Log, pinned by smokes, re-reviewed GO.

## Validation Evidence
- command: `bash tests/ship-order-smoke.sh` → pass (order, transfer carrier, archive-hash e2e, delta, registry 2×25 0-lost + find-pr + post-cleanup, F12, census REWRITE/QUAR/fail-hard)
- command: `bash tests/workflow-event-smoke.sh` → pass (T5 block: dual form, 5 number rejects, 3 matrix rejects + 4 valid cells, profiles, batch 4/4, legacy×2 + agreement, L1, H5, e2e)
- command: `scripts/verify-agentic-infra core` → 26/26 pass
- command: `bun test pi/extensions/__tests__/` → 361 pass, 0 fail
- command: `scripts/workflow-ledger-census diff` → exit 0 (own-ledger CROISSANCE only); v1↔v2 0 flips / 110 slugs
- command: `bash tests/plan-check-freeze-smoke.sh` + gate diff → green + byte-identical
- command: `scripts/workflow-context-budget` → all surfaces ok (implement/plan-implement raised with rationale, reviewed)

## Follow-up
- T6: mechanical enforcement of the T/D/FD/F machine; shared lock helper extraction (ship-metrics × workflow-event); workflow-event decomposition before 1k; distinction-check registry.
- T7: F12 fallback closure per harness (style skill + load-check + detect pin + receipt); T7 entry criterion is the gate.
- T8: ship budget surface; tokens under protocol.
