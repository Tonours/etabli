# Implemented: pre-lane-3 Etabli contract distill and router verb collisions

## Metadata
- Archived: 2026-08-21
- Source plan: `PLAN.md` — Distill always-on Etabli contracts and fix router verb collisions
- Source plan SHA-256: `bb2b02b61308a2d133be1984fb25bed1667e3dd4eee118f45c83196e7a6fd880`
- Status: IMPLEMENTED
- Commit / branch: `refactor/skill-default-load` (uncommitted at archive)

## Outcome
Always-on contracts now name when not to write `PLAN.md`, what the last message must contain, and how to stop a long loop before an external cap. The classifier no longer steals the 23 organic  prompts into `verify-workflow` / `research-plan` / `pr-review`. Zero new skills or route names. Lane 3 was not launched. Official lane 2 stays `not_established`.

## Context
- Lane 2 official: 2 AHEAD / 12 TIE / 1 BEHIND / 8 INCONCLUSIVE
- PLAN ceremony was not the 14/23 wall cause (ADR-0014; hillclimb/authoring transcripts had no `PLAN.md`)
- Held-in misses: English `verify` before implement; `\bfix\b` in “Don't fix”; `\bweb\b` in “web UI”; “prepare it for review” + PR

## Decisions
### Distill, do not copy  playbooks
- Context:  wins on reply shapes and hillclimb stop, not on a larger skill surface
- Choice: three contract owners + smallest classifier tighten
- Rejected options: new skills, -mode copy, 40 min hillclimb cap, reseal graders
- Rationale: self-improvement must stay READY-gated and evaluator-honest
- Consequences: quick card stayed 120 lines; catalog unchanged

### Classifier: work-embedded verify, implement negation, drop bare `web`
- Context: `VERIFY_PATTERN` fired before `IMPLEMENT_PATTERN`
- Choice: `isStandaloneVerifyRequest`; `IMPLEMENT_NEGATION_PATTERN`; remove `\bweb\b` from `RESEARCH_PATTERN`; skip review/pr-review on `PREPARE_FOR_REVIEW_PATTERN`
- Rejected options: new route names; leave organic fixtures documentation-only
- Rationale: held-out `Retest et prouve`, `recherche web sourcée`, and `code review de la PR GitHub 42` stayed green
- Consequences: 23 organic fixtures locked in `tests/router-evals/core.json`

## Accepted Drift
- Original plan/spec: some work prompts (session-pickup, shipping, orchestrate, visual-parity) now classify as `answer` rather than `plan-implement`
- Implemented reality: plan allowed `plan-implement` or `answer` for work prompts after the collision fix
- Why accepted: the acceptance criterion was “not stolen by verify/research/pr-review”, not “every work prompt becomes plan-implement”

## Validation Evidence
- command: `bash tests/workflow-docs-smoke.sh`
  - result: ok
- command: `bun test pi/extensions/__tests__/workflow-router-fixtures.test.ts`
  - result: 56 pass
- command: `bun test pi/extensions/__tests__/workflow-router-alignment.test.ts`
  - result: 58 pass
- command: `bun test pi/extensions/__tests__/workflow-router-runtime.test.ts`
  - result: 21 pass
- command: `scripts/answer-quality-eval`
  - result: 10/10
- command: `git diff --check` on named files
  - result: clean
- simplify: removed 1
- quality: project-router | mechanical fixed: 0 | findings: 0 | status: clean
- reviewer_model: Cursor Grok 4.6 (same session; deciding-code table complete for classifier)
- adversary_model: plan-mode already folded; code-diff cross-model not run (no second family in this turn)

## Follow-up State
- Remaining risks: WORK_EMBEDDED_VERIFY can skip a standalone “verify the merge”; reply-shape sentences are unmeasured until a later lane; code-diff adversary was not cross-model
- Parking lot: C11 rubric calibration + axes-cache (satellite, needs authorization)
- Superseded docs/specs: the 2026-08-20 “23/23 AHEAD” execution plan this file replaced
- Next links: lane 3 only after explicit user authorization of budget/model/thinking
