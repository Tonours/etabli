# Implemented: Close Etabli planning, completion, and self-improvement evidence gaps

## Metadata
- Archived: 2026-09-18
- Source plan: `PLAN.md` — Close Etabli planning, completion, and self-improvement evidence gaps
- Source plan SHA-256: `fe01fcb67fb6f810b241f86077f96d2894174c3f7b71bb11cf146e2b5bcbb697`
- Status: IMPLEMENTED
- Commit / branch: uncommitted workspace patch
- Workflow initiative: close-harness-gaps

## Outcome
- Planning now compares project intent, specifications, decisions, code, tests, gaps, and evidence before READY.
- READY and check-freeze fail closed on incomplete or malformed plans, with CommonMark AST parsing for status and active-HTML semantics.
- Autonomous completion binds successful current validation, review, adversary, outcome, archive, and plan-removal evidence to the final change.
- Retrospective recurrence counts initiatives rather than duplicate observations; self-improvement supports frozen quality, efficiency, and reliability objectives with protected evaluator provenance.
- Loop guidance separates observation, command, and campaign budgets. TypeSafe/Jev was assessed as an optional typed semantic judgment provider and handed to a dedicated follow-up plan.

## Context
- `workflow/spec.md`: canonical routing, READY, completion, and self-improvement map.
- `docs/research/20260917-harness-engineering-loops.md`: primary-source harness/loop research and reproduced local gaps.
- `docs/research/20260918-typesafe-ai-etabli-fit.md`: TypeSafe fit analysis and guarded pilot shape.
- `scripts/lib/plan-check-freeze.mjs`: executable READY/check-freeze semantics.
- `.workflow/close-harness-gaps/events.jsonl`: canonical implementation and validation ledger.

## Decisions
### Trace specifications and code together
- Context: code-only reconnaissance could miss project intent and absent specification coverage.
- Choice: require a proportional Requirement Trace from request/spec/decisions through observed code/tests, gap disposition, and evidence.
- Rejected options: making a missing spec automatically blocking; creating a second planning artifact.
- Rationale: the single plan remains restartable while gaps stay explicit and actionable.
- Consequences: READY requires a populated trace for non-trivial work.

### Bind completion to the final state
- Context: event presence and earlier successful reviews could survive later code changes or failures.
- Choice: resolve latest verdicts, require success, and order final validation/review/adversary evidence after relevant changes.
- Rejected options: presence-only completion and committed-diff-only review.
- Rationale: completion must describe the shippable workspace patch.
- Consequences: accepted review fixes invalidate prior closure evidence and require a fresh frozen-patch pass.

### Use explicit self-improvement objectives
- Context: strict held-in pass gain could not express safe cost or reliability improvements.
- Choice: freeze objective, metric, direction, threshold, population, and evaluator bundle while retaining per-task safety/non-regression and combined-candidate retesting.
- Rejected options: one universal quality objective and adaptive candidate-owned evaluators.
- Rationale: comparison semantics stay inspectable and protected.
- Consequences: synthetic harness coherence remains distinct from measured runtime improvement.

### Delegate CommonMark semantics to a standards parser
- Context: adversarial review exposed repeated edge cases in the custom Markdown interpretation.
- Choice: vendor CommonMark 0.31.2 under BSD-2-Clause with retained third-party notices and walk its AST for status and active HTML, retaining narrow Etabli policy above it.
- Rejected options: continuing to grow a partial parser; a host-only Pandoc dependency.
- Rationale: one grammar now owns lists, blockquotes, code, comments, HTML, and references in every runtime.
- Consequences: the vendored parser becomes a reviewed runtime dependency.

## Accepted Drift
- Original plan/spec: the plan did not anticipate replacing the status/HTML interpretation layer.
- Implemented reality: repeated fresh-context findings justified a vendored CommonMark AST dependency and a broader adversarial regression corpus.
- Why accepted: local patches repeatedly moved another Markdown boundary; the parser dependency removes that error-prone responsibility while preserving fail-closed workflow policy.

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: 19/19 checks passed, including 273 Pi tests and 212/212 router evaluations.
- command: `bash tests/dual-runtime-guard-matrix-smoke.sh`
  - result: READY, check-freeze, comments, code, references, lists, and blockquote matrix passed in LF/CRLF variants.
- command: `git diff --check -- . ':(exclude)pi/extensions/pi-mobile-bridge.ts'`
  - result: passed; unrelated user file remained excluded.
- command: frozen-patch Logic, Spec, and code-diff adversary reviews
  - result: GO on frozen patch v85 (`5c501d49ccba0f404aaf3d4666b853863f0fee1f5352f53ef802f89354802868`) from Logic, Spec, and code-diff adversary reviewers.

## Follow-up State
- Remaining risks: representative task campaigns have not yet measured productivity or quality gain; the new contracts prove harness coherence.
- Parking lot: calibrated Jev shadow evaluation and real provider smoke are owned by the next plan.
- Superseded docs/specs: none.
- Next links: `docs/research/20260918-typesafe-ai-etabli-fit.md` and the next Jev integration plan.
