# Implemented: answer quality evaluation harness

## Metadata
- Archived: 2026-07-07
- Source plan: answer quality evaluation harness
- Status: IMPLEMENTED
- Commit / branch: `main` at `f7f3e26` plus uncommitted working-tree changes

## Outcome

Added a deterministic answer-quality floor for durable Etabli and obvault
artifacts. The new helper rejects missing objective markers and unsupported
perfection/correctness overclaims, but explicitly does not score answers as
objectively 10/10.

## Context

- `workflow/answer-quality.md`: shared answer-quality contract existed without
  a dedicated mechanical check.
- `scripts/research-proof-check`: existing pattern for source/status marker
  validation.
- `/Volumes/Crucial/work/obvault/kb/source-grounded-answer-quality.md`: durable
  obvault note that now links the Etabli helper.

## Decisions

### Quality Floor, Not Score
- Context: The goal asks for answers to reach 10/10 quality and efficiency, but
  a script cannot prove subjective final-answer quality.
- Choice: Implement `scripts/answer-quality-check` as a mode-based floor for
  objective markers.
- Rejected options: Fake automated score, mandatory source markers for every
  simple answer.
- Rationale: The helper can catch missing evidence and overclaims without
  reward-hacking the broader answer-quality contract.
- Consequences: Durable artifacts get a runnable check; final answer judgment
  still uses `workflow/answer-quality.md`.

### Wikilinks Count As obvault Entrypoints
- Context: obvault notes naturally use `[[second-brain-operating-model]]` and
  `[[_index]]` rather than full repo paths.
- Choice: `--mode obvault` accepts both path references and wikilinks.
- Rejected options: Force obvault notes to duplicate path-style references.
- Rationale: The validator should match the vault's real linking model.
- Consequences: The smoke test now covers wikilink-style entrypoints.

## Accepted Drift

- Original plan/spec: Add only contract pointers and helper docs.
- Implemented reality: Also indexed `answer-quality-check` in `README.md`.
- Why accepted: README already lists validation helpers, and the docs smoke test
  now pins the helper there for maintainability.

## Validation Evidence

- command: `bash tests/answer-quality-check-smoke.sh`
  - result: passed; printed `answer quality check smoke test: ok`
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed; printed `workflow docs smoke test: ok`
- command: `scripts/answer-quality-check --mode research docs/source-grounded-answer-quality-research.md`
  - result: passed; printed `answer quality check: ok`
- command: `scripts/answer-quality-check --mode research workflow/answer-quality.md`
  - result: passed; printed `answer quality check: ok`
- command: `scripts/research-proof-check workflow/answer-quality.md && scripts/research-proof-check docs/source-grounded-answer-quality-research.md`
  - result: passed; both printed `research proof check: ok`
- command: `(cd /Volumes/Crucial/work/obvault && bash -n _meta/*.sh && _meta/validate-kb.sh && _meta/refresh-kb.sh query "answer quality" && /Volumes/Crucial/work/etabli/scripts/answer-quality-check --mode obvault kb/source-grounded-answer-quality.md)`
  - result: passed; `validate-kb: ok`, answer-quality entrypoints found, and
    obvault answer-quality note passed the helper
- command: `git diff --check`
  - result: passed in Etabli
- command: `(cd /Volumes/Crucial/work/obvault && git diff --check)`
  - result: passed
- command: `scripts/workflow-event validate answer-quality-eval-harness`
  - result: passed; `24 events, ok`

## Review Evidence

- Plan adversary: `GO WITH NOTES`; accepted findings required quality-floor
  wording and overclaim detection.
- Code diff review: same-context `GO WITH NOTES`; no blockers found.
- Limitation: no fresh-context reviewer was launched because this run had no
  explicit subagent authorization.

## Follow-up State

- Remaining risks: the helper can only validate objective markers; it cannot
  prove real answer quality, factual correctness, or completeness by itself.
- Parking lot: future eval datasets or trace graders could exercise real answer
  examples once representative cases exist.
- Superseded docs/specs: none.
- Next links:
  - `workflow/answer-quality.md`
  - `scripts/answer-quality-check`
  - `tests/answer-quality-check-smoke.sh`
  - `/Volumes/Crucial/work/obvault/kb/source-grounded-answer-quality.md`
