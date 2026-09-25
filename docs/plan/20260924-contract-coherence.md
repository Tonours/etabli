# Implemented: Contract coherence — prose aligned or mechanical rule + fixtures, no control removed

## Metadata
- Archived: 2026-09-24
- Source plan: `PLAN.md` — Tranche 4 — Cohérence des contrats (F1, F2, F5, F6, F7, F8, F9, F10, F15 + indépendance adversaire-plan + Review Changes + implement/étape 1)
- Source plan SHA-256: `36551b6131ad2cd953809670e5c77d975edad324616079c9f1999aaf3a8ecf3a`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main` (base `7d53652`)
- Workflow initiative: contract-coherence, contract-coherence-2

## Outcome
- **AC1 (F1) small journey executable.** Steps 1–7 bounded to plan routes; small tier runs 0→8→11?→12→12b→12c→self-review→17 with every plan-verb step qualified (`(the task, for small)` ×3, surface checks at 12, N/A archive/deletion at 17, tier-bounded evidence list). `optional for small` purged; validator stays tier-free (absence pin).
- **AC2 (F2) `quality_completed` end-to-end.** Vocab + strict `{status, evidence}` enum `{pass, unavailable}` + legacy lenience + `WORKFLOW_EVENTS` + events table + retrospect mirror + 12c appends in 3 skills; autonomous profile does NOT require it. E2E pin reaches retrospect `complete` plus same-path negative (blocked terminal, ts-shifted ledger).
- **AC3 (F5) adversary reclassified + provenance.** Claude agent is a same-family sample (pins kept); cross-family = pool invocation procedure in `adversary.md`; `model_provenance` complete-when-present additive on `adversary_completed` (strict+legacy jq, retrospect exactKeys-relaxed v2-only, requested.provider required, object guards against jq throw); counting rule present+valid+distinct.
- **AC4–AC9 (F6–F10, F15).** Force-push qualified + cross-ref; ci-fix ledger procedure with extract-and-execute example; router suggestions generic (pool frontalier, no dead route); verdict canon documented without narrowing (census forbid); READY gate reconciled prose-side only (named-files owned by plan-adversary, `non-trivial` purged 4 sites, gate byte-identical); verify line.
- **AC10–AC12.** Distinct-family plan pass required (supplement labeled, blocked otherwise, tri-file pin); `## Review Changes` canonical in both templates + 3 pointers; implement task/plan correspondence prose (ready-gated router kept as sole mechanical control).
- **Gates.** `contract-coherence-smoke.sh` new (32 pins, core manifest row); core 25/25; bun 361/361; census 0 flips (90 OK/18 QUAR at 4 checkpoints incl. post-guards); freeze-smoke green + gate untouched.
- **Collateral kept green.** Jev promotion fingerprints refreshed (F8 touched a bound source); context-budget ceilings raised (reviewed growth); skills-lock updated (3 hashes).

## Context
- Roadmap slice: §12 tranche 4, tier high-risk (validator jq + ledger); 11 plan-adversary rounds (R11 READY, 0 findings).
- Census instrument: per-slug `validate` → OK, else sha vs grandfathered pin → QUAR/FAIL; TSVs in `.workflow/contract-coherence/`; baseline predates the tranche's own ledger (+1 OK row at checkpoint c, not a flip). 3 baseline QUARs have no pin entry (pre-existing inventory gap, bytes identical, verdicts carried).
- `blocked` is terminal for appends: miscategorizing a side incident as run-blocker closes the run. Repair = new run slug, never history rewrite (`contract-coherence` → `contract-coherence-2`).
- `completed` appends enforce the full autonomous chain only when a v2 plan-implement `route_decided` exists; test terminals use `blocked`. `selectActiveLedger` refuses terminal runs (select before terminal).
- Retrospect binds trace↔ledger time windows: CLI-stamped ledgers need post-validate ts-shift to reach `complete` with frozen fixtures.
- Protected skills stay visible: `alambic-brain`, `alambic-obvault`, `typesafe-ai` (untouched by this tranche).

## Decisions
### Prose-or-mechanical, never half (P0 tranche rule)
- Context: §4 contract incoherences across docs, validator, READY gate, router.
- Choice: each finding closes by prose aligned on both sides, or mechanical rule + fixtures.
- Rejected options: one-sided doc edits (AC1 small journey proved them inexécutable 3× in review), validator narrowing where census forbids (F9).
- Rationale: the Codex gate found 3 real executability holes in prose-only fixes; pins make prose falsifiable.
- Consequences: 32-pin coherence smoke; 3 Codex tours (declared overrun).

### Provenance complete-when-present, no mechanical distinction check
- Context: policy demands distinct-family + provenance but has 0 code readers.
- Choice: additive optional object, complete when present, harness-sourced effective values, parent-verified counting rule; distinction check parked as T6 registry candidate.
- Rejected options: mandatory provenance (breaks history), silent fallback counting (false independence), runtime route selection (no author identity at classify sites, fuzzy family normalization — T6).
- Rationale: pools are invoked, not detected; a pass that cannot prove its family cannot count.
- Consequences: jq object guards (throw→clean reject); e2e/pins; T6 candidate noted.

### Small journey fully qualified, count-pinned
- Context: AC1's first fix left plan-verbs at steps 0/8/11/12b/17; Codex found them across 3 tours.
- Choice: `(the task, for small)` at 0/8/12b (count pin 3), surface checks at 12, tier-bounded evidence, N/A report fields.
- Rejected options: leaving conditionals implicit (3 BLOCKs proved reviewers right), tour 4 (declared bound: tour-3 fix accepted on lead proof-re-read of all 8 steps).
- Rationale: small is the most-run tier; an inexécutable journey is a live trap, not a nit.
- Consequences: journey 8/8 steps executable; coherence smoke owns 6 small pins.

### Incidents declared, not hidden
- Context: mid-session deletion of untracked `herdr/` by an unknown actor; erroneous `blocked` append by the implementer.
- Choice: pinned skill tree restored hash-verified from sibling checkouts (d55c3c3, identical ×3); unpinned remainder left unrestored (full/herdr-setup-smoke red, non-gate); ledger continued on `contract-coherence-2` with history intact.
- Rejected options: restoring unverifiable content (wrong config worse than missing), rewriting ledger history (integrity red line), hiding the overrun (budget rule).
- Rationale: every deviation identified with a reason string (T3 rule).
- Consequences: user asked to confirm herdr/ restore source; full profile gap documented.

## Review record
- Logic GO WITH NOTES (fingerprint chain independently recomputed OK; vacuous-pin fixed, divergence rejected w/ evidence).
- Spec GO 12/12 + Scope-Out untouched.
- Thermo SHIP WITH NOTES (3 accepted, 7 rejected w/ evidence; no file crosses bars).
- Codex diff: tour 1 BLOCK (step-12, e2e vacuous) → fixed; tour 2 BLOCK (12b tail) → fixed + sweep; tour 3 BLOCK (11/17 tail, last crumb enumerated) → fixed + pinned, accepted on lead proof. Overrun declared (3 tours, precedent T2/T3).
- Census: baseline = quality = provenance byte-identical (107 rows); guards checkpoint +1 own-ledger OK, 0 flips.
