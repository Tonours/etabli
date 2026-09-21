# Implemented: bounded Jev-first self-improvement with safe plan-implement rollback

## Metadata
- Archived: 2026-09-21
- Source plan: `PLAN.md` — measure plan-implement and automate Jev-first self-improvement
- Source plan SHA-256: `b258de78b958541f1776056f0a5f5fb02d23e84a3a60ca1acfc4639effb0032e`
- Status: IMPLEMENTED
- Commit / branch: pending final main commit
- Workflow initiative: `jev-self-improvement-v1`

## Outcome
- Added a frozen three-scenario, three-repetition-per-arm campaign for the `plan-implement` Jev capsule with exact tracked-worktree and terminal-ledger grading, separate traditional-LLM/Jev telemetry, zero retries, and evaluator/manifest fingerprints.
- Added `scripts/jev-self-improvement --live`: one explicitly selected, natively correlated Pi trace is projected to bounded counters/enums, judged once by Jev, deduplicated, and terminated as `no_op`, `investigate`, or a non-executable `candidate` packet.
- Kept `propose_reviewed` disabled. Three distinct live diagnoses all abstained as uncertain, using three Jev calls and zero traditional-LLM calls.
- Rejected the `plan-implement` efficiency candidate as non-comparable. The baseline passed all nine cells with 1,560,444, 1,526,973, and 1,642,388 traditional-LLM tokens. The first candidate cell failed because the experimental runner injected the capsule before deterministic routing; no savings percentage is claimed.
- Removed only `plan-implement` from Jev `eligible_routes`; deterministic routing remains active and previously measured routes remain eligible.
- Reported rather than hid the development budget overrun: 35 traditional-LLM executions were observed or started across pilots, interrupted campaigns, canaries, and the terminal run.

## Context
- `workflow/self-improvement/jev-plan-implement-result.json`: sanitized aggregate evidence and explicit non-comparable verdict.
- `workflow/self-improvement/jev-plan-implement-report.md`: human-readable measured totals, abstentions, rollback, and cost uncertainty.
- `.workflow/jev-plan-implement/private/`: ignored raw provider evidence; never published.
- `.workflow/jev-self-improvement/private/`: ignored live diagnosis packets; never published.

## Decisions
### Preserve honest non-comparability
- Context: the frozen baseline used an evaluator whose candidate injection order was later found invalid.
- Choice: reject the candidate, correct the future evaluator, and do not compare it with the old baseline.
- Rejected options: reuse the old baseline with changed evaluator bytes; inherit the earlier general 39.623% result; report the failed cell as savings.
- Rationale: paired evidence is valid only with identical manifest, evaluator, runtime, and population bindings.
- Consequences: `plan-implement` currently receives deterministic fallback rather than a Jev capsule.

### Bound autonomy below source mutation
- Context: Jev can reduce a sanitized observation to a typed semantic diagnosis, but it must not become a permission or mutation oracle.
- Choice: make `diagnose_shadow` explicit-live and autonomous through terminal packet creation; require a current fingerprint-bound capability receipt before any non-executable proposal packet.
- Rejected options: automatic source edits, PLAN promotion, commit, push, deployment, or a deterministic invented diagnosis after Jev abstention.
- Rationale: Jev is first-class for semantic interpretation while deterministic code owns evidence, permissions, READY, mutation, promotion, and rollback.
- Consequences: all three live abstentions ended safely at `investigate`; no proposal capability was fabricated.

### Reject symlink parents before writes
- Context: the first private-output validators could create child directories through a symlinked `.workflow` parent before rejecting the resolved path.
- Choice: validate every directory component as a real directory inside the canonical root before creating the next component.
- Rejected options: validate only the final private directory after recursive creation.
- Rationale: fail-closed output handling must not mutate a location outside the selected repository.
- Consequences: campaign and controller tests now prove no outside directory is created through a symlinked parent.

## Accepted Drift
- Original plan/spec: complete an 18-call paired baseline/candidate campaign and enable `propose_reviewed` only after three successful live checks.
- Implemented reality: the baseline completed, but the candidate stopped on its first failed non-comparable cell; all three live diagnoses abstained, so proposal capability remains disabled.
- Why accepted: the plan’s explicit stop condition allowed a rejected result with rollback and prohibited unsupported efficiency or promotion claims.

## Validation Evidence
- `node --test tests/jev-plan-implement-campaign.test.mjs tests/jev-self-improvement-controller.test.mjs`:
  - result: 13/13 passed after the final symlink-parent correction.
- `bun test pi/extensions/__tests__/jev-route-capsule-runtime.test.ts`:
  - result: 13/13 passed; policy hash binding and deterministic fallback verified.
- `tests/harness-trace-retrospect-smoke.sh` and `tests/agentic-infra-manifest-smoke.sh`:
  - result: both passed.
- `scripts/verify-agentic-infra all`:
  - result: 88/90 groups passed. `pi-tests` had 319/320 tests pass, with the installed-loader test exceeding its 5-second limit by 86 ms under full-suite load; it passed alone in 1.50 seconds. `herdr-setup-smoke` failed under broken Homebrew Python 3.14 `pyexpat` and passed with system Python using `PATH=/usr/bin:/opt/homebrew/bin:/bin:/usr/sbin:/sbin`.
- Cross-model review/adversary:
  - result: xAI `grok-4.6` rejected the alleged raw-observation leak after verifying `evaluateSelfImprovementDiagnosis` projects through `prepareSelfImprovementDiagnosisState` before provider egress; final verdict `GO WITH NOTES`.
- `git diff --check`:
  - result: passed.

## Follow-up State
- Remaining risks: route-specific traditional-LLM savings remain unmeasured; the three-task adaptive population is not sealed external-generalization evidence; proposal autonomy remains intentionally disabled.
- Parking lot: rerun a fresh baseline and candidate from the corrected evaluator only under a new explicit campaign budget; improve full-suite timing isolation for the installed Pi loader; repair Homebrew Python/expat outside this repository.
- Superseded docs/specs: none.
- Next links: `workflow/self-improvement/jev-plan-implement-result.json`, `workflow/skills/self-improvement-loop.md`, `workflow/trace-self-improvement.md`.
