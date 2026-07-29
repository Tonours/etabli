# Etabli leap — Pass A baseline (local)

**Date:** 2026-07-29  
**HEAD:** `54a63b5` (`main`)  
**Posture:** read-only gap inventory for a quality / determinism leap  
**Not operational:** canonical contract remains `workflow/spec.md` + ADRs  

## 1. What this baseline is

Pass A freezes **what is already solid** vs **what is still proxy / unknown / soft**, so external deep research does not rediscover shipped work and so implementation candidates can be ranked against real local gaps.

**Core suite re-proved this session:**

```text
scripts/verify-agentic-infra core  → exit 0
  plan-check-freeze-smoke          → ok
  dual-runtime-guard-matrix-smoke  → ok (matrix printed below)
  … remaining core smokes          → ok
```

## 2. Capability matrix (live from dual-runtime smoke)

| Capability | Label | Implication for leap |
| --- | --- | --- |
| `pi.supports_hooks` | **confirmed** | Do not re-design hook surface |
| `pi.plan_ready_mutation_guard` | **confirmed** | Parity work largely closed |
| `pi.check_freeze_guard` | **confirmed** | P0 from 2026-07-24 audit is closed |
| `pi.supports_subagents` | **unknown** | Needs opt-in live proof, not doc refresh |
| `pi.supports_taskexecute_tracking` | **unknown** | Same |
| `pi.supports_goal_state` | **unknown** | Host/session-scoped; offline-unprovable |
| `pi.supports_structured_task_state` | **confirmed** | Keep |
| `pi.supports_named_workflow_graphs` | **proxy_supported** | Adapter proof only, not OS sandbox |
| `claude.supports_hooks` | **confirmed** | Keep |
| `claude.plan_ready_mutation_guard` | **confirmed** | Keep |
| `claude.check_freeze_guard` | **confirmed** | Keep |
| `claude.supports_subagents` | **unknown** | Live Agent-tool only |
| `claude.supports_goal_state` | **unknown** | Live `/goal` only |
| `claude.supports_structured_task_state` | **blocked** | Honest non-capability |
| `claude.supports_taskexecute_tracking` | **blocked** | Pi-only semantics |
| `claude.supports_named_workflow_graphs` | **blocked** | Pi-only adapter |

## 3. Intouchable invariants (do not re-open without ADR)

| Invariant | Evidence class | Primary refs |
| --- | --- | --- |
| Single execution artifact `PLAN.md` | confirmed | ADR-0002, agent-scenarios |
| Thin adapters over shared contract | confirmed | ADR-0006, ADR-0011 |
| Deterministic routing / ops-stop guards | confirmed | ADR-0007, router-eval |
| READY + check-freeze shared `planMutationGuardDecision` | confirmed | dual-runtime matrix, plan-check-freeze |
| Pi + Claude only (no Codex/Kimi harness tree) | confirmed | ADR-0011 |
| Self-improvement never auto-applies harness | confirmed | self-improvement-loop + event schema |
| Obvault = durable memory; Etabli = execution | accepted/verified kb | ADR execution-vs-memory |
| Prefer single reasoner + bounded subagents over decorative multi-agent | verified kb | `kb/single-reasoner-over-multi-agent-pipeline` |

## 4. Closed since 2026-07-24 audit (do not re-propose as P0)

Historical audit `docs/etabli-harness-audit-20260724.md` listed P0s that **adversary-10 closed**:

| Old P0 | Status 2026-07-29 |
| --- | --- |
| C1 mechanize check-freeze | **closed** — `scripts/plan-check-freeze` + dual matrix + Claude PreToolUse |
| C2 Pi READY mutation parity | **closed** — shared `planMutationGuardDecision` on Pi `tool_call` |
| C3 skip-vs-live honesty | **partial** — capabilities stay `unknown` rather than date-refresh; still no default live proof in core |

