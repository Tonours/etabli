<!--
Implemented-plan archive skeleton. Convention: workflow/plan-archive.md.
scripts/plan-cleanup --archive enforces the `# Implemented:` title, the
`- Source plan: \`PLAN.md\`` line, `- Status: IMPLEMENTED`, and a
`- Source plan SHA-256:` line equal to `shasum -a 256 PLAN.md` at archive time.
One owner repo holds root PLAN.md and the single archive; satellites never
hold either. Distill: outcome, facts that mattered, decisions, accepted drift,
validation evidence, follow-up. Omit planning scaffolding and progress logs.
-->
# Implemented: <outcome>

## Metadata
- Archived: YYYY-MM-DD
- Source plan: `PLAN.md` — <subject>
- Source plan SHA-256: `<sha256 of the exact root PLAN.md bytes>`
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
