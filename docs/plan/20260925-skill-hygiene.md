# Implemented: Skill hygiene — F11 user-only flags, T9 descriptions + trigger eval, listing ceilings, ponytail UNCLAIMED

## Metadata
- Archived: 2026-09-25
- Source plan: `PLAN.md` — Tranche 7 — Hygiène des skills (F11, T9, §11)
- Source plan SHA-256: `0f461308fed33a5564def86c0bd2a0fa1f3fc8ec0a4ca21feeb5ac13b45695ee`
- Status: IMPLEMENTED (AC4 UNCLAIMED by explicit user decision)
- Commit / branch: uncommitted on `main` (base `3db5e40`)
- Workflow initiative: skill-hygiene

## Outcome
- **AC1 F11 user-only.** `disable-model-invocation: true` value-asserted on the 10 pinned paths (5 side-effect skills × pi + claude commands) + native `pi-dmi-probe` (hidden-from-prompt, still expandable) + negative naked-skill fixture; `tests/skill-hygiene-smoke.sh` cases AC1a/b/c.
- **AC2 descriptions + trigger eval.** 20 pi + 14 claude descriptions rewritten to what+when+not-for (plan-time 21/33 counts superseded at implement); tripwire shape smoke (AC2a, labeled gameable); FULL trigger eval (AC2b): 24-task corpus (12 held_in / 8 held_out / 4 safety, LIN-789 anchored), pinned qwen/qwen3-8b t0 runner over the native Pi listing, 3-run majority reduction recomputed from raw runs in CI (never trusted), strict exact-match shared normalize module, ceiling clause HOLD 12/12 + zero regressions via the named `skill-eval-ceiling` module (D-impl1 waiver dormant); control baseline 23/24 → candidate 24/24, reasons exactly [objective_not_met].
- **AC3 listings.** Pi cap + Claude C1 dual assertion green; Codex source-measure gate ≤ 8000 over the repo-managed top-level surface (D-impl4: vendor `.system/` reported informational, 2257 chars), folded + plain multi-line descriptions measured in full; Case 5 gates the real repo-deployed vendor surface (union 7136/8000, 35 skills); remedy ladder on breach; T2-parked items closed (37 stale claude keys + herdr reds + live-skills staleness).
- **AC4 ponytail UNCLAIMED.** +5,495 chars/subagent confirmed macbook-work-only (mac-mini probe 0 bytes, never installed here); removal deferred by explicit user decision (D-user1). No pass-with-hole.
- **AC5 wiring.** Core exactly 32 (new hygiene row); bun 361/361 + 25/25 eval vectors; census diff exit 0 (94 OK, 18 QUAR pre-existing); context budget 7/7 ok after reviewed raise (D-impl2: 3 surfaces to exact current chars, zero headroom); freeze attested (strengthenings only, rationale-logged).
- **Gates.** Core 32/32; 3 T7 smokes PASS individually; full-profile runs are PARTIAL (pre-existing harness bug: background children inherit the manifest-read stdin and eat rows — 40/40 and 44/45 observed are prefixes, not the suite); R3 Logic no-findings, R3 Spec conformant, R1/R2/R3 BLOCK → tours 1/2/4 folded, R4 GO, thermo IT1 HOLD → tour-3 folded → IT2 CLEAR; 4 tours, 2 declared overruns.

## Context
- Roadmap slice: tranche 7, tier high-risk (model-evaluated gate + ceiling clause + cross-harness flags); plan-loop R1 CHALLENGED → R2 CHALLENGED → R3 CHALLENGED → R4 CHALLENGED → R5 READY.
- Evaluator: model execution (qwen/qwen3-8b, temp 0) at implement + on demand; committed raw runs + committed reductions; CI re-verifies deterministically (no provider calls).
- Live environment writes (documented remediations, reversible): skills-lock rotation (39 T7 hash swaps + herdr prune), context-budget raise to exact chars, evaluator bundle re-pins (×3: tours 1/2/4).
- Protected skills stay visible: `alambic-brain`, `alambic-obvault`, `typesafe-ai` (untouched by this tranche).

## Decisions
### Ceiling clause with a dormant candidate-independent waiver (D-impl1)
- Context: 48-baseline held_in 12/12 (zero headroom) + safety 3/4 made the v4 bar letter unsatisfiable — baseline_safety_incomplete is candidate-independent (skill-eval.mjs:253-255).
- Choice: HOLD 12/12 + zero regressions + reasons restricted to objective_not_met, with a waiver tolerating baseline_safety_incomplete IFF candidate safety is complete (4/4) — strictly stronger than zero-regression on the candidate.
- Rejected options: re-running the baseline until it passes safety (flakiness churn cannot change the verdict), weakening to plain zero-regression (allows 3/4→3/4).
- Rationale: bar intent preserved; the waiver rewards only gap-eliminating candidates.
- Consequences: SUPERSEDED in force by the rigorous 49-control baseline (23/24, safety 4/4, reasons exactly [objective_not_met]); the waiver stays as reviewed dormant robustness. Highest-scrutiny item, held through R4 + thermo.

### Codex scope is the repo-managed surface (D-impl4)
- Context: counting vendor `.system/` bytes (2257) into the 8000 gate breaches (8793) with remedies punishing repo content for vendor bytes (perverse).
- Choice: gate = top-level r0 only; vendor bytes reported informational, never hidden (Pi-B1 pstack exclusion precedent).
- Rejected options: raising the gate to fit vendor bytes (hides repo growth), demoting repo skills for vendor bytes (perverse).
- Rationale: vendor bytes are never repo-actionable.
- Consequences: highest-scrutiny item for R2 + thermo; held. Case 5 (R3-B3) gates the union of deployed scopes (7136/8000).

