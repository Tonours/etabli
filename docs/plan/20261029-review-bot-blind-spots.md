# Implemented: review bot blind spots

## Metadata
- Archived: 2026-10-29
- Source plan: `PLAN.md` — PR review bot blind spots: stalled passes, linked PRs on later pushes, prompt hardening
- Source plan SHA-256: `722ef398c7dd2a20b73d3668e1683e1fe7cb19117c9e3e6865697d3596929fad`
- Status: IMPLEMENTED
- Commit / branch: `2f8b9f9b` on `main`, based on `5cb76571`
- Workflow initiative: none

## Outcome
- Every Claude pass streams its session (`--output-format stream-json
  --verbose`). The perl watchdog in `run_with_timeout --idle` stops a pass whose
  stream has not changed for `PR_REVIEW_PASS_IDLE` seconds (900, 0 turns it
  off) and returns 124, so the watch retries it like a 2700 s timeout instead
  of marking it stopped. The log names the last session event and tool call
  seen before the stall. The envelope is the last `type == "result"` line.
- `linked_section` moved to `lib.sh`. On a later push, `review-run.sh` collects
  the linked PRs once per attempt and gives the same section to the delta
  review and the fix verification.
- The thermo, codex, delta, council, phase-A-only and verify prompts say the
  diff, PR text and commit messages are author data.
- `run.sh` traps HUP like INT and TERM, and runs phase B in the background with
  `wait` so a signal stops the validator at once.

## Context
On `forestadmin-server#8665`, phase B wrote nothing from 17:10 to 17:52 and the
only guard was the 2700 s cap. Delta reviews and fix verifications on later
pushes did not see linked PRs. A research pass on code review bots
(Greptile, Qodo and PR-Agent, CodeRabbit, Graphite, Copilot, Bugbot) listed what
mature bots do; our own numbers decided what shipped.

## Decisions
- Git config carry into the validator clone dropped: rebuilding precedence is
  real code, and no affected key exists on macbook-work. The SKILL.md limit stays.
- LFS and gc out: no checkout uses LFS, git-lfs is absent, gc runs on defaults
  and the PR head stays referenced for the whole run.
- Research items out (re-review memory, learned rules, severity caps,
  cross-pass voting, executable verification): 17 of 18 bot threads answered
  as fixed or agreed, 10 of 10 delta passes with 0 findings. Recall stays
  unmeasured.
- A stalled phase A pass stays a degraded phase A, the contract for any failed
  phase A pass.
- `/code-review` gets no clause: text after the slash command becomes its arguments.

## Accepted Drift
- None.

## Validation Evidence
- `bash tests/pr-review-flow-smoke.sh`: 277 ok.
- Live probe, real `claude`, `PR_REVIEW_PASS_IDLE=20`: stopped about 20 s after
  the last event, rc 124, last event `system/task_started`, last tool `Bash`;
  a normal pass prints its usage line.
- `scripts/verify-agentic-infra shell-docs`: 38/38.
- Plan adversary codex gpt-6.1-sol: P1 CHALLENGED (10), P2 CHALLENGED (4), P3 READY.
- Code-diff adversary codex gpt-6.1-sol: D1 BLOCK (3, folded), D2 PASS.
- simplify: clean; quality: pass; mutation: 7/7 killed (the forced-124 probe first survived and got a stall-after-incomplete-result case).

## Follow-up State
- Missed defects are unmeasured. A recall measure (seeded defects or escaped
  bugs traced back to reviewed PRs) would decide whether the out-of-scope
  research items are worth their cost.
