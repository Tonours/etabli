# Implemented: Workflow Retrospect Loop

## Metadata
- Archived: 2026-07-06
- Source plan: workflow-retrospect self-improvement loop
- Status: IMPLEMENTED
- Commit / branch: `main` at `579e869`; changes are uncommitted

## Outcome
- Added `scripts/workflow-retrospect`, a local read-only helper that mines
  `.workflow/*/events.jsonl` and `docs/plan/*.md`.
- The helper detects and groups recurring workflow issues across the requested
  categories: adversary findings, validation failures, plan drift, router
  misses, dogfood blockers, and runtime-capability overclaims.
- It emits structured text or JSON with `category`, normalized `key`, `count`,
  `confirmed`, `action_kind`, `recommendation`, and scrubbed evidence samples.
- Added `tests/workflow-retrospect-smoke.sh` with a red-team bad-run fixture
  proving confirmed recurring issues become `recommendation`,
  `router_fixture`, `contract_patch`, or `mechanical_check`.
- Updated docs, smoke pins, and CI so the helper is treated as a first-class
  workflow feedback-loop tool.

## Context
- Existing workflow helpers already covered run status, outcome metrics, and
  dossiers, but they did not synthesize repeated failure patterns into
  self-improvement recommendations.
- `workflow/spec.md` already contained the durable principle that a third
  occurrence of the same review finding becomes a mechanical check and a real
  routing failure becomes a fixture.
- The active goal prohibited external write-back, deploy, push, and runtime
  capability overclaims.

## Decisions
### Keep Retrospect Read-Only
- Context: A self-improvement loop could drift into auto-patching workflow
  contracts or router fixtures.
- Choice: `workflow-retrospect` only reports candidate actions.
- Rejected option: auto-create router fixtures or patch workflow contracts.
- Rationale: generated patches need a reviewed `PLAN.md` and validation.
- Consequence: the helper improves diagnosis and backlog quality without
  bypassing READY gates.

### Filter To Requested Issue Categories
- Context: Fresh-context review found that normal repeated `route_decided`
  events could become false recurring issues.
- Choice: emit only the target categories:
  `adversary_finding`, `validation_failure`, `plan_drift`, `router_miss`,
  `dogfood_blocker`, and `runtime_capability_overclaim`.
- Rejected option: keep generic `observed_route` or `observed_blocker`
  recommendations.
- Rationale: the goal is repeated failure mining, not normal telemetry
  summarization.
- Consequence: the red-team fixture includes repeated normal routes and asserts
  they do not become issues.

### Preserve Existing Goal-Prompt-Rewriter Edits
- Context: the worktree already contained user-requested
  `goal-prompt-rewriter` changes and smoke pins.
- Choice: preserve them and avoid reverting user work.
- Rejected option: remove those pins to make this implementation standalone.
- Rationale: the user asked for those edits immediately before this goal; they
  are not plan drift.
- Consequence: `workflow-docs-smoke` validates both the previous skill update
  and the new retrospect contract.

## Accepted Adversary Findings
- Keep `workflow-retrospect` read-only and emit candidate actions instead of
  auto-patching.
- Include a red-team bad-run fixture so recurrence logic is proven.
- Scan implemented plan archives as well as event ledgers.
- Normal `route_decided` events must not become recurring issues.

## Rejected Adversary Findings
- Auto-create router fixtures directly from retrospect output.
- Require external write-back or scheduled publishing.
- Treat missing archive/root cleanup as a blocker before final validation.
- Revert `goal-prompt-rewriter` smoke pins from the previous user request.

## Validation Evidence
- `bash tests/workflow-retrospect-smoke.sh`
  - result: passed
- `bash tests/workflow-docs-smoke.sh`
  - result: passed
- `bash tests/workflow-event-smoke.sh`
  - result: passed
- `bash tests/workflow-contract-coverage-smoke.sh`
  - result: passed
- `bash tests/workflow-monitor-smoke.sh`
  - result: passed
- `bash tests/workflow-metrics-smoke.sh`
  - result: passed
- `bash tests/workflow-dossier-smoke.sh`
  - result: passed
- `bash -n` on shell scripts in `scripts/` and `tests/`
  - result: passed
- `python3 codex/skills/codex-dynamic-workflows/scripts/verify_workflow.py .workflow/workflow-retrospect-loop`
  - result: passed
- `scripts/workflow-retrospect --min-count 2 --json`
  - result: passed; current repo evidence has `observed_issue_count=16` and
    `confirmed_issue_count=0`
- `git diff --check`
  - result: passed

## Accepted Drift
- Original plan/spec: parse event ledgers and archives into structured
  recurring recommendations.
- Implemented reality: completed as planned, with an extra negative test for
  repeated normal routes after fresh-context review.
- Why accepted: the negative test prevents false self-improvement loops.

## Follow-up State
- Remaining risks: grouping is intentionally conservative text normalization;
  future improvements may add richer fingerprints if real false merges appear.
- Parking lot: scheduling the helper or applying recommendations automatically
  remains out of scope.
- Superseded docs/specs: none.
- Next links:
  - `scripts/workflow-retrospect`
  - `tests/workflow-retrospect-smoke.sh`
  - `workflow/spec.md`
  - `workflow/events.md`
  - `.github/workflows/agentic-infra.yml`
