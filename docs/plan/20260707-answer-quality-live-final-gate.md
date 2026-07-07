# Implemented: Answer-quality live final gate

## Metadata
- Archived: 2026-07-07
- Source plan: answer-quality live final gate
- Status: IMPLEMENTED
- Commit / branch: branch `main`; base commit `f7f3e26`; commit pending

## Outcome
- Added a `Live Final Answer Gate` section to `workflow/answer-quality.md`.
- Updated the repo, Codex, Pi, and Claude adapters so final answers explicitly
  apply that gate.
- Pinned the live-gate section and adapter wording in
  `tests/workflow-docs-smoke.sh`.
- Preserved the rule that answer quality is an evidence-backed discipline, not
  a numeric quality promise.

## Context
- `workflow/answer-quality.md` already defined the quality gate, helper checks,
  eval fixture corpus, audit command, and trace coverage.
- Runtime adapters referenced `workflow/answer-quality.md`, but the final
  response moment did not explicitly name the live gate.
- The active goal asked for answers that are consistently high quality and
  efficient; the maintainable way to improve that is a final-answer discipline,
  not an unverifiable top-score claim.

## Decisions
### Add a lightweight live gate instead of a new hook
- Context: The system already has deterministic checks for durable artifacts
  and trace reviews.
- Choice: Add a concise final-answer gate to the shared contract and point the
  adapters at it.
- Rejected options: Add a blocking runtime scorer; require a new artifact for
  every chat answer.
- Rationale: There was no repeated evidence justifying new machinery, and live
  final answers need a small last-pass check.
- Consequences: Future agents see the gate at the moment of response while the
  detailed rules stay centralized in `workflow/answer-quality.md`.

### Avoid score-overclaim wording
- Context: An initial negative sentence still contained score-overclaim wording
  and failed `scripts/answer-quality-check`.
- Choice: Reword to "avoid promising a numeric quality score" and "do not
  promise a top score".
- Rejected options: Loosen the checker; keep the failing phrase because it was
  negated.
- Rationale: The checker is intentionally conservative around score-overclaim
  language, and the contract can express the same idea without triggering it.
- Consequences: The audit remains green and the no-overclaim discipline is
  preserved.

## Accepted Drift
- Original plan/spec: Add a final-answer gate and preserve score-boundary
  framing.
- Implemented reality: The first wording failed the overclaim regex; the final
  implementation uses score-boundary language instead.
- Why accepted: The accepted drift made the contract clearer and kept the
  validation suite strict.

## Validation Evidence
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed with `workflow docs smoke test: ok`
- command: `scripts/answer-quality-check --mode research workflow/answer-quality.md`
  - result: passed with `answer quality check: ok`
- command: `scripts/answer-quality-audit --obvault /Volumes/Crucial/work/obvault`
  - result: passed with `answer quality audit: ok`
- command: `git diff --check`
  - result: passed in Etabli
- command: `(cd /Volumes/Crucial/work/obvault && git diff --check)`
  - result: passed
- command: `scripts/workflow-event validate answer-quality-live-final-gate`
  - result: passed with `10 events, ok` after archive, cleanup, and completion

## Follow-up State
- Remaining risks: This reduces live-answer drift but still cannot prove every
  future answer will satisfy the user's ideal quality bar.
- Parking lot: Add new saved traces for future near misses or failures; only
  add heavier runtime enforcement after repeated evidence of missed live gates.
- Superseded docs/specs: none.
- Next links:
  - `workflow/answer-quality.md`
  - `AGENTS.md`
  - `codex/AGENTS.md`
  - `pi/AGENTS.md`
  - `claude/CLAUDE.md`
  - `tests/workflow-docs-smoke.sh`
