---
description: Create PLAN.md from PLAN_TEMPLATE.md with Status DRAFT
argument-hint: <task description>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan

User request: $ARGUMENTS

Follow `workflow/spec.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `PLAN_TEMPLATE.md`
   - `PLAN_TEMPLATE_FULL.md`
2. If one of those files is missing in the current workspace, fall back to the Claude shared copies when this command is loaded through `~/.claude/commands`:
   - `../workflow/spec.md`
   - `../PLAN_TEMPLATE.md`
   - `../PLAN_TEMPLATE_FULL.md`
3. If those are unavailable, fall back to the Etabli repo copies when this command is loaded from the repo target path:
   - `../../workflow/spec.md`
   - `../../PLAN_TEMPLATE.md`
   - `../../PLAN_TEMPLATE_FULL.md`
4. If any fallback files exist, read them and continue. Do not tell the user the template/spec is missing.
5. If all workspace and fallback copies are missing, create `PLAN.md` from the template shape embedded in this command and report the missing source paths as a warning, not as a blocker.

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

1. Inspect repo state and relevant files.
2. Create or refresh `PLAN.md` from `PLAN_TEMPLATE.md`.
3. Use `PLAN_TEMPLATE_FULL.md` only for broad/risky work.
4. Set `Status: DRAFT`.
5. Fill goal, workflow contract, scope, steps, checks, risks, and open questions.
6. For non-trivial plans, fill `Workflow Contract`:
   - `Route`: selected workflow route from `workflow/spec.md`.
   - `Role`: planner, challenger, reviewer, verifier, implementer, reporter, or a bounded combination.
   - `Stop condition`: exact condition that ends the current workflow.
   - `Required evidence`: command, artifact, source, or manual check needed before completion.
7. Ask only narrow blocking questions.
8. Stop without implementation.

Do not create or update `docs/plan/` archives during planning.
