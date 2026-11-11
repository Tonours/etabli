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

For ordinary single-surface bugfixes without a plan, choose the bounded-fix
route before invoking this skill. An explicit `/plan-implement` invocation
keeps the plan gate. Run `workflow/skills/plan-loop.md` first when a task is provided. Load a
domain suite only when the brief clearly matches one.

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
- At READY, the user may choose a fresh `/implement` session with the plan
  handoff; continue this run by default. No automatic clear or compaction.
  For bounded implementation slices, Claude may delegate to its existing
  fresh-context `worker` (Sonnet/medium); Codex uses its available native
  worker when authorized, and Pi stays parent-only. Verify each diff and
  proof; only the parent updates `PLAN.md`.
- Council reuse file: right after the clean final review round, before the
  archive (implementation-loop step 14) deletes `PLAN.md`, when that round's
  passes match the council's phase A on the same acceptance criteria (two
  fresh-context reviews plus a cross-family pass with effective-model
  provenance), commit the reviewed patch, then write the round to a file
  outside the repo with `~/.claude/scripts/pr-council-review/run.sh
  --record-review origin/<base> <complete-round-report> <reuse-file>` after a
  fetch. Keep the destination outside the checkout or ignored. It is replaced
  atomically with private permissions; a failure leaves its prior bytes intact.
  Check the exit code. This packages the committed patch fingerprint plus exact
  report bytes; it does not certify the
  passes, effective-model provenance or matching criteria. Pass an eligible file
  explicitly to the council with `--reuse-review`; keep private paths out of PRs.
  For automatic discovery, omit `<reuse-file>` and add `--eligible-review`
  after the report path, explicitly attesting the same two fresh-context
  reviews and cross-family effective-model provenance on matching criteria.
  Only that mode writes a private auto-discoverable record; packaging still
  certifies no review. `--post` discovers it for the same checkout, base and
  patch for one hour, including a later archive-only commit. `--no-reuse`
  forces a complete council. Legacy explicit receipt paths remain supported.

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
