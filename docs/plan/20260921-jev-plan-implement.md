# Implemented: Activate Jev for plan-implement

## Metadata
- Archived: 2026-09-21
- Source plan: `PLAN.md` — Make Jev an active first-class semantic producer for the frequently used `plan-implement` workflow.
- Source plan SHA-256: `ff1506ede436dfc4d9ee044c0f61df6b3ede3e466d84b0a002e287bacdaaa9ce`
- Status: IMPLEMENTED
- Commit / branch: uncommitted working tree on `main`
- Workflow initiative: `jev-plan-implement`

## Outcome
- `plan-implement` is active in the enforced installed-runtime policy and maps only to the dedicated Jev `plan_implementation` category.
- The compiled capsule covers planning, READY gating, implementation, validation, review, archive, and cleanup while deterministic code retains every permission and mutation decision.
- Three public synthetic live canaries passed with three calls, zero retries, confidence 0.99–1.00, 1,264 ms aggregate latency, and 1,721 Jev tokens.
- Traditional-LLM savings for `plan-implement` remain explicitly `not_measured`; the earlier 39.623% result belongs only to the inherited v2 population.

## Context
- `pi/extensions/lib/jev-route-capsule.mjs`: owns the five-option TypeSafe Choice, compiled capsules, zero-retry transport, and authoritative capsule fingerprints.
- `pi/extensions/jev-route-capsule-runtime.ts`: preserves deterministic routing and validates the policy, manifest, fixture, receipt, confidence extrema, and capsule fingerprint before injection.
- `workflow/runtime/jev-plan-implement-activation.json`: public aggregate activation receipt; it contains synthetic prompt hashes and aggregates, not credentials or raw provider payloads.

## Decisions
### Keep deterministic authority outside Jev
- Context: `plan-implement` combines planning and mutation phases.
- Choice: accept Jev guidance only when the deterministic route and dedicated semantic category agree.
- Rejected options: generic planning/implementation categories; Jev-owned READY or mutation authority.
- Rationale: semantic compression must not weaken the workflow gates.
- Consequences: mismatch, abstention, provider error, rollback, or evidence drift inject no capsule.

### Separate activation from inherited efficiency evidence
- Context: the accepted v2 token comparison did not include `plan-implement`.
- Choice: retain v2 as base efficiency evidence and require a separate v3 activation receipt.
- Rejected options: attributing 39.623% savings to the new route or rerunning the full traditional-LLM campaign.
- Rationale: activation and token savings are different claims.
- Consequences: this change proves correct activation, not new traditional-LLM savings.

## Accepted Drift
- Original plan/spec: activation receipt validation relied on syntactically valid case fields and a duplicated expected capsule fingerprint.
- Implemented reality: final review added exact fixture prompt/route binding, derived confidence extrema, an authoritative exported capsule fingerprint, and an end-to-end natural composite route test.
- Why accepted: Logic and Spec reviews found these evidence-integrity gaps; the fixes strengthen the planned fail-closed contract without adding provider calls.

## Validation Evidence
- `bun test pi/extensions/__tests__/jev-route-capsule-runtime.test.ts pi/extensions/__tests__/workflow-router-extension.test.ts pi/extensions/__tests__/installed-extension-loader.test.ts`: 39/39 passed.
- `bun test tests/jev-efficiency-candidate.test.mjs`: 11/11 passed.
- `bash tests/pi-typecheck-smoke.sh`: passed.
- `bun test pi/extensions/__tests__/`: 320/320 passed.
- `bash tests/jev-shadow-smoke.sh`: passed.
- `scripts/router-eval --min-accuracy 1 --require-alignment`: 212/212, accuracy and alignment 1.0.
- `scripts/verify-agentic-infra core`: 22/22 passed.
- `scripts/workflow-context-budget --json`: every surface within its ceiling.
- `git diff --check`: passed.
- Final pinned Logic review: GO; final pinned Spec review: GO.
- Final code adversary: direct `xai/grok-4.6`, GO WITH NOTES; no blocking or actionable finding remained.

## Follow-up State
- Remaining risks: token savings for `plan-implement` are unmeasured; provider availability still falls back deterministically.
- Parking lot: correct the stale “those three routes” wording only in a future measured candidate, because changing the frozen decision prompt here would invalidate canary provenance.
- Superseded docs/specs: none.
- Next links: `workflow/self-improvement/jev-efficiency-final-report.md`, `workflow/runtime/jev-plan-implement-activation.json`.
