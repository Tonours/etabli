# Implemented: Ledger-backed no_progress mutation deny

## Metadata
- Archived: 2026-07-29
- Source plan: P0 leap — mechanical no_progress mutation deny on active workflow ledger
- Status: IMPLEMENTED
- Branch: main (uncommitted until user commits)

## Outcome
- Host-level deny of ordinary code mutations when any **active** (non-terminal)
  `.workflow/*/events.jsonl` ledger signals no-progress (explicit event or
  derived 2-hypothesis / 3-red thresholds shared with project-autonomy).
- Escape hatch: root `PLAN.md` edits + `scripts/workflow-event`-only bash.
- No auto-emit of validation/no_progress events (P1 remains).

## Context
- `planMutationGuardDecision` is the dual-runtime hard-deny surface (Pi tool_call + Claude PreToolUse).
- Adversary narrowed Goal from “stop thrashing without goodwill” to conditional host gate on ledger evidence.

## Decisions
### Shared pure evaluator
- Context: avoid diverging from project-autonomy thresholds
- Choice: `scripts/lib/no-progress-guard.mjs` owns `derivedNoProgress`; autonomy imports it
- Rejected: copy-paste second algorithm
- Rationale: single source of truth for 2/3 rules

### Escape hatch scope
- Context: deny-all would brick recovery
- Choice: allow PLAN.md + workflow-event CLI only (no chaining/redirects)
- Rejected: open write to `.workflow/**` via Write tool
- Rationale: schema path stays `workflow-event`; PLAN demote for human-visible stop

### Terminal definition
- Choice: ledger terminal if it contains `completed` or `blocked`
- Multi-slug: deny if **any** active ledger stops

## Accepted Drift
- None material. Capability matrix notes updated; no new capability row (guard is part of plan_ready_mutation_guard surface).

## Validation Evidence
- command: `bash tests/no-progress-mutate-deny-smoke.sh` → exit 0
- command: `bash tests/plan-check-freeze-smoke.sh` → exit 0
- command: `bash tests/dual-runtime-guard-matrix-smoke.sh` → exit 0
- command: `bash tests/claude-hooks-smoke.sh` → exit 0
- command: `cd pi && bun test ./extensions/__tests__/workflow-router-extension.test.ts` → 17 pass
- command: `bash tests/project-autonomy-smoke.sh` → exit 0
- command: `scripts/verify-agentic-infra core` → exit 0 (includes no-progress-mutate-deny-smoke)
- command: `git diff --check` → exit 0

## Files
- `scripts/lib/no-progress-guard.mjs` (new)
- `scripts/lib/project-autonomy.mjs` (import shared derived)
- `claude/hooks/workflow-router-lib.mjs` (`planNoProgressGuardDecision`)
- `workflow/runtime/workflow-router-core.mjs` (re-export)
- `tests/no-progress-mutate-deny-smoke.sh` (new)
- `tests/claude-hooks-smoke.sh`, `pi/extensions/__tests__/workflow-router-extension.test.ts`
- `workflow/runtime/agentic-infra-checks.tsv`, `tests/agentic-infra-manifest-smoke.sh`
- `workflow/spec.md`, `workflow/agent-quick-card.md`, `workflow/runtime-capabilities.json`

## Follow-ups (P1)
- Auto-emit `validation_failed` / `no_progress` from tool results (true thrash stop without goodwill)
- G2 one-writer honesty smokes; G7 metrics grader-only success