Scorecard: `docs/adversary-etabli-10-scorecard.md` — all dimensions ≥9, High/Critical = 0.

## 5. Residual gap statements (measurable)

Each gap is a statement that deep research or implementation can attack. Labels: **local-only** (no web needed) vs **research-informed** (Pass B useful).

### G1 — Freeze demote rationale is keyword-soft
- **Statement:** A READY weaken is allowed if Decision Log matches `/check-freeze|weaken|weakened|removed check|demot/i` (`scripts/lib/plan-check-freeze.mjs`), not a structured reason field.
- **Proof missing:** adversarial fixtures for false-positive demote (keyword spam) and false-negative (real demote poorly worded).
- **Success signal:** structured demote reason OR tighter rationale schema + fixture pair; `plan-check-freeze-smoke` green.
- **Class:** local-only (small), research-informed for “policy reason schemas” patterns.
- **Priority seed:** P1 Low→Medium

### G2 — one-writer multi-model is protocol, not kernel
- **Statement:** Parent-only writer is contract + honesty labels, not an OS/file lock across sidecars.
- **Proof missing:** mechanical deny when a non-parent path mutates tree during multi-model (or explicit permanent `proxy` with no pretence of OS lock).
- **Success signal:** either (a) confirmed enforcement with smoke, or (b) documented permanent proxy + eval that fails if docs claim OS lock.
- **Class:** research-informed (how others enforce single-writer) + local.
- **Priority seed:** P1

### G3 — `no_progress` mid-session is agent discipline
- **Statement:** Event type + project-autonomy envelope exist; ordinary plan-implement/implement sessions are not continuously forced to stop on 2 hyp / 3 red without agent cooperation.
- **Proof missing:** runtime path that emits/halts on no_progress without relying on model goodwill for non-envelope routes.
- **Success signal:** fixture or hook/extension path that records `no_progress` and blocks further mutate when thresholds hit; or honest permanent proxy for non-envelope routes only.
- **Class:** research-informed + local.
- **Priority seed:** P0 candidate for leap (highest soft→hard leverage)

### G4 — Live multi-model / subagents remain `unknown`
- **Statement:** Default CI green does not prove live multi-model or TaskExecute RPC.
- **Proof missing:** `RUN_REAL_MULTI_MODEL=1` (and Claude live Agent-tool) recorded proof_result with date.
- **Success signal:** capability matrix labels move `unknown`→`confirmed|blocked` with non-stale proof; verify summary can print `live_agent_proof: ran|skipped`.
- **Class:** local/ops (budgeted live run), not web research.
- **Priority seed:** P1 (honesty + optional CI job)

### G5 — `/goal` / goal_state unproven offline
- **Statement:** `supports_goal_state` is session-scoped for Pi; Claude unknown; structured completion verification host-dependent.
- **Proof missing:** live `/goal` evidence packet (outcome + evidence + stop) on both surfaces or explicit blocked.
- **Success signal:** relabel + optional smoke contract; do not invent offline proof.
- **Class:** local/ops.
- **Priority seed:** P1

### G6 — Docs-smoke density vs behavioral proof
- **Statement:** Large string-pin suite protects prose parity; high maintenance; weak signal for agent outcome quality.
- **Proof missing:** inventory of docs-smoke pins that duplicate already-mechanized guards; candidate retire list.
- **Success signal:** pin count down without losing contract coverage; behavioral smokes cover same invariants.
- **Class:** local-only.
- **Priority seed:** P2 hygiene

### G7 — Outcome metrics may count “run completed” as success
- **Statement:** `tokens_per_successful_outcome` and ledger success semantics can reward completion over graded task success (audit residual).
- **Proof missing:** schema/grader that rejects meta-run-finished-as-success everywhere ledgers feed productivity metrics.
- **Success signal:** metrics null or error when success lacks grader/AC evidence; fixture proves refusal.
- **Class:** research-informed (eval/metric design) + local.
- **Priority seed:** P1

