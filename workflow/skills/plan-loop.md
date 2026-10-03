# Plan Loop Contract

Adapters add syntax; source resolution, READY and no-implement rules stay shared.

Shape root `PLAN.md`. Stop at `READY` or `CHALLENGED`.

## Source resolution

Read the workspace `workflow/spec.md`, `PLAN_TEMPLATE.md` and
`PLAN_TEMPLATE_FULL.md`; for a missing one, try the same relative path under
`~/.pi/agent/`, `~/.claude/`, then `~/.agents/`. Only when every copy is
missing, create `PLAN.md` with the sections Meta, Goal, Workflow Contract,
Acceptance Criteria, Scope (In / Out), Facts And Assumptions, Requirement
Trace, Steps, Checks, Risks, Decision Log, Open Questions and Notes / Handoff,
and report the missing paths as a warning, not a blocker.

## Required Sequence

1. Inspect `git status --short` and relevant request/spec, tickets, decisions,
   code, launch/tests and recipe. Record precedence, freshness and conflicts;
   derive provisional criteria from the request/confirmed decisions if no spec
   exists. Classify ACs; include missing verification setup in scope (see
   `workflow/product-verification.md`). Load domain skills only on a clear
   match; name them or `none` in `Notes / Handoff`.
2. Create or refresh `PLAN.md` from `PLAN_TEMPLATE.md`.
3. Use `PLAN_TEMPLATE_FULL.md` only for broad or risky work.
4. Set `Status: DRAFT` first.
5. Fill `Workflow Contract` (every plan):
   - `Route`: the workflow route from `workflow/spec.md`.
   - `Role`: planner, challenger, reviewer, verifier, implementer, reporter,
     or a bounded combination.
   - `Stop condition`: exact condition that ends the current workflow.
   - `Required evidence`: command, artifact, source, or manual check needed
     before completion.
6. Critique the contract, assumptions, risks and project spec. Name the input
   domain, bounds, and valid/invalid neighbors of each behavior changed. For each material
   requirement, compare its source with observed code/tests; identify missing
   actors/permissions, preconditions, nominal/error/recovery flows, boundary
   states, persistence, dependencies, and observable success as applicable.
   Classify every material gap as in-scope correction, verifiable assumption,
   bounded experiment, blocking question, or justified non-goal. Keep this
   trace in `PLAN.md`; do not create a second active artifact.
7. Do not mark `READY` if route, role, stop condition, required evidence,
   checks, or a disposition for any material spec/code gap is missing for
   implementation-bound work. Name the smallest executable
   end-to-end slice and verify its environment and validation surface are
   available before depending on them.
8. Reconcile criteria, Decision Log and approach; set `CHALLENGED` or `READY`.
9. Ask only narrow blocking questions.
10. Return final status, blockers, and next action.

## READY Gate

A plan is `READY` only with: a clear goal; bounded scope and non-goals when
needed; concrete steps; named files or areas for risky changes; checks to run;
route, role, stop condition and required evidence; known
risks or an explicit "none"; facts separated from assumptions when the task
depends on uncertain context; a populated requirement trace with a disposition
for every material spec/code gap; no blocking open question. `workflow/spec.md`
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
