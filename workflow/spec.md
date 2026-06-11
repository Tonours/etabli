# Workflow Spec

Canonical workflow contract for `etabli`.

## Flow

```text
learn -> plan -> implement -> review -> validate
```

## Statuses

`PLAN.md` uses one status:

- `DRAFT`: plan exists, not implementation-ready.
- `CHALLENGED`: review found blockers or vague scope/checks.
- `READY`: scope, steps, checks, and risks are clear enough to execute.

Only `READY` authorizes implementation.

## Rules

- Read code directly before planning or editing.
- Keep one execution artifact: `PLAN.md`.
- Do not create `REVIEW.md` or secondary mandatory planning docs.
- For small safe tasks, use the simple `PLAN_TEMPLATE.md` shape.
- For broad/risky work, use `PLAN_TEMPLATE_FULL.md`.
- Keep observed facts separate from assumptions in plans.
- Record exact validation commands and results before claiming completion.
- Planning review updates `PLAN.md` in place.
- Implementation follows plan steps in order.
- If new facts invalidate the plan, update it before continuing.
- Review checks correctness, regressions, safety, validation, and plan drift.
- Prefer focused checks over full-suite ritual.

## Minimal READY gate

A plan is `READY` when it has:

- clear goal
- bounded scope and non-goals when needed
- concrete steps
- named files/areas for risky changes
- checks to run
- known risks or explicit "none"
- facts separated from assumptions when the task depends on uncertain context
- no blocking open questions

## Runtime surfaces

Pi and Claude wrappers are thin runtime adapters over this contract.

- Pi skills: `pi/skills/`
- Claude commands: `claude/commands/`
- Plan templates: `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md`
- Project context: `docs/project-context.md` in harnessed projects
- Agent memory: `docs/agent-memory/` in harnessed projects (`workflow/memory.md`)
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`

## Default commands

Pi:

- `/skill:plan-loop <task>`: create/review `PLAN.md`, stop at `READY` or `CHALLENGED`
- `/skill:plan-implement <task>`: plan, then implement if `READY`
- `/skill:implement`: implement existing `READY` plan
- `/skill:review`: review current diff

Claude:

- `/plan`: create `PLAN.md` only, stop at `DRAFT`
- `/plan-loop`: create/review `PLAN.md`, stop at `READY` or `CHALLENGED`
- `/plan-implement`: plan, then implement if `READY`
- `/implement`: implement existing `READY` plan
- `/review`: review current diff

## Daily loop

1. inspect repo state
2. read relevant files
3. create or refresh `PLAN.md`
4. review plan to `READY` or `CHALLENGED`
5. implement small steps
6. run focused checks
7. review diff
8. commit once verified
