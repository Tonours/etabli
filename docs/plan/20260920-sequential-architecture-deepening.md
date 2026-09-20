# Implemented: sequential architecture deepening with TypeSafe review

## Metadata

- Archived: 2026-09-20
- Source plan: `PLAN.md` — implement five architecture opportunities sequentially
- Source plan SHA-256: `5562b260689e3fbd996b18b16cdf0983e2ccc6ed49d36d26a19891d6779047b5`
- Status: IMPLEMENTED
- Commit / branch: not committed; pre-existing user changes preserved

## Outcome

Five architecture slices landed in sequence:

1. `scripts/lib/managed-surfaces.sh` now owns managed-link and pruning policy. Deploy and check/fix select explicit modes; the installer delegates convergence while preserving installer-specific settings behavior.
2. `workflow/runtime/workflow-router-core.mjs` owns route and guard policy. The Claude path is a two-line compatibility adapter, and Pi imports the canonical runtime.
3. `scripts/lib/usage-accounting.mjs` owns token aliases, validation, arithmetic, and assistant-message aggregation. Pi keeps its base-token projection; Claude and benchmark evidence keep cache-aware totals.
4. Benchmark parsing, dispatch, paid-stage orchestration, and rendering moved from shell heredocs to JavaScript CLI modules. Budget registration still precedes spawn, the process cap remains 128, and the inventory remains 115.
5. `scripts/typesafe-architecture-review` uses four `Noul` judgments, one `Choice`, and four `Score` judgments as its decision engine. Typed answers determine pass/revise/block, quality floors, the quality index, and the exit status.

TypeSafe remains read-only and cannot authorize filesystem changes, spending, or READY transitions. Offline fixtures validate composition and failure behavior. No API key or paid call was authorized, so the semantic review of this plan is recorded as `not_run`, not as a model pass.

## Review fixes

- Kept the TypeSafe timeout active through response-body consumption.
- Preserved installer-mode Pi settings migration and wrong-symlink replacement.
- Centralized cross-surface, catalog, vendor, and stale-link pruning.
- Restored detailed benchmark probe output.
- Made the TypeSafe smoke independent of root `PLAN.md`.
- Validated TypeSafe usage, probability sums, Choice argmax, Score legends, weighted scores, confidence boundaries, and quality floors.
- Removed obsolete installer convergence helpers and updated ownership assertions.

## Validation evidence

- `scripts/verify-agentic-infra full` — 84/84 checks passed.
- Pi test suite — 273/273 passed; TypeScript typecheck and dependency audit passed.
- Router evaluation — 212/212, alignment 1, zero write-route false positives, ops-stop misses, or research-route misses.
- Focused TypeSafe, benchmark, usage, deploy, install, fix-links, vendor-policy, guard, and action-graph suites passed.
- Thermonuclear maintainability review — no remaining structural blocker. The 1,597-line router was moved without net implementation growth; the former owner became a two-line adapter.
- Direct defect review — no remaining actionable finding.
- Fresh Logic/Spec review — accepted findings fixed and retested.
- Cross-model code-diff adversary — GO after its three findings were fixed.
- `no-ai-slop` scan — no banned filler patterns in the new durable prose.

## Preserved worktree state

The pre-existing README/docs/settings edits, `scripts/dev-spawn` deletion, and `docs/plan/20260920-docs-dead-reference-audit.md` remain outside this implementation's claims. Their captured baseline patch is `.workflow/architecture-deepening/preexisting.patch` with SHA-256 `9c55fcd0a00248625a84258475ccad32f097ff211bb8fa391eea1f31d491df19`.

## Follow-up

Calibrate TypeSafe thresholds on a labeled plan corpus and run a live semantic review only when credentials and paid execution are explicitly authorized.
