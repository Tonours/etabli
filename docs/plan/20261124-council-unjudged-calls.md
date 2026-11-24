# Implemented: council denial check excuses calls the auto mode classifier never judged

## Metadata
- Archived: 2026-11-24
- Source plan: `PLAN.md` - council denial check excuses calls the auto mode classifier never judged
- Source plan SHA-256: `5d65bd4316b1a95c44cbce9d28ea67ec577e397268edb690eb1f90e338afd5d3`
- Status: IMPLEMENTED
- Tier: standard; review: one fresh review
- Commit / branch: `fix/council-unjudged-calls`, base `e9967dac`, head `ecd4300a`

## Outcome
- `lib.sh` `excused_ids` (was `hook_refusal_ids`) excuses a denied tool_use whose result is a PreToolUse hook error or `The server-side auto mode classifier gave no verdict for ...`. A real classifier denial still vetoes the pass.
- New smoke cases: an unjudged call alone passes (AC-1), a real denial beside an unjudged one still fails with one counted (AC-2). Hook refusal cases unchanged (AC-3).

## Evidence
- `bash tests/pr-review-gates-smoke.sh`: rc 0, `all pr-review gate checks passed`.
- `bash tests/pr-review-flow-smoke.sh`: rc 0, `PR review flow smoke test: ok`.
- Mutation: dropping the unjudged alternative fails AC-1; matching any classifier text fails AC-2.
- Review: fresh reviewer GO WITH NOTES, no finding.

## Risks
- A future CLI rewording of the unjudged text stops the excuse silently, back to today's veto (fail-closed).
