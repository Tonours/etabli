# Plan Loop Contract

Shared contract for creating or reviewing `PLAN.md`.

Runtime adapters may add tool syntax. They must not change the source
resolution, the READY gate, or the no-implement rule.

## Purpose

Shape the workspace root `PLAN.md`. Stop at `READY` or `CHALLENGED`.

## Source resolution

Read the workspace `workflow/spec.md`, `PLAN_TEMPLATE.md` and
`PLAN_TEMPLATE_FULL.md`; for a missing one, try the same relative path under
`~/.pi/agent/`, `~/.claude/`, then `~/.agents/`. Only when every copy is
missing, create `PLAN.md` with the sections Meta, Goal, Workflow Contract,
Acceptance Criteria, Scope (In / Out), Facts And Assumptions, Steps, Checks,
Risks, Decision Log, Open Questions and Notes / Handoff, and report the missing
paths as a warning, not a blocker.

## Required Sequence

1. Inspect repo state (`git status --short`) and relevant files. Load a
   domain suite only if the brief clearly matches one. Name the skill(s)
   used, or `none`, in `Notes / Handoff`.
2. Create or refresh `PLAN.md` from `PLAN_TEMPLATE.md`.
3. Use `PLAN_TEMPLATE_FULL.md` only for broad or risky work.
4. Set `Status: DRAFT` first.
5. Fill `Workflow Contract` for non-trivial plans:
   - `Route`: the workflow route from `workflow/spec.md`.
   - `Role`: planner, challenger, reviewer, verifier, implementer, reporter,
     or a bounded combination.
   - `Stop condition`: exact condition that ends the current workflow.
   - `Required evidence`: command, artifact, source, or manual check needed
     before completion.
6. Critique scope, route, role, stop condition, evidence, steps, checks,
   assumptions, risks.
7. Do not mark `READY` if route, stop condition, required evidence, or
   checks are missing for non-trivial implementation-bound work.
8. Update `PLAN.md` in place to `CHALLENGED` or `READY`.
9. Ask only narrow blocking questions.
10. Return final status, blockers, and next action.

## READY Gate

A plan is `READY` only with: a clear goal; bounded scope and non-goals when
needed; concrete steps; named files or areas for risky changes; checks to run;
route, role, stop condition and required evidence for non-trivial work; known
risks or an explicit "none"; facts separated from assumptions when the task
depends on uncertain context; no blocking open question. `workflow/spec.md`
§ Minimal READY gate is the canonical list and wins on conflict.

## Rules

- Do not implement.
- Do not create or update `docs/plan/` archives during planning.
- Do not create `REVIEW.md`.
- Do not ask whether to implement next.
- For autonomous plan-loop completion this contract is only the planning
  phase; the route must be `plan-implement`, which continues after the
  actual root `PLAN.md` is `READY`.

## Completion Evidence

A plan-loop pass is complete only when the handoff names the final
`PLAN.md` status (`READY` or `CHALLENGED`), any blockers, and the next
action.
