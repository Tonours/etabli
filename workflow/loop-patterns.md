# LLM Loop Patterns

Use the smallest pattern whose verifier can prove the goal. A loop is a bounded
control policy, not permission to broaden scope or perform external writes.

| Pattern | Use when | Required verifier | Default cap |
| --- | --- | --- | --- |
| `direct` | One low-risk change with a deterministic check | focused check | 1 pass |
| `localize-repair-validate` | Coding/debugging with an observable failure | failing-then-passing check | 3 iterations |
| `react` | The next action depends on tool/runtime evidence | observation after every action | 5 actions |
| `self-refine` | A rubric can improve a draft | same rubric before/after | 2 passes |
| `planner-builder-evaluator` | Broad/risky work crosses concerns | independent evaluator when available | 2 repair rounds |
| `parallel-sections` | Work units have independent ownership | integration check | bounded by authorized workers |
| `tree-search` | Several plausible branches and a cheap evaluator exist | branch score plus backtrack log | depth 2, width 3 |
| `scheduled-idempotent` | Recurring report/maintenance work | idempotence and last-run evidence | one run per cadence |

## Universal contract

Every non-trivial loop names: goal verifier; iteration, elapsed-time, token/tool
budget when observable; context-reset threshold; escalation/stop condition; and
permissions. Stop on success, exhausted budget, repeated no-progress, safety or
permission boundary, or required user input. Missing telemetry is `unmeasured`,
never zero. Record rejected hypotheses and do not redo them after handoff.

Use ReAct observations only when evidence changes the next action. Self-refine is
advisory for code unless a distinct evaluator supplies completion evidence.
Parallel work requires independent files/ownership plus user/runtime authority.
Tree search requires an explicit branching reason and cheap deterministic score.

## Context handoff

Create a handoff at a slice/runner boundary or before context degradation. It
contains goal, current state, last verifier result, changed paths, failed
hypotheses, next action, and a do-not-redo list. Grade the final state first;
audit process only for READY, permission, safety, review, and evidence invariants.
