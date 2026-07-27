---
description: Plan, review, then implement only when PLAN.md is READY
argument-hint: [task description]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan Implement

User request: $ARGUMENTS

Follow `workflow/spec.md` and the shared contract in
`workflow/skills/implementation-loop.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order.
Try each path with a direct read; do not stop at the first miss.

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/plan-archive.md`
   - `workflow/skills/implementation-loop.md`
   - `workflow/skills/adversary.md`
   - `PLAN_TEMPLATE.md`
   - `PLAN_TEMPLATE_FULL.md`
2. Prefer absolute installed home copies (stable when command paths are realpath'd):
   - `~/.claude/PLAN_TEMPLATE.md`, `~/.claude/PLAN_TEMPLATE_FULL.md`
   - `~/.pi/agent/PLAN_TEMPLATE.md`, `~/.pi/agent/PLAN_TEMPLATE_FULL.md`
   - `~/.agents/PLAN_TEMPLATE.md`, `~/.agents/PLAN_TEMPLATE_FULL.md`
   - and matching workflow files under each of those roots:
     - `workflow/spec.md`, `workflow/plan-archive.md`
     - `workflow/skills/implementation-loop.md`, `workflow/skills/adversary.md`
3. Relative install-surface fallbacks (logical path only; do not realpath the command dir first):
   - From `~/.claude/commands`:
     - `../PLAN_TEMPLATE.md`, `../PLAN_TEMPLATE_FULL.md`
     - `../workflow/spec.md`, `../workflow/plan-archive.md`
     - `../workflow/skills/implementation-loop.md`, `../workflow/skills/adversary.md`
4. Relative Etabli-repo fallbacks after realpath into `claude/commands/`:
   - `../../PLAN_TEMPLATE.md`, `../../PLAN_TEMPLATE_FULL.md`
   - `../../workflow/spec.md`, `../../workflow/plan-archive.md`
   - `../../workflow/skills/implementation-loop.md`, `../../workflow/skills/adversary.md`
5. If any fallback file exists, read it and continue. Do not tell the user the template/spec is missing.
6. If archive instructions are missing after all lookups, still implement only from `READY`; skip archiving with a warning instead of inventing an archive format.

Run `plan-loop` behavior when `$ARGUMENTS` is present, then follow
`workflow/skills/implementation-loop.md`.

If `$ARGUMENTS` is self-improvement of Etabli itself, also read
`workflow/skills/self-improvement-loop.md`. If it is an ambitious or A-to-Z
project, also read `workflow/skills/ambitious-project-loop.md`. These contracts
add evidence and slicing requirements; they do not replace the `READY` gate or
authorize push, PR, deploy, release, or external write-back.

## Autonomous chain

This command is the full-auto workflow. Run every phase in one uninterrupted
flow — never stop between phases to ask "continue?":

1. Understand: scoped local recon of the affected area; dispatch scouts only
   for an explicitly selected multi-model profile, then carry sourced findings
   into the plan.
2. Plan: create/refresh `PLAN.md`, self-critique to `READY` or `CHALLENGED`.
3. Adversary: run the cross-model pass non-interactively (`codex exec
   --sandbox read-only` piping `PLAN.md`, per `/adversary`); fold accepted
   findings; continue only if still `READY`. If Codex is unavailable, run the
   adversary contract yourself and record that the pass was same-model.
4. Implement the `READY` plan steps in order; code behavior changes ship with
   their tests, bug fixes start from a failing test.
5. Run the plan checks, then a simplification pass (re-run checks if it
   edited anything).
6. Fresh-context review: dispatch a read-only reviewer subagent on the diff
   (per `workflow/spec.md`); fold blockers, rerun checks if edits were needed.
7. Code-diff adversary: run the adversary Code diff mode cross-model on the
   implementation diff; in an autonomous run without a cross-model runner,
   stop as `blocked`.
8. Archive to `docs/plan/`, delete root `PLAN.md`, report the final handoff.

Record the event ledger (`.workflow/<slug>/events.jsonl`) across the run and
respect the no-progress and cap rules from `workflow/spec.md`.

Stops are limited to: `CHALLENGED` plan, blocker surviving adversary or review,
no-progress rule, missing validation surface, or a human checkpoint category
(destructive, production, secrets, external write-back).

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not pause between phases for a go-ahead; the stop list above is exhaustive.
- Do not create `REVIEW.md`.
