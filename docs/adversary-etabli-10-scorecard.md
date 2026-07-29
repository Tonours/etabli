# Adversary Etabli 10/10 — final scorecard

**Date:** 2026-07-29  
**Baseline:** `docs/adversary-etabli-10-baseline.md` (HEAD `586e6d6` + this slice)  
**Verdict target:** solid 10 = zero High/Critical open, every dimension ≥9, mechanical evidence only.

## Suite (final)

| Command | Exit |
| --- | --- |
| `scripts/verify-agentic-infra core` | 0 (see scratch `verify-core.log`) |
| `cd pi && bun test ./extensions/__tests__/*.test.ts` | 0 |
| `bash tests/dual-runtime-guard-matrix-smoke.sh` | 0 |
| `bash tests/plan-check-freeze-smoke.sh` | 0 |
| `bash tests/claude-hooks-smoke.sh` | 0 |
| `bash tests/agent-scenarios-smoke.sh` | 0 |
| `bash tests/router-eval-smoke.sh` | 0 |
| `bash tests/runtime-capabilities-smoke.sh` | 0 |
| `bash tests/workflow-docs-smoke.sh` | 0 |
| `git diff --check` | 0 |

Guard coverage matrix: scratch `guard-coverage.txt` (Write/Edit/MultiEdit/AC weaken deny; demote±rationale; bash PLAN.md; Claude `plan-ready-guard` process deny).

## Dimension scores

| # | Dimension | Score | Evidence | Open High/Critical |
| --- | --- | --- | --- | --- |
| 1 | Contract clarity | **9.5** | Quick card ≤120 (`workflow/agent-quick-card.md`); map `workflow/spec.md`; details `workflow/contract-details.md`; README Map points to quick card + verify core; docs-smoke pins | none |
| 2 | Routing determinism | **9.5** | router-eval-smoke 0; agent-scenarios 0 (ops-stop, prompt-only READY, real-ready-implements, etc.) | none |
| 3 | READY/mutation parity Pi↔Claude | **9.5** | Shared `planMutationGuardDecision`; dual-runtime matrix; Pi extension tool_call tests; Claude PreToolUse process path; capabilities `plan_ready_mutation_guard=confirmed` | none |
| 4 | Check-freeze | **9.5** | CLI AC fixtures; dual matrix Edit/MultiEdit/AC; Claude hook Write/Edit/Bash freeze deny; demote without rationale deny | none |
| 5 | Safety / ops-stop | **9** | agent-scenarios destructive/external-writeback; dual ops-stop; filter-output suite; supply-chain in core | none (no new host ASR platform) |
| 6 | Multi-model discipline | **9** | Portfolio bounds tests; multi-model-orchestration; one-writer labelled **protocol/proxy not OS lock** (README + capabilities + quick card) | none |
| 7 | Validation surface | **9.5** | core 0; live opt-in separate; no skip-as-success in core path | none |
| 8 | Memory / obvault | **9** | untrusted pack contract; obvault smokes in full profile; no overclaim in this slice | none |
| 9 | Linear / MCP honesty | **9.5** | OAuth enable path `docs/mcp-strategy.md`; skills `LINEAR_MCP_UNAVAILABLE`; template `$linear_gap` | none |
| 10 | Self-improvement hygiene | **9** | self-improvement-loop never auto-apply (docs-smoke pin); workflow-event rejects auto-apply candidate; no_progress event type pinned; agent discipline remains **proxy** for mid-session stop (honest, not confirmed OS) | none |

**High/Critical open:** 0  
**Mean (honest):** all dimensions ≥9 → solid adversary 10 under plan definition (not marketing 10 on live-only surfaces).

## Residual Low (accepted)

1. Decision Log freeze rationale is keyword-based (`check-freeze|weaken|demot`).
2. one-writer / no_progress mid-session are protocol, not kernel enforcement — labelled proxy/protocol.
3. Live multi-model / goal_state remain `unknown` until opt-in live proof (correct honesty).
4. Telemetry still experimental; not expanded (by design).

## Non-goals held

- No telemetry feature surface expansion in diff.
- No new parallel harness tree.
- No confirmed labels without proof_command.

## Closure

Baseline P1 items (AC fixtures, Claude hook freeze path, README quick card) closed in this slice. Archive: `docs/plan/20260729-etabli-adversary-10.md`.
