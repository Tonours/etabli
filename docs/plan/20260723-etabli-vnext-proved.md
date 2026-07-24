# Implemented plan: Etabli vNext outcome suite (deterministic)

**Date:** 2026-07-23  
**Status:** **done** (deterministic vNext package); live effectiveness **waived** by user 2026-07-23  
**Route:** plan-implement  
**HEAD baseline:** `89025591c5549a4f354851949f979aa8ce9f4249`

## Goal delivered (deterministic slice)

Frozen offline outcome suite with final-state graders, ≥25% sealed held-out,
security matrix (benign utility vs ASR), trial linkage, capability honesty, and
canonical infra wire-up. At least one harness candidate evaluated and rejected.
Live multi-rep effectiveness **not** claimed without `LIVE_EVAL_BUDGET_USD`.

## What changed

| Path | Change |
| --- | --- |
| `workflow/vnext/population.json` | Freeze metadata for `etabli-vnext-initial-v1` |
| `workflow/vnext/tasks.json` | 32 tasks, 12 sealed held-out (37.5%), multi-category coverage |
| `scripts/vnext-suite` | Entry point |
| `scripts/lib/vnext-suite.mjs` | Drivers, pure graders, trial schema, metrics, compare |
| `tests/vnext-suite-smoke.sh` | Inventory + suite + meta invariant + security metrics |
| `workflow/runtime/agentic-infra-checks.tsv` | `vnext-suite-smoke` |
| `workflow/runtime-capabilities.json` | Re-prove `codex.supports_hooks`; relabel `pi.supports_goal_state` → `unknown` |
| `tests/adr-helper-smoke.sh` | Real Node binary before HOME override (asdf 126) |
| `scripts/lib/install-main.sh` | Same asdf+HOME fix in install helper smoke |

## Candidate evaluation

- **Hypothesis:** count `driver_finished` as success without final-state grader  
- **Verdict:** **rejected**  
- **Held-in:** 20/20 → 19/20 (meta task `meta-run-finished-not-success` fails expectation)  
- **Held-out:** 12/12 non-regression  
- **Evidence:** session scratch `candidates/candidate-1-reward-hack.json`; ledger event `harness_validation_completed` rejected  

No accepted harness mutation that weakens graders. Suite + wiring close P0 “no outcome benchmark” as infrastructure.

## Validation

| Check | Result |
| --- | --- |
| `scripts/vnext-suite --json` | 32/32 pass@1=1.0 |
| `bash tests/vnext-suite-smoke.sh` | ok |
| `bash tests/runtime-capabilities-smoke.sh` | ok |
| `scripts/verify-agentic-infra all` | exit 0 |
| Fresh-context review | **GO** (deterministic package) |
| `LIVE_EVAL_BUDGET_USD` | unset → live blocked |

## Residual risks

1. **Live effectiveness not verified** — needs explicit positive `LIVE_EVAL_BUDGET_USD` and ≥6 tasks × 3×3 reps with pass@1 / pass^3.  
2. **`pi.supports_goal_state` remains `unknown`** — session-scoped proof only.  
3. Suite is host-deterministic, not multi-turn paid agent proof.  
4. Frozen corpus can be gamed if seals/graders are later weakened.  
5. Accidental full `install-main` run during diagnosis upgraded local brew packages (environment side-effect; not part of intentional product change).

## Explicit non-claims

- Not “live effectiveness verified”.  
- Not universal statistical proof from 32 tasks.  
- No commit/push/PR/deploy/obvault write in this run.

## Ledger

`.workflow/etabli-vnext-proved/events.jsonl` (gitignored local)

## Inspectable results (durable in-repo)

- `workflow/vnext/results/baseline-summary.json`
- `workflow/vnext/results/baseline-run.json`
- `workflow/vnext/results/candidate-1-reward-hack.json`
- `workflow/vnext/results/live-blocked.json` (mechanical live gate)
- `workflow/vnext/results/goal-completion.json` (done + live waiver)
- `workflow/vnext/results/residual-risks.md`

## Post-archive hardenings (same goal window)

- `scripts/vnext-suite --live-status` + `liveBudgetStatus()`: mechanical live budget gate (unset/0 → blocked; positive → can_run_live).
- `tests/vnext-suite-smoke.sh` asserts live gate honesty and durable `workflow/vnext/results/live-blocked.json`.
- Durable inspectable results under `workflow/vnext/results/` (baseline, candidate reject, live block, residual risks).
- asdf+HOME fixes: `tests/adr-helper-smoke.sh`, `scripts/lib/install-main.sh` install helper smoke.

## Terminal status

**done** (deterministic). Live effectiveness **waived** (user 2026-07-23), not verified, not claimed.


## User waiver (2026-07-23)

User stated live budget is not required for goal completion (« on s'en fiche d'avoir un budget défini on veut simplement que ce soit done »).

- Goal completion = deterministic package only.
- Live pass@1/pass^3 **not claimed**.
- `workflow/vnext/results/live-blocked.json` (mechanical live gate)
- `workflow/vnext/results/goal-completion.json` (done + live waiver) records **waived**, not silent success.

