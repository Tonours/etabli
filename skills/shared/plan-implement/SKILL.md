---
name: plan-implement
description: Plans, then implements a task in one run once PLAN.md is READY. Use for multi-step work needing a plan and its implementation; not for planning alone or plan-free fixes.
argument-hint: [task description]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Agent, Skill]
---

# Plan Implement

Follow the shared contract in `workflow/skills/implementation-loop.md`. The
routing map `workflow/spec.md` wins on conflict; open it only when the route or
a gate is in doubt.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Run `workflow/skills/plan-loop.md` first when a task is provided. Load a
domain suite only when the brief clearly matches one.

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
- Council reuse file: right after the clean final review round, before the
  archive (implementation-loop step 14) deletes `PLAN.md`, when that round's
  passes match the council's phase A on the same acceptance criteria (two
  fresh-context reviews plus a cross-family pass with effective-model
  provenance), commit the reviewed patch, then write the round to a file
  outside the repo whose first line is `patch-sha256: ` followed by
  `~/.claude/scripts/pr-council-review/run.sh --reuse-sha origin/<base>` (after a
  fetch, so it matches the PR's merge base).

## Delivery

After validation, archive and push (implementation-loop steps 14-18), deliver
by the branch and ticket:

- Default branch with direct commits (like etabli): no PR step; report the
  pushed SHAs.
- Linear ticket linked (in the branch name or the brief):
  1. Open the PR with the `pr` skill.
  2. Run the council at its default high effort, posting:
     `~/.claude/scripts/pr-council-review/run.sh <N> --post` (the
     `pr-council-review` skill on Claude; the same script through Bash on
     Pi). Script missing, or a run that fails or times out without a
     verdict → `council: unavailable`, stop `blocked`.
     Reuse: add `--reuse-review <file>` when the reuse file (Rules above) exists.
     The script skips phase A only when the fingerprint still matches the PR
     (the plan archive aside) and never once the validator reviewed the
     head; the validator gate always applies.
  3. Fix every blocking finding, push, rerun the council. At most 3 rounds;
     still not GO after round 3 → stop `blocked` with the open findings.
  4. Only after GO, move the Linear ticket to In Review.
  5. End with the PR link.
  A blocked stop leaves the Linear ticket untouched.
- No Linear ticket: open the PR with the `pr` skill, end with its link.
- Under fleet (`FLEET_SESSION_ID` set): PR and council run directly; ask for
  the Linear status change through a `fleet question` to the host instead of
  writing it.
