# Etabli leap — Pass C candidates

**Date:** 2026-07-29  
**Inputs:**  
- Pass A: `docs/research/20260729-etabli-leap-baseline.md`  
- Pass B: `docs/research/deep-research-runs/0{1..4}-*.md` (all **Partial**)  
**Filter:** only claims that survived deep-research verifiers; map to G1–G10; reject second-harness / auto-apply / PLAN.md replacement.

## Claim → gap transfer table

| ID | Survived claim (compressed) | Report | Gaps | Cost | Decision |
| --- | --- | --- | --- | --- | --- |
| C-01 | Mid-session stop is host refuse (tool/write/continuation), not prompt | 01 | G3 | M | **P0** |
| C-02 | Ledger `no_progress` + thresholds (2 hyp / 3 red) without mutate-block stay soft | 01 | G3 | M | **P0** (same ship) |
| C-03 | Single-writer = tool allowlist + sandbox read-only + admission hooks; not OS lock | 01, 03 | G2 | S–M | **P1** |
| C-04 | Schema `writer: parent-only` alone is protocol | 01 | G2 | S | **P1** (honesty pin) |
| C-05 | Claude Stop thrashing override (8-block cap) is host-level anti-loop | 01 | G3 | L | **P2** (host-specific; optional later) |
| C-06 | Codex anti-spin: suppress auto-continue after tool-less turn + budget stop | 01 | G3, G5 | L | **P2** (goal_state / host) |
| C-07 | Retry budget for identical write content (tool policy) | 01 | G3 | M | **P2** |
| C-08 | Sealed held-in/held-out acceptance for harness changes | 02, 04 | G8, G9 | S | **already shipped** (schema); cadence P1 |
| C-09 | Task success = final-state grader only; reject “run finished” | 02, 04 | G7 | S–M | **P1** |
| C-10 | pass@1 / pass^k on non-deterministic subsets only | 02 | G8 | M | **P2** (live budget) |
| C-11 | Capability matrix: expiry + proof_command; never date-only refresh | 02 | G4, G5 | S | **already shipped**; keep discipline |
| C-12 | Multi-agent hops ≠ quality; ~15× token tax | 02, 03 | G10 | — | **reject** expansion |
| C-13 | Multi-agent helps breadth-first read-heavy / multi-axis review / verifier loops | 03 | G2, G10 | — | **keep** current multi-model design |
| C-14 | Write path: single continuous reasoner; no parallel co-edit | 03 | G2 | — | **keep** (ADR + contract) |
| C-15 | Minimum control plane: one parent, budgets, isolation, verification — not second stack | 03 | G10 | — | **reject** G10 expansion |
| C-16 | Safe self-improve: sealed holdout + independent grader + READY/human; never auto-apply | 04 | G9 | S | **already shipped**; use for this P0 process |
| C-17 | Comparative `harness_validation_completed` with per-candidate deltas | 04 | G9 | S | **P1 process** after P0 |

## Ranked ship candidates

### P0 — selected: **G3 mechanical no_progress mutate-deny on active ledger**

| Field | Value |
| --- | --- |
| **Title** | Host-level mutation deny when ledger signals no-progress (explicit event or derived 2/3 thresholds) |
| **Gap** | G3 (+ honesty label for non-ledger sessions) |
| **External pattern** | C-01, C-02 — host refuse tool/write; ledger alone insufficient |
| **Local surfaces** | `scripts/lib/project-autonomy.mjs` (`derivedNoProgress`); `planMutationGuardDecision` (Claude PreToolUse + Pi `tool_call`); dual-runtime smokes |
| **Mechanism** | Pure shared evaluator + call from mutation guard when non-terminal `.workflow/*/events.jsonl` present |
| **Success signal** | Fixture: ledger with `no_progress` **or** 3× same `validation_failed` without `file_changed` → Write/Edit/mutating bash **denied** with reason matching `no_progress`; after `file_changed` + fresh failures below threshold → allow (if READY otherwise); no ledger → READY behavior unchanged |
| **Effort** | M (shared lib + guard wiring + smokes + docs pin) |
| **ADR risk** | Low — strengthens determinism; no new harness; no PLAN replacement |
| **Auto-apply?** | No — ships via READY plan only |
| **Out of P0** | Claude Stop-hook thrashing cap product feature; Codex anti-spin; identical-write retry budget; forcing ledger on every ordinary answer route |

### P1 backlog (after P0)

| Cand | Gap | One-liner |
| --- | --- | --- |
| P1-A | G2 | Audit portfolio/Claude read-only tool pins; permanent **proxy** label where no OS lock; smoke that scout roles lack write/edit |
| P1-B | G7 | `workflow-metrics` / outcome success null or reject without final-state grader / AC evidence |
| P1-C | G4/G5 | Budgeted live proof → relabel unknown; verify summary `live_agent_proof: ran\|skipped` |
| P1-D | G1 | Structured freeze demote reason (beyond keyword) |
| P1-E | G8/G9 | Optional weekly sealed offline sample + one `harness_validation_completed` for this leap P0 |

### P2 / reject

| Cand | Decision | Why |
| --- | --- | --- |
| G6 docs-smoke thin-out | **done** (2026-07-29) | Thinned workflow-docs-smoke; behavioral smokes own phrase contracts |
| G10 named workflow graphs expand | **reject** | C-12, C-15 — second stack / low coding ROI |
| Multi-agent permanent swarm | **reject** | C-12, C-14 |
| Auto-apply self-improve | **reject** | C-16 |
| Telemetry product expansion | **reject** | non-goal |
| Third harness tree | **reject** | ADR-0011 |

## Ranking rationale (post Pass B)

1. **G3 still #1** — all four reports reinforce: soft protocol ≠ reliability; host must deny. Etabli already has schema + envelope controller; missing piece is **mutation gate coupling**.
2. **G2 is P1 not P0** — allowlists/admission already exist on Pi portfolio; residual is honesty + Claude parity + tests, not a greenfield mechanism.
3. **G7 is high ROI but smaller leap** —  already final-state; residual is metrics laundering — ship after G3.
4. **Self-improvement machinery already exists** — leap value is shipping P0 *through* it (comparative event), not redesigning the loop.
5. **Orchestration research validates current architecture** — do not expand multi-agent graphs.

## Pass C checklist

- [x] Merge survived claims → transfer table  
- [x] Rank P0/P1/P2/reject  
- [x] Select single P0 with mechanical success signal  
- [ ] Root `PLAN.md` READY for that P0 only  
- [ ] Implement + validate (separate once READY)

## Non-goals held

Same as Pass A: no parallel harness, no telemetry product, no PLAN dual-write, no framework rewrite, no auto-apply.
