> Historical snapshot (2026-07-29). Not operational. Canonical: docs/adversary-etabli-10-scorecard.md

# Adversary Etabli 10/10 — baseline scorecard

**Date:** 2026-07-29  
**HEAD:** `586e6d6`  
**Posture:** evidence-only; no charity; scores from local commands + file inspection.

## Suite baseline (captured)

| Command | Exit | Log |
| --- | --- | --- |
| `scripts/verify-agentic-infra core` | 0 | scratch `verify-core-baseline.log` |
| `cd pi && bun test ./extensions/__tests__/*.test.ts` | 0 | `baseline-pi-tests.log` |
| `bash tests/dual-runtime-guard-matrix-smoke.sh` | 0 | `baseline-dual-runtime.log` |
| `bash tests/plan-check-freeze-smoke.sh` | 0 | `baseline-plan-check-freeze.log` |
| `bash tests/workflow-docs-smoke.sh` | 0 | `baseline-workflow-docs.log` |
| `bash tests/runtime-capabilities-smoke.sh` | 0 | `baseline-runtime-cap.log` |
| `bash tests/claude-hooks-smoke.sh` | 0 | `baseline-claude-hooks.log` |
| `bash tests/agent-scenarios-smoke.sh` | 0 | `baseline-agent-scenarios.log` |
| `bash tests/router-eval-smoke.sh` | 0 | `baseline-router-eval.log` |

Guard probe (shared `planMutationGuardDecision`): AC weaken Write deny; Edit remove check deny; MultiEdit remove check deny; demote no rationale deny; bash PLAN.md deny. See scratch `guard-probe.txt`.

## Dimension scores (0–10)

| # | Dimension | Score | Evidence | Gap to ≥9 / 10 |
| --- | --- | --- | --- | --- |
| 1 | Contract clarity | **8.5** | `workflow/spec.md` map; `workflow/agent-quick-card.md` 99 lines; docs-smoke pins. README lacks quick-card pointer. | README + ensure map/details ownership explicit |
| 2 | Routing determinism | **9** | router-eval + agent-scenarios green; dual ops-stop. | Maintain fixtures on new misses only |
| 3 | READY/mutation parity Pi↔Claude | **9** | shared `planMutationGuardDecision`; dual matrix + Pi extension tests; capabilities confirmed. | Claude PreToolUse smoke does not yet assert freeze path |
| 4 | Check-freeze | **8.5** | Runtime denies AC/Edit/MultiEdit/bash (probe); CLI smoke only Checks fixtures; no AC fixture file; no Claude hook process freeze assert | AC fixtures + CLI smoke; Claude hook freeze; Edit/MultiEdit in matrix smoke |
| 5 | Safety / ops-stop | **9** | ops-stop scenarios; filter-output tests; supply-chain in core. | Optional small host-level pin matrix (no new platform) |
| 6 | Multi-model discipline | **9** | portfolio bounds in extension tests; multi-model-orchestration contract; parent-only prose. | Keep proxy honesty on one-writer (not OS lock) |
| 7 | Validation surface | **9** | core green; live opt-in not claimed success. | Keep live skips honest |
| 8 | Memory / obvault | **9** | untrusted pack in skills; routing smoke in suite. | No overclaim |
| 9 | Linear / MCP honesty | **9** | `docs/mcp-strategy.md` OAuth path; `LINEAR_MCP_UNAVAILABLE` in skills | None High |
| 10 | Self-improvement hygiene | **8.5** | self-improvement-loop forbids auto-apply; retrospect read-only. no_progress still largely agent discipline | Mechanical pin or explicit proxy label for no_progress |

**Open High/Critical:** none mechanical.  
**Open Medium (block solid 10 on dims 1/4/10):** coverage holes below.

## Findings

### P1 (High if left untested in adversary review)

1. **AC freeze unfixtured** — code freezes Acceptance Criteria (`scripts/lib/plan-check-freeze.mjs`) and probe denies, but `tests/fixtures/plan-check-freeze/*` and CLI smoke only cover `## Checks`.
2. **Claude hook freeze path unasserted** — `tests/claude-hooks-smoke.sh` exercises READY gate via `plan-ready-guard.mjs` but not a READY PLAN.md weaken Write through the hook process.
3. **README onboarding** — no pointer to `workflow/agent-quick-card.md`.

### P2

4. Dual matrix documents Write weaken; Edit/MultiEdit weaken should be first-class matrix assertions (probe works).
5. Capability `unknown` live claims (subagents, goal_state) correctly non-confirmed; must not date-refresh.
6. one-writer multi-model remains protocol/proxy not OS lock — must stay labelled honest.

### P3

7. Keyword-only Decision Log rationale for freeze demote is coarse.
8. Telemetry experimental — correctly not core; do not expand.

## Ordered patch list (this goal)

1. S1: AC fixtures + plan-check-freeze smoke; dual matrix Edit/MultiEdit; Claude hooks freeze process path; guard-coverage capture.
2. S2: capabilities honesty note + docs alignment if needed (no date-only).
3. S3: README quick card + verify core already present.
4. S4–S6: only if High remains; else honest labels on scorecard.
5. Final scorecard + archive.
