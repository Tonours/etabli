# Implemented: answer quality audit command

## Metadata
- Archived: 2026-07-07
- Source plan: answer quality audit command
- Status: IMPLEMENTED
- Commit / branch: `main` at `f7f3e26` plus uncommitted working-tree changes

## Outcome

Added `scripts/answer-quality-audit`, a consolidated local command for the
Etabli answer-quality validation suite. It can run repo-local checks with
`--skip-obvault` and include the second-brain validation with
`--obvault <path>`.

## Context

- `scripts/answer-quality-check`: quality-floor checker for durable artifacts.
- `scripts/answer-quality-eval`: versioned fixture runner for typical, edge,
  and adversarial answer-quality cases.
- `/Volumes/Crucial/work/obvault/kb/source-grounded-answer-quality.md`: durable
  obvault note now points at the consolidated audit.

## Decisions

### Explicit obvault Path
- Context: obvault validation is required for the local second-brain goal, but
  the Etabli repo may be cloned without obvault beside it.
- Choice: Require `--obvault <path>` for full validation and provide
  `--skip-obvault` for repo-local smoke.
- Rejected options: Auto-discover and mutate obvault, or make obvault mandatory
  for every smoke.
- Rationale: The audit remains portable and avoids accidental external-state
  assumptions.
- Consequences: Full local validation is one command when the path is known.

### Command Composition
- Context: The validation suite already existed as separate scripts.
- Choice: Compose existing commands and print each command before running it.
- Rejected options: Reimplement checks inside the audit script.
- Rationale: Existing helpers stay the source of truth, and failures remain
  inspectable.
- Consequences: The audit is easier to maintain and does not mask underlying
  checker behavior.

## Accepted Drift

- Original plan/spec: Add a simple audit wrapper.
- Implemented reality: Fixed a shell-glob bug found during full obvault
  validation by adding a small `run_shell_in` helper.
- Why accepted: Without this fix, `_meta/*.sh` was passed literally and the
  full audit could not validate obvault shell files.

## Validation Evidence

- command: `bash tests/answer-quality-audit-smoke.sh`
  - result: passed; printed `answer quality audit smoke test: ok`
- command: `scripts/answer-quality-audit --skip-obvault`
  - result: passed through the smoke; printed `answer quality audit: ok`
- command: `scripts/answer-quality-audit --obvault /Volumes/Crucial/work/obvault`
  - result: passed; printed `answer quality audit: ok`
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed inside the audit; printed `workflow docs smoke test: ok`
- command: `scripts/answer-quality-check --mode obvault /Volumes/Crucial/work/obvault/kb/source-grounded-answer-quality.md`
  - result: passed inside the audit; printed `answer quality check: ok`
- command: `git diff --check`
  - result: passed in Etabli
- command: `(cd /Volumes/Crucial/work/obvault && git diff --check)`
  - result: passed
- command: `scripts/workflow-event validate answer-quality-audit-command`
  - result: passed; `16 events, ok`

## Review Evidence

- Plan adversary: `GO WITH NOTES`; accepted findings required explicit/skippable
  obvault validation and visible command logging.
- Code diff review: same-context `GO WITH NOTES`; no blockers found.
- Limitation: no fresh-context reviewer was launched because this run has no
  explicit subagent authorization.

## Follow-up State

- Remaining risks: the audit still validates deterministic artifacts and vault
  hygiene, not live model output quality or user satisfaction.
- Parking lot: once reviewed real-answer traces exist, extend this command or a
  companion runner to include those trace fixtures.
- Superseded docs/specs: none.
- Next links:
  - `scripts/answer-quality-audit`
  - `tests/answer-quality-audit-smoke.sh`
  - `workflow/answer-quality.md`
  - `/Volumes/Crucial/work/obvault/kb/source-grounded-answer-quality.md`
