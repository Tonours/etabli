# Agent Memory

Canonical convention for durable agent lessons in projects using the workflow scaffold.

## Location

Use `docs/agent-memory/`. Store one lesson per Markdown file, named in kebab-case. Start each file with a one-line summary.

## What to Record

- Corrections that should change future behavior, with the reason.
- Confirmed approaches that are likely to matter again, with the evidence.
- Project-specific caveats that are not already captured in code, tests, or source-of-truth docs.

Do not duplicate `PLAN.md`, `docs/project-context.md`, README content, or transient run logs.

## Maintenance

- Read `docs/project-context.md`, then `docs/agent-memory/`, before non-trivial work.
- Update an existing lesson instead of creating a near-duplicate.
- Delete or rewrite lessons that become invalid.

## Bootstrap

Use this prompt when adding memory to an existing project using the workflow scaffold:

```text
Reflect on past sessions/handoffs in docs/agent-runs/, extract durable lessons into docs/agent-memory/, one per file.
```
