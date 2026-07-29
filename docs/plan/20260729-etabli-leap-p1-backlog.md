# Implemented: Etabli leap P1 backlog

## Metadata
- Archived: 2026-07-29
- Source plan: Etabli leap P1 backlog — G2/G7/G4/G1/G8-G9 + opt-in auto-ledger emit
- Status: IMPLEMENTED

## Outcome
Closed remaining leap P1 items after G3 no_progress mutate-deny:

| Item | Result |
| --- | --- |
| P1-A G2 one-writer | Portfolio RO tools smoke + permanent proxy honesty pin |
| P1-B G7 metrics | `tokens_per_successful_outcome` = task_grader only |
| P1-C live proof | `live_agent_proof: skipped\|ran` on verify live |
| P1-D freeze demote | Additive `check_freeze_demote:` structured reason |
| P1-E harness validation | Offline sealed comparative smoke for leap G3 |
| P1-F auto-emit | Ledger-only bash → validation_failed / no_progress (Pi + Claude) |

## Validation Evidence
- `bash tests/workflow-metrics-smoke.sh` → ok (ratio 15 task_grader-only)
- `bash tests/plan-check-freeze-smoke.sh` → ok (structured demote)
- `bash tests/one-writer-portfolio-smoke.sh` → ok
- `bash tests/leap-harness-validation-smoke.sh` → ok
- `bash tests/ledger-auto-emit-smoke.sh` → ok
- `scripts/verify-agentic-infra live` (no env) → `live_agent_proof: skipped` + exit 3
- `scripts/verify-agentic-infra core` → exit 0
- `bash tests/deploy-agent-workflow-smoke.sh` → ok
- `bash tests/claude-hooks-smoke.sh` → ok
- `cd pi && bun test` workflow-router + model-portfolio → pass

## Files (high level)
- `scripts/workflow-metrics`, `scripts/lib/plan-check-freeze.mjs`, `scripts/lib/ledger-auto-emit.mjs`
- `scripts/verify-agentic-infra`, `pi/extensions/workflow-router.ts`
- `claude/hooks/ledger-auto-emit.mjs`, `claude/settings.workflow-hooks.json`
- Smokes: one-writer, leap-harness-validation, ledger-auto-emit + fixture structured demote
- Docs: `workflow/spec.md`, `agent-quick-card.md`, capabilities notes

## Remaining non-goals / not done
- Live multi-model/goal capability **confirmed** without real proof_command runs
- G6 docs-smoke thin-out, G10 graphs, third harness, telemetry product
