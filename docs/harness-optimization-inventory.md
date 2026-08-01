# Harness optimization inventory (performance / tokens / loops)

**Date:** 2026-07-31  
**Branch target:** `feat/harness-optimization-m1-suite`  
**Scope:** Etabli Pi+Claude harness; no swarm/Neo4j/vector DB/auto-apply

Status legend: `already-shipped` | `implement-now` | `blocked`  
Evidence classes: `offline` | `live` | `blocked-with-evidence`

| ID | Item | Class | Status | Evidence |
| --- | --- | --- | --- | --- |
| M1-schema | outcome_metric participant_usage + batch fields | already-shipped | offline | scripts/lib/workflow-event-detail.jq; tests/workflow-event-smoke.sh |
| M1-metrics | tokens_per_success + verified_throughput | already-shipped | offline | scripts/workflow-metrics; tests/workflow-metrics-smoke.sh |
| M1-builder-cli | builder + workflow-outcome-metric CLI | already-shipped | offline | scripts/lib/outcome-metric-builder.mjs; scripts/workflow-outcome-metric |
| M1-pi-producer | Pi agent_settled emit | already-shipped | offline | pi/extensions/workflow-router.ts; tests/workflow-outcome-metric-smoke.sh |
| M1-claude-producer | Claude Stop hook usage→outcome_metric | already-shipped | offline | claude/hooks/outcome-metric-emit.mjs; tests/claude-outcome-metric-emit-smoke.sh |
| M1-task-grader-gate | task_grader only with real grader flag | already-shipped | offline | scripts/lib/outcome-metric-builder.mjs; tests/workflow-outcome-metric-smoke.sh |
| T1-manifests | route-context-manifests.json + check | already-shipped | offline | workflow/route-context-manifests.json |
| T1-loader | inject manifest into Pi+Claude route guidance | already-shipped | offline | pi + claude router guidance; workflow-router-runtime.test.ts |
| T2-symbol-first | symbol/delta-first progressive disclosure | already-shipped | offline | workflow/route-context-manifests.json progressive_disclosure |
| T3-tool-caps | hard tool output caps | blocked | blocked-with-evidence | no reproduced thrash failure justifying host caps; guidance only via T2 |
| H1-ucr | claim/evidence checker offline | already-shipped | offline | scripts/claim-evidence-check; tests/claim-evidence-check-smoke.sh |
| L1-adherence | workflow-loop-adherence core | already-shipped | offline | scripts/workflow-loop-adherence |
| L1-chaos | order/BLOCK/post-stop fixtures | already-shipped | offline | tests/workflow-loop-adherence-smoke.sh |
| G1-exec-graph | derived execution graph | already-shipped | offline | scripts/workflow-execution-graph |
| G2-claim-graph | claim→evidence graph view | already-shipped | offline | claim-evidence-check --json .graph |
| BENCH-A | core+full targeted +  + new smokes | already-shipped | offline | docs/harness-optimization-benchmark.md |
| BENCH-B | live A/B TokensParSuccès + DébitVérifié | already-shipped | live | docs/harness-optimization-bench/live-ab-tokens-throughput.json; panel vs baseline measured; targets not met |
| INV-exhaust | this inventory exhaustive classification | already-shipped | offline | docs/harness-optimization-inventory.md |
| NO-swarm | reject permanent multi-agent swarm | already-shipped | offline | multi-model-orchestration.md |
| NO-graphdb | reject Neo4j day-1 | already-shipped | offline | obvault-memory.md derived graph |
| NO-auto-apply | reject harness auto-apply | already-shipped | offline | self-improvement-loop.md |

## Classification rules

- `implement-now`: offline fixtureable or hook surface exists today
- `already-shipped`: code+smoke already green on branch worktree
- `blocked`: needs live provider proof, unreproduced failure, or forbidden architecture

## Done criteria mapping

1. Inventory versioned under `docs/` — this file  
2. 100% implement-now shipped — update Status column to already-shipped with proof  
3. Benchmark A — `docs/harness-optimization-benchmark.md`  
4. Benchmark B — same file, live section or blocked-with-evidence  
