# Harness optimization benchmark

Generated: 2026-07-31T23:40:58Z
HEAD: `a762c2085a83f242f58cdd66aea840ba02e673c9`
Branch: `feat/harness-optimization-m1-suite`

## Benchmark A (offline)

| Check | Exit | Notes |
| --- | ---: | --- |
| `scripts/verify-agentic-infra core` | 0 | PASS |
| `scripts/verify-agentic-infra full` | 0 | PASS |
| `scripts/-suite --strategy baseline` | 0 | suite_passed=35 / 35; pass_at_1=1; held_out={'passed': 13, 'total': 13} |

###  security floors
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

Generated: 2026-08-01T00:08:53Z

**Status: measured (live)** — population `multi-model-quality-fixtures-v1` via `RUN_REAL_MULTI_MODEL=1 bash tests/multi-model-real-smoke.sh --quality`.

Artifacts:
- `docs/harness-optimization-bench/live-multi-model-quality-report.json`
- `docs/harness-optimization-bench/live-ab-tokens-throughput.json`

### Arms (success = recall==1 ∧ FP==0)

| Arm | Successes/runs | TokensParSuccès | DébitVérifié /h | mean elapsed ms |
| --- | ---: | ---: | ---: | ---: |
| baseline (single gpt-5.6-terra) | 6/6 | 6214.2 | 202.72 | 17758 |
| panel (council) | 6/6 | 12250.2 | 78.24 | 46015 |
| sol-ceiling | 3/3 | 9707.3 | 213.27 | 16880 |

### Panel vs baseline

| Metric | Ratio panel/baseline | Target | Met? |
| --- | ---: | --- | --- |
| TokensParSuccès | 1.971× | ≤0.50× | False |
| DébitVérifié | 0.386× | ≥2.00× | False |

### Floors (quality)

- baseline recall=1, FP=0
- panel recall=1, FP=0
- non-regression recall/FP: **True**
- multi-model quality gate verdict: **ROLLBACK_TO_OPT_IN**
- failures: tenant-cache: panel tokens exceed 4x baseline, tenant-cache: panel latency exceeds 4x baseline

### Claims

- −50% tokens: **false** (panel uses ~1.97× baseline tokens/success)
- +100% verified throughput: **false** (panel throughput ~0.39× baseline)
- Real agent scenarios: `RUN_REAL_AGENT_SCENARIOS=1` → **ok** (Pi+Claude CLIs)

### Inventory gate

`docs/harness-optimization-inventory.md` has **0** `implement-now` rows; T3 hard caps remain blocked-with-evidence; live B is now **measured**.
