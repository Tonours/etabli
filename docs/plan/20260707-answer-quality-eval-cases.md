# Implemented: answer quality eval cases

## Metadata
- Archived: 2026-07-07
- Source plan: answer quality eval cases
- Status: IMPLEMENTED
- Commit / branch: `main` at `f7f3e26` plus uncommitted working-tree changes

## Outcome

Added a versioned answer-quality fixture corpus and local eval runner. Etabli can
now check that `scripts/answer-quality-check` keeps expected behavior across
typical, edge, and adversarial artifacts instead of relying only on temporary
smoke fixtures.

## Context

- `scripts/answer-quality-check`: deterministic quality-floor helper added in a
  previous slice.
- `tests/answer-quality-check-smoke.sh`: temporary smoke fixtures existed, but
  no versioned representative corpus.
- `docs/answer-quality-eval-cases.md`: source-backed design note for the local
  fixture strategy.
- `/Volumes/Crucial/work/obvault/kb/source-grounded-answer-quality.md`: durable
  second-brain note now links the eval runner and manifest.

## Decisions

### Versioned Fixture Eval Before Model Graders
- Context: The active goal asks for higher answer quality, but the repo had no
  representative eval cases.
- Choice: Add `scripts/answer-quality-eval` plus
  `tests/fixtures/answer-quality/manifest.tsv`.
- Rejected options: API-backed model graders, subjective 10/10 scoring, or
  storing executable cases in obvault.
- Rationale: OpenAI eval guidance supports starting with datasets of typical,
  edge, and adversarial examples; Anthropic guidance supports simple,
  transparent systems before adding complexity.
- Consequences: Helper regressions are now caught by a local manifest; live
  model output quality remains a future evaluation layer.

### Manifest Validation Is Part Of The Runner
- Context: An invalid mode could otherwise be counted as an expected helper
  failure.
- Choice: Validate `mode` and `category` values in `scripts/answer-quality-eval`.
- Rejected options: Let malformed rows pass when `expected=fail`.
- Rationale: Fixture integrity matters as much as helper behavior.
- Consequences: Bad manifest metadata fails explicitly.

## Accepted Drift

- Original plan/spec: Add eval runner, manifest, docs, and obvault link.
- Implemented reality: Also validated Bash syntax for both answer-quality
  scripts and smoke wrappers during final checks.
- Why accepted: It strengthens the local validation surface without expanding
  runtime behavior.

## Validation Evidence

- command: `bash -n scripts/answer-quality-eval tests/answer-quality-eval-smoke.sh scripts/answer-quality-check tests/answer-quality-check-smoke.sh`
  - result: passed
- command: `bash tests/answer-quality-eval-smoke.sh`
  - result: passed; `answer quality eval: 10/10 cases matched expectations`
    and `answer quality eval smoke test: ok`
- command: `scripts/answer-quality-eval tests/fixtures/answer-quality/manifest.tsv`
  - result: passed; `answer quality eval: 10/10 cases matched expectations`
- command: `bash tests/answer-quality-check-smoke.sh`
  - result: passed; `answer quality check smoke test: ok`
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed; `workflow docs smoke test: ok`
- command: `scripts/research-proof-check docs/answer-quality-eval-cases.md && scripts/research-proof-check workflow/answer-quality.md && scripts/research-proof-check docs/source-grounded-answer-quality-research.md`
  - result: passed; each printed `research proof check: ok`
- command: `scripts/answer-quality-check --mode research docs/answer-quality-eval-cases.md && scripts/answer-quality-check --mode research workflow/answer-quality.md`
  - result: passed; both printed `answer quality check: ok`
- command: `(cd /Volumes/Crucial/work/obvault && bash -n _meta/*.sh && _meta/validate-kb.sh && _meta/refresh-kb.sh query "answer quality" && /Volumes/Crucial/work/etabli/scripts/answer-quality-check --mode obvault kb/source-grounded-answer-quality.md)`
  - result: passed; `validate-kb: ok`, answer-quality entrypoints found, and
    obvault note passed the helper
- command: `git diff --check`
  - result: passed in Etabli
- command: `(cd /Volumes/Crucial/work/obvault && git diff --check)`
  - result: passed
- command: `scripts/workflow-event validate answer-quality-eval-cases`
  - result: passed; `23 events, ok`

## Review Evidence

- Plan adversary: `GO WITH NOTES`; accepted findings required strict-mode
  negative cases without constraining simple chat and rejected API/model graders
  for this slice.
- Code diff review: same-context `GO WITH NOTES`; one accepted hardening
  finding added manifest metadata validation.
- Limitation: no fresh-context reviewer was launched because this run has no
  explicit subagent authorization.

## Follow-up State

- Remaining risks: this fixture eval still checks deterministic artifacts, not
  live model output, factual truth, user satisfaction, or global answer quality.
- Parking lot: add representative real-answer traces once enough reviewed
  examples exist; only then consider a model grader or pairwise evaluator.
- Superseded docs/specs: none.
- Next links:
  - `scripts/answer-quality-eval`
  - `tests/fixtures/answer-quality/manifest.tsv`
  - `docs/answer-quality-eval-cases.md`
  - `/Volumes/Crucial/work/obvault/kb/source-grounded-answer-quality.md`
