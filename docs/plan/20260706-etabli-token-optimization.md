# Implemented: Etabli workflow token budget reduction

## Metadata
- Archived: 2026-07-06
- Source plan: Etabli workflow token reduction
- Status: IMPLEMENTED
- Commit / branch: `main` at `db5fc9d` with uncommitted working-tree changes

## Outcome
- Added an instruction-budget section to `scripts/workflow-efficiency-report`.
- Reduced the measured autoload/scaffold instruction budget from `9455` to
  `1891` estimated tokens, ratio `0.2`.
- Met both the hard target (`<=25%`) and the stretch target (`<=20%`).
- Compressed the live Codex, Pi, and Claude entrypoints into thin source maps.
- Compressed scaffold agent docs while preserving source-of-truth links.
- Added smoke coverage to prevent budget drift.
- Updated the workflow contract so explicit active-run authorization can launch
  one read-only fresh-context reviewer instead of blocking again.

## Context
- Baseline source set:
  `codex/AGENTS.md`, `pi/AGENTS.md`, `claude/CLAUDE.md`,
  `workflow-scaffold/templates/AGENTS.md`,
  `workflow-scaffold/templates/CLAUDE.md`,
  `workflow-scaffold/templates/docs/agent-workflow.md`, and
  `workflow-scaffold/templates/docs/claude-code-workflow.md`.
- Baseline estimate: `ceil(chars / 4)`.
- Historical token evidence from local Codex state was treated as baseline
  context only; success is proven by source-level budget and smoke checks.
- Existing dirty single-PR maintenance loop changes were preserved.

## Decisions
### Source-level budget gate
- Context: `.workflow/*/events.jsonl` had no reliable `outcome_metric` baseline
  for historical workflow-token success.
- Choice: enforce a deterministic source-level instruction budget in
  `scripts/workflow-efficiency-report`.
- Rejected options: encode historical local-state totals as `outcome_metric`;
  block on an exact tokenizer.
- Rationale: the checked-in source files are reproducible and can be smoke
  pinned.
- Consequences: future drift fails the smoke test when the budget or file set
  exceeds the intended target.

### Thin entrypoints
- Context: live and scaffolded agent entrypoints duplicated workflow rules.
- Choice: keep entrypoints as compact maps to shared contracts.
- Rejected options: move all behavior into every harness-specific adapter.
- Rationale: adapters should load quickly and point to the source of truth.
- Consequences: detailed behavior stays in `workflow/spec.md` and
  `workflow/skills/*`; entrypoints remain small.

### Read-only reviewer authorization
- Context: the workflow required a fresh-context review, but the active tool
  contract needed explicit subagent authorization.
- Choice: encode that explicit active-run authorization for subagents,
  delegation, reviewers, or "all" permits exactly one read-only reviewer when a
  runner is available.
- Rejected options: weaken destructive checkpoints, skip fresh review, or
  self-review the final diff.
- Rationale: read-only review is a quality gate, not an irreversible action.
- Consequences: destructive, secret, production, billing, deploy, push, merge,
  and external-write gates remain unchanged.

## Accepted Drift
- Original plan/spec: optimize token budget and archive after validation.
- Implemented reality: also updated `workflow/spec.md` and
  `workflow/skills/implementation-loop.md` to prevent repeat blocking on
  read-only fresh-context reviewer authorization.
- Why accepted: the user explicitly requested the workflow change after the
  blocker repeated, and the change is smoke-pinned without weakening risky
  action gates.

## Review Evidence
- Plan adversary:
  - result: `GO`
  - accepted: do not encode historical baseline as `outcome_metric`; define
    source-level budget target before claiming reduction.
  - rejected: block implementation until an exact tokenizer is available.
- Fresh-context diff reviewer:
  - agent: `019f3946-97c8-7213-8e00-8ecf03013df3`
  - result: `GO WITH NOTES`
  - accepted note: assert the exact seven-file instruction budget set in
    `tests/workflow-efficiency-report-smoke.sh`.

## Validation Evidence
- `scripts/workflow-efficiency-report --json`:
  - result: passed; `current_tokens=1891`, `baseline_tokens=9455`,
    `current_ratio=0.2`.
- `bash tests/workflow-efficiency-report-smoke.sh`:
  - result: passed; asserts target, stretch target, and exact budget file set.
- `bash tests/workflow-docs-smoke.sh`:
  - result: passed.
- `bash tests/workflow-scaffold-smoke.sh`:
  - result: passed.
- `bash tests/workflow-contract-coverage-smoke.sh`:
  - result: passed.
- `bash tests/workflow-monitor-smoke.sh`:
  - result: passed.
- `bash tests/workflow-dossier-smoke.sh`:
  - result: passed.
- `bash tests/workflow-retrospect-smoke.sh`:
  - result: passed.
- `bash tests/codex-organization-smoke.sh`:
  - result: passed.
- `bun test pi/extensions/__tests__/`:
  - result: passed; 186 tests.
- `node --check claude/hooks/*.mjs`:
  - result: passed.
- `bash tests/pr-latest-head-status-smoke.sh`:
  - result: passed; validates preserved single-PR maintenance changes.
- `scripts/workflow-event validate etabli-token-optimization`:
  - result: passed; 25 events before archive completion.
- `git diff --check`:
  - result: passed.

## Follow-up State
- Remaining risks: token counts use `ceil(chars / 4)`, not an exact model
  tokenizer.
- Parking lot: future work can add exact tokenizer support if it is available
  without adding network or model coupling to the smoke path.
- Superseded docs/specs: root `PLAN.md` was superseded by this archive after
  validation.
- Next links:
  - `.workflow/etabli-token-optimization/events.jsonl`
  - `.workflow/etabli-token-optimization/results/P4-completion-audit.md`
