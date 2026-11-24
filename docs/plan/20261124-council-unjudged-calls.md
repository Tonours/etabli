# PLAN.md

## Meta
- Subject: council denial check excuses calls the auto mode classifier never judged
- Status: VALIDATED
- Branch: fix/council-unjudged-calls
- Last revised: 2026-11-24
- Archive: docs/plan/20261124-council-unjudged-calls.md

## Goal
A council pass whose only "denials" are auto mode calls the classifier gave no
verdict on is no longer vetoed as incomplete. A real denial still vetoes.

## Workflow Contract
- Route: plan-implement
- Role: planner, implementer, reporter
- Tier: standard
- Budget: one implementation round, review budget per review-rounds.md
- Stop condition: PR open with the focused smoke green and one fresh review clean.
- Required evidence: `bash tests/pr-review-gates-smoke.sh` green with the new cases; mutation probe result; review verdict.

## Acceptance Criteria
- AC-1 [product]: a `permission_denials` entry whose tool_result says `The server-side auto mode classifier gave no verdict for ...` does not fail `check_denials`. Proof: new smoke case, rc 0, listed as not a veto.
- AC-2 [product]: a real classifier denial (`Permission for this action was denied by the Claude Code auto mode classifier`) beside an unjudged call still fails the pass. Proof: smoke case rc 1, only the real one counted.
- AC-3 [product]: hook refusals keep their behavior. Proof: existing hook cases green.

## Repos
- Owner: this repo
- Satellite: none

## Scope
### In
- `claude/scopes/work/scripts/pr-council-review/lib.sh` (`hook_refusal_ids`, `check_denials`)
- `tests/pr-review-gates-smoke.sh`
### Out
- Disabling user hooks for the validator (would change the forest plugin run).
- Real classifier denials (pkill and alike) stay a veto.

## Facts And Assumptions
### Observed Facts
- Mac validator streams `$TMPDIR/pr-council-{109,2082,8724,10296}.*/validator.json.stream`: 11 denials, 10 carry "The server-side auto mode classifier gave no verdict for Bash|mcp__linear__get_issue: another call in this response was changed after auto mode reviewed it ... This is not a judgment that the action is unsafe. Issue the Bash call again". One (pkill) is "[Destructive or Unwanted Actions]".
- Each pass ended `denials=3`, `validator exit 3`, so the watcher marked the sha `.dryrun-exhausted` (reports `*-dryrun.md` on the Mac).
- `lib.sh:106-117` excuses only `^PreToolUse:[A-Za-z_]+ hook error: ` results; `lib.sh:119-140` counts the rest as a veto. Precedent: 25db94fc (#128).
- `tests/pr-review-gates-smoke.sh:118-133` pins the hook refusal cases and the "hook refusal(s), not a veto" label.

### Assumptions
- None.

## Requirement Trace
| Requirement / source | Observed state | Gap / ambiguity | Decision | Step / expected evidence |
| --- | --- | --- | --- | --- |
| Unjudged call is not a veto | counted as a denial | excuse regex too narrow | in-scope correction | step 1, AC-1 case |
| Real denial vetoes | vetoes | must stay | keep | AC-2 case |
| Excuse is per call id | per id via stream | unjudged id of another call must not excuse | keep id match | existing "another call" case |

## Approach
- Input domain: tool_result error text of a denied tool_use id in the stream; string or text blocks.
- Neighbors: unjudged (excused), real classifier denial (veto), hook refusal (excused), no stream (veto).
- Mutation each test must catch: dropping the unjudged alternative (AC-1 fails), matching any classifier text (AC-2 fails).

## Steps
1. Rename `hook_refusal_ids` to `excused_ids`, match hook refusals or the unjudged classifier text; relabel the not-a-veto line.
2. Add the AC-1 and AC-2 smoke cases, update the pinned label.

## Checks
- command: `bash tests/pr-review-gates-smoke.sh`
  - expected: ok
  - last run: 2026-11-24, rc 0, `all pr-review gate checks passed`
- command: `bash tests/pr-review-flow-smoke.sh`
  - expected: ok
  - last run: 2026-11-24, rc 0, `PR review flow smoke test: ok`

## Risks
- A future CLI rewording of the unjudged text makes the excuse silently stop (back to today's veto, fail-closed).

## Decision Log
- 2026-11-24: excuse by tool_result text like #128 rather than disabling hooks for the validator.

## Review Changes
- Code review: fresh reviewer GO WITH NOTES, no finding. Note on `^` and multi-line text refuted (`jq -n '"a\nb"|test("^b")'` is false); text-block gap judged minor.
- simplify: rename only, one regex alternative. / quality: no new helper. / mutation: dropping the unjudged alternative fails AC-1, matching any classifier text fails AC-2.

## Open Questions
- None

## Notes / Handoff
- Current goal / phase: validated, archived, PR open.
- Owner decisions / constraints: "peux tu également fixer les PR en erreur" (recovery handled from the fleet side session).
- Branch / SHA: fix/council-unjudged-calls from origin/main e9967dac.
- Domain skills: none.