### Strict exact-match normalize, shared module (R2-L + IT1-M)
- Context: first-word prefix matching was lenient; normalize logic was duplicated between runner and tests.
- Choice: envelope-cleaned response must EQUAL the expected name; single `skill-trigger-normalize.mjs` imported by runner + reduce + frozen vector tests (25/25).
- Rejected options: keeping prefix match (masks near-misses), duplicating with a sync test (skew flips verdicts silently).
- Rationale: a sync skew between harness and tests would flip verdicts; one module cannot skew.
- Consequences: 0 flips on 144 records at adoption; R3-B1 typeof guards close the untyped-record hole the strict module exposed.

### Corpus keeps 2 verbatim-verb tasks (D-impl3)
- Context: 2/24 tasks carry the expected domain verb verbatim; voiding was proposed.
- Choice: keep; discriminative power proven empirically (3 real regressions caught during iteration: sec-pr YAML, adversary steal, retrospect steal).
- Rejected options: voiding + full re-eval (flakiness churn cannot change any verdict; held_in at ceiling either way).
- Rationale: the review task still discriminates via the pr-review confusable.
- Consequences: accepted corpus limit, noted for a future round; highest-scrutiny item #2, held.

### AC4 UNCLAIMED by user decision (D-user1)
- Context: ponytail is macbook-work-only; this machine probes 0 bytes.
- Choice: leave UNCLAIMED; removal deferred by explicit user choice.
- Rejected options: claiming on this machine's 0-byte probe (dishonest — wrong machine), silently dropping AC4 (pass-with-hole).
- Rationale: the falsifiable bar names removal-or-scope proof; any other outcome = user decision.
- Consequences: T7 ships AC1/AC2/AC3/AC5 green with the hole named.

## Accepted Drift
- Original plan/spec: 21 names / 33 adapter files; 48-baseline (21/24, safety 3/4); fixtures-only codex smoke; prefix normalize.
- Implemented reality: 20 pi + 14 claude shaped files (implement recount); rigorous 49-control baseline (23/24, safety 4/4, live-minus-descriptions, identical order); Case 5 repo-surface gate; strict shared normalize + typeof guards.
- Why accepted: all deltas are strengthenings or rigor fixes restoring intent (freeze: rationale-logged, no demotion); R4 GO + thermo CLEAR on the final scope.

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: SUMMARY: 32/32 checks passed (post-fix final)
- command: `bash tests/skill-hygiene-smoke.sh`
  - result: PASS (AC1 DMI flags + native probe + AC2a shape tripwire)
- command: `bash tests/skill-trigger-eval-smoke.sh`
  - result: PASS (recomputed reduction + ceiling clause HOLD 12/12, zero regressions; negative null-raw case tamper-fails)
- command: `bash tests/codex-skill-source-smoke.sh`
  - result: PASS (under-cap + breach-fail + dangling-warn + vendor-excluded + plain-multiline 103 + repo-surface 7136/8000)
- command: `bun test tests/skill-trigger-normalize.test.mjs tests/skill-trigger-ceiling.test.mjs`
  - result: 25 pass, 0 fail
- command: `bun test ./extensions/__tests__/*.test.ts` (cwd pi)
  - result: 361 pass, 0 fail
- command: `scripts/workflow-ledger-census diff` (post-baseline)
  - result: exit 0; 94 OK, 18 QUAR pre-existing, none mine
- command: `scripts/workflow-context-budget`
  - result: ok, 7 surfaces within ceiling (verify/plan-loop/review at exact chars, headroom 0)
- command: `scripts/verify-agentic-infra full` (×2)
  - result: 40/40 then 44/45+1-pre-existing-HEAD — PARTIAL prefixes (harness stdin bug, see Follow-up); T7 full rows verified individually above instead
- reviews: plan R1–R4 CHALLENGED → R5 READY; implement IR1 BLOCK (H1/H2/M1/M2) → tour-1 → IR2 BLOCK (H/M/L) → tour-2 → IT1 HOLD (2 HIGH + 3 MED + 1 LOW) → tour-3 → IR3 BLOCK (B1/B2/B3) → tour-4 → IR4 GO + IT2 CLEAR; R3 Logic hunter no-findings; 4 tours, 2 declared overruns (OVERRUN-1 tour-3 thermo, OVERRUN-2 tour-4 R3).

## Follow-up State
- Remaining risks: `verify-agentic-infra` full-profile runs are nondeterministic prefixes (background check children inherit the manifest-read stdin via the while loop and consume rows; observed 40 vs 45 RUN of 111 eligible) — core + individual smokes are the honest gates until fixed; context-budget verify/plan-loop/review at headroom 0 (any description growth re-breaches); workflow-docs-smoke red at HEAD (pre-existing, out of T7 scope).
- Parking lot: staged/unstaged T1–T7 work still uncommitted on main (110+ files; ship decision is the user's); AC4 ponytail removal on macbook-work (user-deferred); no dedicated NONE probe for bug-check's non-Linear boundary (D-impl5 gap, future corpus round).
- Superseded docs/specs: none (all deltas folded into this archive + Decision Log).
- Next links: roadmap tranche 8 (tokens sous protocole).
