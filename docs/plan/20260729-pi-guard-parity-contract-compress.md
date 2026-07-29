# Implemented: Pi guard parity + contract compress

## Meta
- Date: 2026-07-29
- Source: goal « Pi guard parity + contract compressé »
- Route: plan-implement (self-improvement)

## Goal
Close Pi ↔ Claude READY/mutating asymmetry, enforce check-freeze on PLAN.md
tool writes, compress the agent contract entry, and align Linear MCP promises.

## Changes
- Shared `planMutationGuardDecision` = READY gate + check-freeze on PLAN.md
  writes (`claude/hooks/workflow-router-lib.mjs`), re-exported via
  `workflow/runtime/workflow-router-core.mjs`.
- Claude `plan-ready-guard.mjs` and Pi `tool_call` both call the shared path.
- `parseChecks` freezes Checks **and** Acceptance Criteria.
- Bun extension tests for Pi READY deny + check-freeze; dual-runtime matrix
  expanded; capability claims `plan_ready_mutation_guard` /
  `check_freeze_guard` confirmed for Pi and Claude.
- `workflow/agent-quick-card.md` (≤120 lines); `workflow/contract-details.md`;
  `workflow/spec.md` compressed map (~188 lines) with pin-compatible rules.
- Linear option A: OAuth enable steps in `docs/mcp-strategy.md`; skills keep
  `LINEAR_MCP_UNAVAILABLE` degrade + pointer.

## Non-goals preserved
- No telemetry surface expansion.
- No new harness tree.
- No commit/push/PR/external write in this run.

## Validation
| Command | Result |
| --- | --- |
| `scripts/verify-agentic-infra core` | EXIT 0 |
| `cd pi && bun test ./extensions/__tests__/*.test.ts` | EXIT 0 |
| `bash tests/dual-runtime-guard-matrix-smoke.sh` | EXIT 0 |
| `bash tests/plan-check-freeze-smoke.sh` | EXIT 0 |
| `bash tests/workflow-docs-smoke.sh` | EXIT 0 |
| `bash tests/runtime-capabilities-smoke.sh` | EXIT 0 |
| `bash tests/claude-hooks-smoke.sh` | EXIT 0 |
| `bash tests/agent-scenarios-smoke.sh` | EXIT 0 |
| `git diff --check` | EXIT 0 |

## Capability reclass
| Claim | Before | After |
| --- | --- | --- |
| Pi READY mutation | approximate (audit) | **confirmed** `plan_ready_mutation_guard` |
| Check-freeze runtime | prose/CLI only | **confirmed** `check_freeze_guard` |

## Notes
- `PLAN.md` **missing** still allows ordinary mutations (pre-existing design:
  gate is DRAFT/CHALLENGED, not “always need a plan”). Documented in capability
  notes and quick card.
- Fresh-context review: **GO WITH NOTES** then residual under-denies fixed
  (bash→PLAN.md deny; Edit reconstruct fail-closed; demote-without-rationale
  fixture; spec checkpoint wording). Re-ran core + matrix + pi tests → EXIT 0.

## Archive
This file is the distilled archive for the goal slice.
