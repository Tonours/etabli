---
description: Create/review PLAN.md and stop at CHALLENGED or READY
argument-hint: <task description>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Skill]
---

# Plan Loop

User request: $ARGUMENTS

Follow `workflow/spec.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order.
Try each path with a direct read; do not stop at the first miss.

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `PLAN_TEMPLATE.md`
   - `PLAN_TEMPLATE_FULL.md`
2. Prefer absolute installed home copies (stable when command paths are realpath'd):
   - `~/.claude/PLAN_TEMPLATE.md`, `~/.claude/PLAN_TEMPLATE_FULL.md`, `~/.claude/workflow/spec.md`
   - `~/.pi/agent/PLAN_TEMPLATE.md`, `~/.pi/agent/PLAN_TEMPLATE_FULL.md`, `~/.pi/agent/workflow/spec.md`
   - `~/.agents/PLAN_TEMPLATE.md`, `~/.agents/PLAN_TEMPLATE_FULL.md`, `~/.agents/workflow/spec.md`
3. Relative install-surface fallbacks (logical path only; do not realpath the command dir first):
   - From `~/.claude/commands`: `../PLAN_TEMPLATE.md`, `../PLAN_TEMPLATE_FULL.md`, `../workflow/spec.md`
4. Relative Etabli-repo fallbacks after realpath into `claude/commands/`:
   - `../../PLAN_TEMPLATE.md`, `../../PLAN_TEMPLATE_FULL.md`, `../../workflow/spec.md`
5. If any fallback file exists, read it and continue. Do not tell the user the template/spec is missing.
6. If all workspace and fallback copies are missing, create `PLAN.md` from the template shape embedded in this command and report the missing source paths as a warning, not as a blocker.

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

1. Inspect repo state and relevant files. Skill selection comes first: invoke
   `suite-router` to detect domain(s), then the matching suite(s) —
   `design-suite` (UI/UX, brand, responsive, dark mode, ui.sh),
   `stack-suite` (Node/TS/React/web UI), `forest-backend-suite` (BFF, auth,
   permissions, MCP, capabilities, Zendesk, workflow executor/orchestrator),
   `ember-forestadmin-suite` (Ember frontend), or a task-shaped one such as
   `bug-check`. It points at what is already known, so the plan starts from
   evidence instead of rediscovery. Name the skill(s) used, or `none`, in
   `Notes / Handoff`.
2. Create or refresh `PLAN.md` from `PLAN_TEMPLATE.md`.
3. Use `PLAN_TEMPLATE_FULL.md` only for broad/risky work.
4. Set `Status: DRAFT` first.
5. Fill `Workflow Contract` for non-trivial plans:
   - `Route`: selected workflow route from `workflow/spec.md`.
   - `Role`: planner, challenger, reviewer, verifier, implementer, reporter, or a bounded combination.
   - `Stop condition`: exact condition that ends the current workflow.
   - `Required evidence`: command, artifact, source, or manual check needed before completion.
6. Critique scope, route, role, stop condition, evidence, steps, checks, assumptions, and risks.
7. Do not mark `READY` if route, stop condition, required evidence, or checks are missing for non-trivial implementation-bound work.
8. Update `PLAN.md` in place to `CHALLENGED` or `READY`.
9. Ask only narrow blocking questions.
10. Return final status, blockers if any, and next action.

Rules:
- Do not implement.
- Do not create `REVIEW.md`.
- Do not create or update `docs/plan/` archives during planning.
- Do not ask whether to implement next.
- If the user asked for autonomous plan-loop completion, this command is only
  the planning phase; the route must be `/plan-implement`, which continues
  after the actual root `PLAN.md` is `READY`.
