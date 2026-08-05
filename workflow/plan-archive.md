# Implemented Plan Archives

Canonical convention for implemented plan memory.

## Location

Use `docs/plan/`. Store one implemented plan per Markdown file, named:

```text
YYYYMMDD-short-slug.md
```

The singular directory name is intentional.

## When To Archive

Archive a plan if and only if it was implemented and validation ran.

- Do not archive `DRAFT` plans as implemented.
- Do not archive `CHALLENGED` plans as implemented.
- Do not archive abandoned `READY` plans as implemented.
- Do not archive during planning commands.
- Do archive after implementation commands finish the planned work and run focused checks.

`PLAN.md` remains the only execution artifact while work is in progress. Files in `docs/plan/` are post-implementation memory records, not active plans.

## When To Discard (unrelated / abandoned)

If root `PLAN.md` does not match the current user request, do not stay blocked.
Discard it and continue (or write a new plan for the new scope):

```bash
scripts/plan-cleanup --discard <reason-slug>
```

- Allowed from any plan status (`DRAFT`, `CHALLENGED`, `READY`, unknown).
- Writes `docs/plan/YYYYMMDD-discarded-<reason-slug>.md` with `Status: DISCARDED`.
- Removes root `PLAN.md` so ordinary work or a fresh plan can proceed.
- Do **not** use `--discard` after a successful implementation — use `--archive` with a validated implemented record instead.

## Archive Format

Do not raw-copy `PLAN.md` by default. Distill it into a memory-first implementation record:

```md
# Implemented: <outcome>

## Metadata
- Archived: YYYY-MM-DD
- Source plan: <PLAN.md subject>
- Status: IMPLEMENTED
- Commit / branch: <when available>

## Outcome
- ...

## Context
- path/source: fact that mattered

## Decisions
### <decision>
- Context:
- Choice:
- Rejected options:
- Rationale:
- Consequences:

## Accepted Drift
- Original plan/spec:
- Implemented reality:
- Why accepted:

## Validation Evidence
- command:
  - result:

## Follow-up State
- Remaining risks:
- Parking lot:
- Superseded docs/specs:
- Next links:
```

## What To Omit

- unchecked planning scaffolding;
- obsolete assumptions after they are resolved;
- step-by-step progress logs unless they explain a decision;
- rollback notes that no longer matter after validation;
- chat-only context that cannot be verified from repo state or cited sources.

## Relationship To Agent Memory

Use `docs/plan/` for implemented plan history.

Use `docs/agent-memory/` for reusable lessons that should change future agent behavior across tasks.
