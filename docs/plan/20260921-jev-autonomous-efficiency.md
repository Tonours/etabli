# Implemented: Jev-first autonomous efficiency campaign

## Metadata
- Archived: 2026-09-21
- Source plan: `PLAN.md` — Complete the Jev maturity path, automate evidence-driven self-improvement, and minimize traditional-LLM runtime tokens without weakening Etabli gates.
- Source plan SHA-256: `e4a07f1da3af567cc99e2e8fc2ae1dc75055be1b96b8b86408ecb6e609148207`
- Status: IMPLEMENTED
- Commit / branch: uncommitted working tree; no commit or push authorized
- Workflow initiative: `jev-autonomous-efficiency-resumed` (the original `jev-autonomous-efficiency` ledger remains immutably terminal-blocked at its superseded authorization checkpoint)

## Outcome
- Froze a seven-category, three-repetition benchmark and strict comparator with protected-route preservation and provider-reported token accounting.
- Accepted `jev-route-capsule-v2` at 889,124 traditional-LLM tokens versus 1,472,609 baseline: 39.623% aggregate savings and 45.050%, 34.080%, 39.945% per repetition.
- Preserved the stable pass vector and 3/3 protected passes; the 30% target was met in every repetition and the 50% stretch was not met.
- Promoted Jev into the installed Pi runtime for the evaluated planning, implementation, and review routes with one call maximum, zero retries, deterministic fallback, protected bypass, and policy rollback.
- Kept the self-improvement controller read-only and evidence-gated; Jev is the semantic producer, while deterministic code retains permission, READY, mutation, comparison, promotion, and rollback authority.

## Context
- The installed `/Users/tonours/.pi/agent/extensions` path is a managed link to this checkout, so the promoted extension is the installed runtime source.
- Private prompts, traces, provider receipts, and comparison artifacts remain ignored under `.workflow/jev-autonomous-efficiency/private/`.
- The accepted candidate artifact is `04656055...3fa8`; the accepted comparison receipt is `12aeeb07...f25`.

## Decisions
### Make promotion fail closed and recalculable
- Context: declarative fingerprints did not prove that installed bytes matched evaluated evidence.
- Choice: bind the policy to a separately hashed public promotion manifest that verifies the accepted comparison facts and eleven active or transitive source hashes at every load.
- Rejected options: trusting constants, requiring the ignored private receipt at runtime, or enabling the candidate without drift detection.
- Rationale: a clean checkout can verify the promoted aggregate and installed source graph without exposing private campaign data.
- Consequences: any manifest or source drift falls back to the deterministic route contract until the promotion manifest is deliberately refreshed and reviewed.

### Keep deterministic routing authoritative
- Context: Jev may disagree with the code-owned route or become unavailable.
- Choice: map each enforced deterministic route to one evaluated capsule category and inject only an exact match; record one `route_mismatch` event and fall back otherwise.
- Rejected options: letting Jev choose permissions or accepting contradictory capsules.
- Rationale: Jev becomes first-class for semantic compression without gaining safety authority.
- Consequences: protected routes, plain answers, and non-evaluated `plan-implement` requests bypass Jev.

### Share route context between installed handlers
- Context: a second handler initially diverged on prompt-derived DRAFT/CHALLENGED status.
- Choice: extract one shared route-context resolver used by both extensions.
- Rejected options: duplicated prompt/status logic.
- Rationale: the promoted semantic layer must see exactly the deterministic route that the canonical router sees.
- Consequences: direct edits, plan status, knowledge context, and route eligibility stay in parity.

## Accepted Drift
- Original plan/spec: stretch toward 50% savings.
- Implemented reality: 39.623% aggregate savings, with every repetition above the required 30% target.
- Why accepted: quality and safety gates were preserved; the stretch goal was explicitly non-binding and is reported as unmet.
- Original plan/spec: promote eligible structured seams broadly.
- Implemented reality: only the evaluated planning, implementation, and review route set is enforced; `plan-implement` remains bypassed.
- Why accepted: promotion scope cannot exceed the measured population without fresh evidence.

## Validation Evidence
- `bun test pi/extensions/__tests__/jev-route-capsule-runtime.test.ts pi/extensions/__tests__/workflow-router-extension.test.ts pi/extensions/__tests__/installed-extension-loader.test.ts`
  - 37/37 passed, including source/manifest/receipt tampering, route mismatch, route coverage, shared plan context, rollback, and real Pi loader.
- `bun test pi/extensions/__tests__/`
  - 318/318 passed.
- `scripts/verify-agentic-infra core`
  - 22/22 passed.
- `bash tests/jev-shadow-smoke.sh`
  - passed.
- `bash tests/pi-typecheck-smoke.sh`
  - passed.
- live `jev-1.13.0` post-hardening canary
  - accepted `planning`; 1 call; 0 retries; 735 ms; 434 input and 49 output tokens; deterministic contract and capsule both present.
- final Logic review
  - GO, no findings.
- final Spec review
  - GO, no findings.

## Follow-up State
- Remaining risks: Jev cost telemetry remains unavailable; the adaptive benchmark is not sealed external generalization evidence; `plan-implement` needs a new paired campaign before promotion.
- Parking lot: evaluate additional route categories on a frozen population before widening `eligible_routes`.
- Superseded docs/specs: none; `workflow/self-improvement/jev-efficiency-final-report.md` is the aggregate result.
- Next links: `workflow/runtime/jev-route-capsule-policy.json`, `workflow/runtime/jev-route-capsule-promotion.json`, `workflow/self-improvement/jev-efficiency-final-report.md`.
