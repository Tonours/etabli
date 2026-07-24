# Implemented: harness audit fixes C1–C8

## Metadata
- Archived: 2026-07-24
- Source: `docs/etabli-harness-audit-20260724.md` §8–9
- Status: IMPLEMENTED
- Branch: main (uncommitted worktree preserved)

## Outcome
Landed audit reliability fixes without new business loops:

| ID | Fix | Surface |
| --- | --- | --- |
| C1 | Mechanical check-freeze | `scripts/plan-check-freeze`, fixtures, smoke |
| C2 | Pi READY mutation parity | shared `planReadyGuardDecision` on Pi `tool_call` |
| C3 | `live_agent_proof: skipped\|ran` | `scripts/verify-agentic-infra` |
| C4 | Capability re-proof | `workflow/runtime-capabilities.json` (deterministic proofs 2026-07-24) |
| C5 | outcome success kinds | `success_kind` / `grader_success` + metrics denominators |
| C6 | Autonomous ledger hygiene | `tests/autonomous-ledger-hygiene-smoke.sh` + impl-loop pin |
| C7 | Docs-smoke + behavioral pin | plan-check-freeze helper assertion in docs-smoke |
| C8 | Dual-runtime guard matrix | `tests/dual-runtime-guard-matrix-smoke.sh` |
| C9 | **No-op** | No new vNext tasks; C1–C8 sufficient; capacity reserved for real failures |

## Decisions
### C9 no-op
- Context: optional after C1–C8 green
- Choice: skip new population tasks this cycle
- Reason: no new graded daily-task failures mined in-session; avoid synthetic tasks

### C4 live claims
- `pi.supports_subagents` and `pi.supports_taskexecute_tracking` **relabelled `unknown`** (2026-07-24): offline re-run requires `RUN_REAL_MULTI_MODEL=1`; no date-only refresh

## Validation Evidence
- `tests/plan-check-freeze-smoke.sh`: ok
- Pi READY guard tests: 14 pass (workflow-router-extension)
- `tests/dual-runtime-guard-matrix-smoke.sh`: ok
- `tests/autonomous-ledger-hygiene-smoke.sh`: ok
- `tests/workflow-metrics-smoke.sh`: ok
- `tests/runtime-capabilities-smoke.sh`: ok
- `tests/agent-scenarios-smoke.sh`: ok
- `live_agent_proof: skipped` under default env
- `scripts/verify-agentic-infra all`: **exit 0**
- `git diff --check`: see session log (pre-existing dirty paths may differ)

## Follow-up
- Re-proof `pi.supports_subagents` / `taskexecute_tracking` before 2026-07-26 if still needed as confirmed/proxy
- Mine real daily failures into vNext (C9) later