### G8 — Reward-hacking residual on optional daily eval
- **Statement:**  + held-out + adversary exist; daily usage of grader-backed population is optional.
- **Proof missing:** small recurring sealed sample tracked over time (population_id), even if mostly offline.
- **Success signal:** documented weekly/CI-optional job; trend artifact without expanding telemetry product surface.
- **Class:** research-informed + local.
- **Priority seed:** P1

### G9 — Self-improvement comparative credit underused
- **Statement:** `harness_validation_completed` schema supports held-in/held-out comparative credit; operational cadence for mining→validate→READY is manual.
- **Proof missing:** last N harness candidates with comparative events vs empty.
- **Success signal:** at least one leap P0 ships via self-improvement path with comparative event evidence.
- **Class:** process/local.
- **Priority seed:** P1 (process)

### G10 — Named workflow graphs only proxy on Pi
- **Statement:** `@agwab/pi-workflow` adapter is proxy_supported; Claude blocked.
- **Proof missing:** whether named graphs add value over Etabli routes without dual harness.
- **Success signal:** adopt with confirmed proof **or** demote/remove from claims surface.
- **Class:** research-informed (orchestration graphs vs simple workflows).
- **Priority seed:** P2 (likely reject expansion)

## 6. Gap ranking seed (pre–Pass B)

| Rank | Gap | Why |
| --- | --- | --- |
| 1 | **G3** no_progress enforcement | Soft mid-session stop is the largest honesty→mechanics leap |
| 2 | **G2** one-writer enforcement or permanent proxy | Multi-model residual; scorecard dim 6 |
| 3 | **G7** success metric semantics | Prevents gaming “green runs” |
| 4 | **G4/G5** live capability honesty | Unknown→confirmed/blocked without marketing drift |
| 5 | **G1** freeze rationale structure | Small hardening on already-strong freeze |
| 6 | **G8** recurring grader sample | Quality floor beyond docs pins |
| 7 | **G9** self-improvement cadence | Closes loop with evidence |
| 8 | **G6/G10** hygiene / non-expansion | Protect focus |

**Non-goals for this leap (hold):**

- New parallel agent harness tree
- Telemetry product expansion
- Replacing PLAN.md
- Framework hop (LangGraph, Crew, etc.) as architecture rewrite
- Nvim / Ghostty feature work
- Auto-apply harness patches

## 7. Sources already consumed (do not re-deep-research as “what is etabli”)

| Artifact | Role |
| --- | --- |
| `docs/adversary-etabli-10-scorecard.md` | Residual lows + dimension scores |
| `docs/adversary-etabli-10-baseline.md` | Pre-slice P1 list |
| `docs/plan/20260729-etabli-adversary-10.md` | What just shipped |
| `docs/etabli-harness-audit-20260724.md` | Historical map (partially stale P0s) |
| `docs/agentic-workflow-hardening.md` | External source matrix (older) |
| `workflow/runtime-capabilities.json` | Live labels |
| `kb/single-reasoner-over-multi-agent-pipeline` | Multi-agent caution |
| `kb/etabli-self-improvement-harness-contract` | No autonomous harness patch |
| `kb/synthesis-harness-skills-multi-agent` | Consolidated harness notes |

## 8. Pass A deliverable checklist

- [x] Fresh `verify-agentic-infra core` exit 0
- [x] Capability matrix snapshot
- [x] Closed vs open gap separation
- [x] Measurable gap statements G1–G10
- [x] Seed ranking + non-goals
- [x] Pass B external claims (`docs/research/deep-research-runs/`)
- [x] Pass C candidate table with P0/P1/reject (`docs/research/20260729-etabli-leap-candidates.md`)

## 9. Next

1. ~~Run four deep-research prompts~~ done.
2. ~~Pass C candidates~~ done — P0 = G3 ledger mutate-deny.
3. Root `PLAN.md` is **READY** for that single P0; implement via plan-implement / implement route.
