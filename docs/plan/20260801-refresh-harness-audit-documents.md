# Implemented: Refresh harness robustness and self-improvement audit documents

## Metadata

- Archived: 2026-08-01
- Source plan: `PLAN.md` — Refresh harness robustness and self-improvement audit documents
- Status: IMPLEMENTED
- Commit / branch: not committed; five audit documents remain untracked

## Outcome

Updated the five requested audit artifacts with a source-backed adversarial review, corrected top-five prioritization, explicit evidence labels, and additional improvement backlog. No runtime, workflow, hook, script, test, CI, or capability file changed.

## Context

- `claude/hooks/workflow-router-lib.mjs`: Bash mutation detection is a finite heuristic; controlled guard-only calls allowed `node -e`, `python3 -c`, `git apply`, and `install` under DRAFT/no_progress.
- `scripts/lib/no-progress-guard.mjs`: malformed lines are skipped and any terminal event closes a ledger for the mutation guard; controlled malformed and early-terminal cases allowed mutations.
- `scripts/workflow-event` / `scripts/lib/workflow-event-detail.jq`: a synthetic 12-event autonomous ledger validates without links to real diff, command output, archive, or independent reviewer.
- `workflow/vnext/tasks.json`: 13 held-out entries marked sealed are tracked and readable; frozen corpus is not isolated evaluation.

## Decisions

### Re-rank the roadmap around authority and evidence integrity

- Context: The former top five began at multi-exec and terminal quality, while direct mutation and ledger fail-open paths could bypass them.
- Choice: Put fail-closed mutation authority, ledger integrity, observed completion receipts, and evaluation integrity at P0.
- Rejected options: Preserve the old rank or treat `measured:true` as a universal completion gate.
- Rationale: A self-improvement loop cannot safely optimize evidence whose mutation, chronology, or evaluator can be self-attested.
- Consequences: Delegation, telemetry, mining, skill evaluation, canary, and calibration remain in P1/P2 until the P0 truth boundary is addressed.

### Preserve honest telemetry and evaluation labels

- Context: Deterministic/offline success can legitimately have `outcome_metric.measured:false`; public held-out fixtures were described as sealed.
- Choice: Separate semantic grade/receipt from token telemetry, and name the current corpus frozen-public-held-out until an isolated evaluator exists.
- Rejected options: Block every unmeasured terminal or describe versioned fixtures as confidentially sealed.
- Rationale: Both rejected options would overclaim safety or invalidate honest evidence.
- Consequences: Future implementation must add provenance/evaluator isolation rather than changing wording alone.

### Keep this change documentation-only

- Context: The user requested updates to the five analysis documents after the adversarial review.
- Choice: Do not change the harness in this plan; create a follow-on `plan-implement` task for implementation.
- Rejected options: Auto-apply the recommendations or deploy an external evaluator/OS sandbox without a separate authorization and architecture plan.
- Rationale: The self-improvement contract requires READY-gated, evidence-backed, narrow changes.
- Consequences: Known P0 gaps remain open until the follow-on implementation work completes.

## Accepted Drift

- Original plan/spec: Update five existing audit documents after review.
- Implemented reality: The five documents were already untracked, so no Git before/after diff was available; review compared the current documents against the READY plan and current source evidence.
- Why accepted: The limitation is documented in every relevant artifact and does not weaken the scope or validation claims.

## Validation Evidence

- `scripts/verify-agentic-infra core`
  - result: exit 0 before documentation edits; baseline only.
- `scripts/answer-quality-check --mode repo <each of the five audit documents>`
  - result: all five passed after edits.
- Markdown whitespace check over the five documents, including `git diff --no-index --check /dev/null <file>`
  - result: passed.
- Required audit marker check (`fail-closed`, `frozen-public-held-out`, adversarial claim check, trust boundaries)
  - result: passed after correcting the check's initial regex, not the documents.
- Post-change documentation review
  - result: GO WITH NOTES; no blocking finding, with untracked/local-only validation explicitly disclosed.

## Follow-up State

- Remaining risks: P0 mutation, ledger, completion-provenance, and evaluator-isolation gaps are documented but not fixed.
- Parking lot: external isolated evaluator, OS sandbox, live multi-model rerun, canary rollout, and human calibration require a separate scoped plan and/or external capability.
- Superseded docs/specs: the five `docs/harness-*-20260801.md` documents now supersede their earlier v1 content in the working tree.
- Next links:
  - `docs/harness-top5-consolide-20260801.md`
  - `docs/harness-robustness-top5-20260801.md`
  - `docs/harness-self-improvement-analysis-20260801.md`
  - `docs/harness-surface-map-20260801.md`
  - `docs/harness-robustness-top5-claim-check-20260801.md`
  - Task #12: plan and implement the identified harness improvements.
