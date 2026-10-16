---
status: accepted
date: 2026-10-16
supersedes: [ADR-0026, ADR-0028]
tags: [tooling, simplification, verification, ledger, tests]
affected_components: [scripts/workflow-event, scripts/plan-cleanup, scripts/deploy-workflow, scripts/lib/plan-status.mjs, workflow/runtime/agentic-infra-checks.tsv, PLAN_TEMPLATE.md, PLAN_TEMPLATE_FULL.md]
---

# Drop the eval, ledger, product-verification and freeze tooling

Four subsystems leave Etabli because nothing in the daily Pi and Claude loop depended on them. Skill and token evals go (`token-bench`, `skill-eval`, `skill-trigger-*`, `workflow/self-improvement/`, `workflow/skills/skill-evaluation.md`). Ledger tooling goes (`workflow-lease`, `workflow-ship-metrics`, `workflow-ledger-census`, `docs/workflow-statistics.md`); the event ledger itself stays. Source-bound product verification goes (`project-verification*`, `workflow/product-verification.md`, the recipe schema, the scaffold `verification/` templates); plans lose the `## Product Verification` section, and `workflow-event` and `plan-cleanup` no longer gate on a product receipt. `plan-check-freeze` and the unused `pr-latest-head-status` go too. `parsePlanStatus` moves to `scripts/lib/plan-status.mjs`. Prose-only smoke tests that pinned doc wording are removed in bulk.

## Consequences

- Product ACs are still proven by observed evidence from existing tests or a direct run, without a shared recipe runner.
- `scripts/lib/workflow-event-detail.jq` still accepts the `product_*` fields so older ledgers stay valid.
- ADR-0028's per-worktree lease and ADR-0026's harness eval no longer have code; this supersedes both.
