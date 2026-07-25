# Implemented: Recenter the Etabli harness

## Metadata
- Archived: 2026-07-25
- Source plan: Recenter the Etabli harness on high-value workflow controls
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`

## Outcome
- Split validation into a 15-check daily `core`, 39 additional deterministic
  `full` checks, and two explicitly opted-in `live` checks.
- Patched Pi's `brace-expansion` override from 5.0.7 to 5.0.8; `bun audit`
  reports no vulnerabilities.
- Kept architecture-only and ordinary work parent-only while preserving
  escalation for explicit multi-model work, critical risk, material
  uncertainty, repeated failure, and required fresh review.
- Reduced answer-quality enforcement to the durable-artifact checker and its
  versioned fixture eval; retained prior traces only as historical provenance.
- Moved telemetry readers and project autonomy out of the core path and labeled
  them experimental/on-demand.
- Removed tracked lean-ctx helpers, one byte-identical duplicate handoff, and
  obsolete answer-quality audit/trace helpers.
- Reduced README to an entry map and made Codex deployment content-aware by
  default instead of forcing topology-only relinks.
- Final tracked implementation diff before this archive was a net reduction of
  632 lines.

## Context
- `workflow/runtime/agentic-infra-checks.tsv`: validation profiles and legacy CI
  groups share one manifest.
- `workflow/vnext/tasks.json`: frozen unchanged at SHA-256
  `4ae440269c06b17afb2289ecad9713e696d7ba0a55495b74ef31175f59c82526`.
- Pre-change health failed on the high-severity
  `brace-expansion@5.0.7` advisory.
- Historical workflow telemetry had too few task-grader outcomes to support a
  user-value claim.

## Decisions

### Separate deterministic and live proof
- Context: live CLI smokes previously exited successfully when skipped.
- Choice: `live` requires both explicit opt-ins and exits 3 with `SKIP` when
  either is absent.
- Rejected options: treating skipped checks as pass; mixing live checks into
  the deterministic full profile.
- Rationale: validation labels must match the evidence actually produced.
- Consequences: CI compatibility groups remain deterministic and live proof is
  intentionally absent until explicitly authorized.

### Freeze profile and held-out inventories
- Context: moving checks could otherwise silently reduce coverage, and vNext
  computed its hash from the current corpus.
- Choice: pin exact core/full/live inventories, Pi/Nvim compatibility subsets,
  and the vNext task hash in smoke tests.
- Rejected options: count-only assertions and self-derived baselines.
- Rationale: a green result must reject silent coverage shrinkage.
- Consequences: intentional inventory changes require an explicit fixture
  update.

### Remove low-value active layers without deleting history
- Context: answer-quality audit/trace wrappers duplicated checker/eval behavior.
- Choice: delete active wrappers/tests, retain historical trace artifacts with
  clear archival labeling.
- Rejected options: deleting durable evidence or keeping stale commands in the
  canonical contract.
- Rationale: preserve provenance while reducing daily ceremony.
- Consequences: current validation has one checker and one fixture eval.

## Accepted Drift
- Original plan/spec: the first plan draft did not freeze the full profile or
  vNext corpus independently.
- Implemented reality: the plan adversary and code reviewers required exact
  inventories and a fixed task hash before accepting the change.
- Why accepted: these additions prevent false-green completion without adding
  runtime orchestration.

## Validation Evidence
- `scripts/verify-agentic-infra core`
  - result: PASS, including audit, Pi tests, routes, guards, deployment, supply
    chain, and contract coverage.
- `scripts/verify-agentic-infra full`
  - result: PASS for every deterministic manifest check.
- `scripts/vnext-suite --json`
  - result: 35/35, 13 sealed held-out, deterministic host mode, frozen hash.
- `scripts/verify-agentic-infra live` without opt-ins
  - result: `SKIP`, exit 3; no live target reported PASS.
- `scripts/deploy-agent-workflow --dry-run`
  - result: all managed surfaces `OK`; no topology-only Codex relink.
- `scripts/check-fix-symlinks.sh --verbose`
  - result: 0 issues, 0 fixes, 0 unresolved.
- `git diff --check`
  - result: PASS.
- Fresh-context review
  - result: PASS after exact full inventory and historical-doc corrections.
- Code-diff adversary
  - result: GO with no remaining findings.

## Follow-up State
- Remaining risks: live multi-runtime effectiveness was not run because the
  required explicit opt-ins were absent.
- Parking lot: telemetry may support a user-value claim only after at least 10
  representative real tasks have task-grader outcomes.
- Superseded docs/specs: former answer-quality audit/trace commands are
  historical only.
- Next links: `workflow/spec.md`, `workflow/answer-quality.md`,
  `workflow/runtime/agentic-infra-checks.tsv`.
