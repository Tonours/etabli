# Implemented: pattern-only Jev self-improvement diagnosis with a deterministic no-friction gate

## Metadata
- Archived: 2026-09-23
- Source plan: `PLAN.md` — make Jev self-improvement diagnosis decisive and cheaper
- Source plan SHA-256: `ce126caac2d776ca893c95c23024e94dde33e07c0045780d678a782e337b015b`
- Status: IMPLEMENTED
- Commit / branch: `main`
- Workflow initiative: `jev-diagnosis-efficiency`

## Outcome
- The `self-improvement-diagnosis` profile now asks Jev a single Choice question, `pattern`, instead of three (`pattern`, `target`, `actionability`).
- `reduceSelfImprovementDiagnosis(result, episode)` derives `target` through a frozen pattern-to-surface map. `actionability` is `no_op` only for `no_material_friction` on a completed episode with `verifier=true`, and `investigate` otherwise. A single episode never yields `candidate`.
- The level-2 controller skips Jev on a completed, `verifier=true` episode whose friction counters (`tool_errors`, `validation_failures`, `review_rework`, `plan_rework`, `compactions`, `retries`) are all 0 or null. It returns `no_op` / `no_friction_signals` with `jev.calls: 0` and `diagnosis: null`. The `jev-judge` diagnostic probes stay ungated.
- Live synthetic probe, same 8 frozen scenarios. The baseline diagnosed 0 of 8. The candidate diagnosed 3 of 4 friction scenarios on both repeats, with zero wrong patterns, and the clean scenario needs no call. Tokens per call dropped from 840/211 to 546/~92 (about −39% total). Latency stayed at 270–1475 ms.

## Context
- The earlier three live controller checks all abstained (`workflow/self-improvement/jev-plan-implement-report.md`). The probe located the cause.
  - `actionability` was uncertain in 7 of 8 scenarios (top probability 0.44–0.68), including a clean run (0.44 `candidate` against 0.40 `no_op`).
  - `pattern` was confident: 0.97–1.00 on the one-friction scenarios.
- `target` criteria map 1:1 to `pattern` criteria, and a separate `target` answer contradicted the pattern once. On held-out `mixed`, it returned `execution_reliability` at 0.73 together with `validation_strategy` at 0.76.
- TypeSafe guidance says to keep policy and known rules in code and ask one narrow semantic judgment. `actionability` is a policy rule, and the loop contract already says a single anecdote is not enough evidence for a candidate.

## Decisions
### Jev owns only the semantic judgment
- Context: the three-question request abstained on every episode.
- Choice: ask only `pattern`, and derive `target` and `actionability` in code.
- Rejected options: enriching the Jev state with derived rates (the counters already support confident patterns); per-friction Noul questions (larger contract change with no evidence it is needed).
- Rationale: the failure was in the question design, not in the data. Deriving the rest from an accepted Jev pattern is not an invented fallback diagnosis.
- Consequences: level 3 (`propose_reviewed`) has no producer until cross-episode recurrence exists. The controller's candidate branch remains, reachable only through fixtures.

### Deterministic no-friction gate before Jev
- Context: clean episodes spent a Jev call to be told there was no friction.
- Choice: an eligibility gate in the controller only. Its reason (`no_friction_signals`) differs from Jev's `jev_no_material_friction`.
- Rejected options: placing the gate in `evaluateSelfImprovementDiagnosis`, which would make the explicit probes lie about what Jev said.
- Rationale: code owns evidence and eligibility. Jev sees the same counters, so the gate discards no information Jev had.
- Consequences: `verifier=true` also holds when no review ran, which is the ceiling of the existing counters, not of the gate.

### Rejected candidate A: rewritten pattern criteria
- Context: Step 1 first sharpened the `pattern` criteria ("relative to activity", "dominant", verification includes blocked).
- Choice: reverted to the original `pattern` text.
- Evidence: review_blocked dropped from 0.97 to 0.48 and was mis-ranked as `verification_gap`; validation dropped from 1.00 to 0.74/0.77; context and mixed were pulled toward `no_material_friction`. Friction scenarios diagnosed: 1 of 4 on both repeats.
- Lesson: materiality hedges in the instructions push Jev toward "no friction". Do not rewrite criteria without a paired probe.

## Accepted Drift
- Original plan/spec: rewrite the `pattern` criteria and use a budget of 20 Jev calls.
- Implemented reality: the original `pattern` text was kept, and the budget was raised to 30 before the rerun, with the raise recorded. All 30 calls were used.
- Why accepted: the plan's escalation fired on candidate A. The cause was isolated to the rewrite, and the rerun used the same frozen scenarios.

## Validation Evidence
- `bun test pi/extensions/__tests__/semantic-profiles.test.ts`: 18/18 pass. The fingerprint tamper test is retargeted to `questions.pattern`.
- `node --test tests/jev-self-improvement-controller.test.mjs`: 7/7 pass, with new tests showing the gate skips `diagnose` and real reducer output never yields `candidate`.
- `bash tests/jev-judge-smoke.sh`, `bash tests/harness-trace-retrospect-smoke.sh`: pass.
- `node --test tests/jev-plan-implement-campaign.test.mjs` 8/8 and `bun test pi/extensions/__tests__/jev-route-capsule-runtime.test.ts` 13/13: pass.
- `scripts/verify-agentic-infra core`: 22/22 with `TYPESAFE_API_KEY` unset. With the key exported, `jev-shadow-smoke` fails because its missing-key abstention cannot fire; it fails identically on `main`.
- Reviews, all same-family (no non-Claude runner on this machine):
  - plan adversary (fable): GO WITH NOTES;
  - Logic and Spec hunters (sonnet): GO WITH NOTES each;
  - code-diff adversary (fable): GO WITH NOTES.
  - Accepted notes were folded in as doc-only fixes.
- Event ledger `.workflow/jev-diagnosis-efficiency/events.jsonl`, validated with `--profile autonomous-completed`.

## Follow-up State
- Remaining risks:
  - The probe is 8 synthetic scenarios with one repeat, which is indicative but not calibrated; `calibration_status` stays `pending_corpus`.
  - Context-pressure episodes (errors plus compactions) still abstain as genuinely mixed.
  - No natively correlated real Pi trace was available locally for a live controller run.
- Parking lot:
  - Populate `retries` (a same-tool call right after that tool's error) in the extractor.
  - Aggregate recurrence across episodes; this would be the level-3 producer.
  - Fix `jev-shadow-smoke` so it ignores an exported key.
- Superseded docs/specs: the three-answer diagnosis description in `workflow/trace-self-improvement.md`, `workflow/semantic-profiles.md` and `workflow/skills/self-improvement-loop.md`.
- Next links: `workflow/trace-self-improvement.md`, `workflow/skills/self-improvement-loop.md`.
