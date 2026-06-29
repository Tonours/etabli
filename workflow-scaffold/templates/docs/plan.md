# Implemented Plan Archives

Implemented plans live here after they have been completed and validated.

Use one Markdown file per implemented plan, named:

```text
YYYYMMDD-short-slug.md
```

Do not archive drafts, challenged plans, or abandoned ready plans. Do not archive during planning. `PLAN.md` remains the active execution artifact while work is in progress.

Each archive is a distilled memory record, not a raw copy of `PLAN.md`.

Use this shape:

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

Keep archives short. Preserve why choices were made, what changed, what was rejected, how it was validated, and what remains true for future work.
