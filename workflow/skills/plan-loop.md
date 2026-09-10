# Plan Loop Contract

Shared contract for creating or reviewing `PLAN.md` and stopping at
`CHALLENGED` or `READY`.

Runtime adapters may add tool syntax. They must not change the planning
ladder, the READY gate, or the no-implement rule.

## Purpose

Shape a plan in the workspace root `PLAN.md`. Stop when the plan is
`READY` or `CHALLENGED`. Do not implement.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order.
Try each path with a direct read; do not stop at the first miss.

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `PLAN_TEMPLATE.md`
   - `PLAN_TEMPLATE_FULL.md`
2. Prefer absolute installed home copies (stable when skill or command
   paths are realpath'd):
   - `~/.pi/agent/PLAN_TEMPLATE.md`, `~/.pi/agent/PLAN_TEMPLATE_FULL.md`,
     `~/.pi/agent/workflow/spec.md`
   - `~/.claude/PLAN_TEMPLATE.md`, `~/.claude/PLAN_TEMPLATE_FULL.md`,
     `~/.claude/workflow/spec.md`
   - `~/.agents/PLAN_TEMPLATE.md`, `~/.agents/PLAN_TEMPLATE_FULL.md`,
     `~/.agents/workflow/spec.md`
3. Relative install-surface fallbacks (logical path only; do not realpath
   the skill or command dir first):
   - From `~/.pi/agent/skills/<skill>` or `~/.agents/skills/<skill>`:
     `../../PLAN_TEMPLATE.md`, `../../PLAN_TEMPLATE_FULL.md`,
     `../../workflow/spec.md`
   - From `~/.claude/commands`: `../PLAN_TEMPLATE.md`,
     `../PLAN_TEMPLATE_FULL.md`, `../workflow/spec.md`
4. Relative Etabli-repo fallbacks after realpath into the adapter dir:
   - From `pi/skills/<skill>`: `../../../PLAN_TEMPLATE.md`,
     `../../../PLAN_TEMPLATE_FULL.md`, `../../../workflow/spec.md`
   - From `claude/scopes/shared/commands/`: `../../../../PLAN_TEMPLATE.md`,
     `../../../../PLAN_TEMPLATE_FULL.md`, `../../../../workflow/spec.md`
5. If any fallback file exists, read it and continue. Do not tell the user
   the template or spec is missing.
6. If all workspace and fallback copies are missing, create `PLAN.md` from
   the template shape embedded in this contract and report the missing
   source paths as a warning, not as a blocker.

Embedded fallback shape:

```md
# PLAN.md

## Meta
- Subject:
- Status: DRAFT | CHALLENGED | READY
- Last revised:
- Archive: pending until implemented and validated

## Goal

## Workflow Contract
- Route:
- Role:
- Stop condition:
- Required evidence:

## Acceptance Criteria
-

## Scope
### In
-

### Out
-

## Facts And Assumptions
### Observed Facts
-

### Assumptions
- None / ...

## Steps
1.
2.
3.

## Checks
- command:
  - expected:
  - last run:

## Risks
- None / ...

## Decision Log
- YYYY-MM-DD:

## Open Questions
- None / ...

## Notes / Handoff
-
```

## Required Sequence

1. Inspect repo state (`git status --short`) and relevant files. Load a
   domain suite only if the brief clearly matches one. Name the skill(s)
   used, or `none`, in `Notes / Handoff`.
2. Create or refresh `PLAN.md` from `PLAN_TEMPLATE.md`.
3. Use `PLAN_TEMPLATE_FULL.md` only for broad or risky work.
4. Set `Status: DRAFT` first.
5. Fill `Workflow Contract` for non-trivial plans:
   - `Route`: selected workflow route from `workflow/spec.md`.
   - `Role`: planner, challenger, reviewer, verifier, implementer,
     reporter, or a bounded combination.
   - `Stop condition`: exact condition that ends the current workflow.
   - `Required evidence`: command, artifact, source, or manual check
     needed before completion.
6. Critique scope, route, role, stop condition, evidence, steps, checks,
   assumptions, and risks.
7. Do not mark `READY` if route, stop condition, required evidence, or
   checks are missing for non-trivial implementation-bound work.
8. Update `PLAN.md` in place to `CHALLENGED` or `READY`.
9. Ask only narrow blocking questions.
10. Return final status, blockers if any, and next action.

## Rules

- Do not implement.
- Do not create or update `docs/plan/` archives during planning.
- Do not create `REVIEW.md`.
- Do not ask whether to implement next.
- If the user asked for autonomous plan-loop completion, this contract is
  only the planning phase; the route must be `plan-implement`, which
  continues after the actual root `PLAN.md` is `READY`.

## Completion Evidence

A plan-loop pass is complete only when the handoff names the final
`PLAN.md` status (`READY` or `CHALLENGED`), any blockers, and the next
action. Implementation is out of scope.
