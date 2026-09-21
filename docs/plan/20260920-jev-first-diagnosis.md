# Implemented: Jev-first self-improvement diagnosis

## Metadata
- Archived: 2026-09-20
- Source plan: `PLAN.md` — Make Jev the primary semantic diagnostician for trace-driven Etabli self-improvement.
- Source plan SHA-256: `ea9fd4f7ceb292dfb954796422584fcc520250165413714f70938ac902e92064`
- Status: IMPLEMENTED
- Commit / branch: uncommitted worktree on `main` at `3cc4b08`
- Workflow initiative: `jev-first-diagnosis`

## Outcome
- Added the thirteenth semantic profile, `self-improvement-diagnosis`, with exclusive `diagnostic` authority and a pinned contract fingerprint.
- Jev is the required producer of `pattern`, `target`, and `actionability`; deterministic code owns source eligibility, sanitization, abstention, permissions, persistence, mutation, promotion, and rollback.
- Added offline request preparation and explicit-live diagnosis commands. The generic CLI and library evaluators reject diagnostic profiles, so callers cannot bypass the dedicated observation validator and reducer.
- Preserved the historical `self-improvement-candidate` profile and level-1 extractor output. General level-2 activation remains blocked pending real-format canaries and calibration.

## Context
- `scripts/lib/harness-trace-retrospect.mjs`: the historical level-1 tuple is deterministic compatibility output, not the Jev diagnosis.
- `workflow/runtime/semantic-profile-policy.json`: the catalog now has thirteen profiles while the original twelve retain their policy/calibration identity.
- `pi/extensions/lib/self-improvement-diagnosis.mjs`: canonical level-1 identity and per-adapter signal nullability are checked before sanitized projection.
- `pi/extensions/lib/semantic-profiles.mjs`: the diagnostic evaluator uses one immutable policy snapshot and persists the final abstention outcome, including incoherent tuples.

## Decisions
### Separate semantic authority from operational authority
- Context: the previous shadow profile classified a tuple already chosen by deterministic code.
- Choice: create an additive diagnostic profile whose semantic output cannot exist without an accepted Jev judgment.
- Rejected options: relabel the historical profile; retain a deterministic semantic fallback; let Jev mutate workflow assets.
- Rationale: make Jev first-class without weakening permission, privacy, review, or rollback boundaries.
- Consequences: Jev is indispensable inside this bounded plane, but `candidate` still means reviewed follow-up only.

### Keep activation evidence-gated
- Context: the new profile has no real-format corpus or held-out quality evidence.
- Choice: mark it `pending_corpus`, exclude it from the historical calibration selector, and keep general level 2 unavailable.
- Rejected options: reuse the `self-improvement-candidate` report or synthesize a promotion claim.
- Rationale: integration tests prove contract behavior, not model quality.
- Consequences: the next authorized work is canary and calibration evidence, not automatic proposal or mutation.

## Accepted Drift
- Original plan/spec: the diagnosis adapter could have wrapped the shared generic evaluator directly.
- Implemented reality: the shared module owns the dedicated atomic evaluation path; the pure adapter only validates/projects/reduces.
- Why accepted: cumulative review proved that a generic library path and pre-reducer receipt persistence could bypass the authority and abstention contract.

## Validation Evidence
- `bun test pi/extensions/__tests__/semantic-profiles.test.ts pi/extensions/__tests__/semantic-profile-calibration.test.ts`:
  - 30 passed, 0 failed, 189 assertions.
- `tests/jev-judge-smoke.sh`, `tests/harness-trace-retrospect-smoke.sh`, `tests/workflow-docs-smoke.sh`:
  - all passed.
- `scripts/workflow-context-budget` and `git diff --check`:
  - all seven context surfaces within ceilings; diff check passed.
- `scripts/verify-agentic-infra core`:
  - 22/22 checks passed; 305 Pi tests with 952 assertions; router evaluation 212/212; typecheck, audit, skill lock, smokes, and contract checks passed.
- Cumulative isolated review of patch `f1d7702d3354a980791fdf4d8c03941a715c9cc7e396fa46f01aa72f244e25bf`:
  - Logic Hunter: no findings.
  - Spec Hunter: no findings.
  - Cross-model adversary: `xai/grok-4.3`, attested provider/model, verdict `GO`, no actionable findings.
- Provider behavior:
  - no live Jev diagnosis, private trace egress, or paid calibration was performed; tests used injected fake providers.

## Follow-up State
- Remaining risks: model quality and abstention rates are unmeasured on real-format observations; historical calibration report verification is stale at `skill-suggestion` after later catalog changes.
- Parking lot: native run/session binding; private real-format canaries; a versioned held-in/held-out diagnosis corpus; recurrent multi-initiative aggregation; reviewed proposal generation; external promotion controller with atomic rollback.
- Superseded docs/specs: none; level-1 compatibility remains intentional.
- Next links: `workflow/trace-self-improvement.md`, `workflow/semantic-profiles.md`, `workflow/runtime/jev-profile-calibration/README.md`.
