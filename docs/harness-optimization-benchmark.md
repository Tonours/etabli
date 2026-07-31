# Harness optimization benchmark

Generated: 2026-07-31T23:40:58Z
HEAD: `a762c2085a83f242f58cdd66aea840ba02e673c9`
Branch: `feat/harness-optimization-m1-suite`

## Benchmark A (offline)

| Check | Exit | Notes |
| --- | ---: | --- |
| `scripts/verify-agentic-infra core` | 0 | PASS |
| `scripts/verify-agentic-infra full` | 0 | PASS |
| `scripts/vnext-suite --strategy baseline` | 0 | suite_passed=35 / 35; pass_at_1=1; held_out={'passed': 13, 'total': 13} |

### vNext security floors
```json
{
  "benign_utility": 1,
  "benign_utility_counts": {
    "utility_pass": 26,
    "total": 26
  },
  "attack_success_rate": 0,
  "attack_counts": {
    "blocked": 9,
    "total": 9,
    "attack_success": 0
  },
  "note": "ASR is fraction of attack tasks where host failed to block; separate from benign utility"
}
```

### Tail evidence (full)
```
PASS obvault-shadow-promote-smoke (0s)
RUN  autonomous-ledger-hygiene-smoke
autonomous ledger hygiene smoke test: ok
PASS autonomous-ledger-hygiene-smoke (2s)
RUN  workflow-loop-adherence-smoke
workflow-loop-adherence smoke test: ok
PASS workflow-loop-adherence-smoke (3s)
RUN  route-context-manifest-smoke
route-context-manifest smoke test: ok
PASS route-context-manifest-smoke (1s)
RUN  workflow-execution-graph-smoke
workflow-execution-graph smoke test: ok
PASS workflow-execution-graph-smoke (0s)
RUN  workflow-outcome-metric-smoke
builder unit ok
emit helper ok
task_grader demotion ok
workflow-outcome-metric smoke test: ok
PASS workflow-outcome-metric-smoke (1s)
RUN  claude-outcome-metric-emit-smoke
claude-outcome-metric-emit smoke test: ok
PASS claude-outcome-metric-emit-smoke (0s)
RUN  claim-evidence-check-smoke
claim-evidence-check smoke test: ok
PASS claim-evidence-check-smoke (0s)
```

## Benchmark B (live A/B)

| Probe | Exit | Output tail |
| --- | ---: | --- |
| workflow-real-agent-scenarios | 0 | `workflow real agent scenarios: skipped (set RUN_REAL_AGENT_SCENARIOS=1 to run real Pi and Claude CLIs)` |
| multi-model-real-smoke | 0 | `multi-model real smoke: SKIP (set RUN_REAL_MULTI_MODEL=1 and choose --probe-only, --quality, --conversation, --task-rpc, --panel-debug, or --all)` |

### Live TokensParSuccès / DébitVérifié

**Status: blocked-with-evidence**

- No live baseline/candidate population executed with measured parent+sidecar tokens and batch makespan.
- Opt-in env `RUN_REAL_AGENT_SCENARIOS` / `RUN_REAL_MULTI_MODEL` not set; probes skipped honestly (exit 0 skip).
- Offline producers proven (Pi `agent_settled`, Claude Stop hook, CLI). No invented −50% / ×2 claims.

**Needed input:** `RUN_REAL_AGENT_SCENARIOS=1` and/or `RUN_REAL_MULTI_MODEL=1` with provider auth + frozen population id.

## Inventory gate

`docs/harness-optimization-inventory.md` has **0** `implement-now` rows remaining (T3 hard caps remain `blocked` with evidence).
