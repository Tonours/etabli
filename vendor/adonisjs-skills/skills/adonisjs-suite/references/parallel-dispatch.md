# Coordination and parallel analysis guide

Use this guide when several AdonisJS specialists or subagents contribute to one task. Parallelism is for independent read-only evidence gathering. Writes to a shared worktree stay sequential under one explicit owner.

## Labels

- **parallel-read-only** — may inspect independent evidence at the same time and return findings without editing.
- **sequential** — a decision or write from the first phase feeds the next phase.

## Concurrency matrix

| Pair | Label | Condition |
|------|-------|-----------|
| architecture + backend | sequential | architecture decision first |
| architecture + Tuyau | sequential | architecture decision first |
| architecture + testing | sequential | test proof follows the chosen design |
| architecture + review | sequential | review judges the implemented design |
| backend + Tuyau | sequential | same-feature routes, validators, and controllers overlap |
| backend + testing | sequential | tests follow the implemented behavior |
| backend + review | sequential | review follows implementation and focused tests |
| Tuyau + testing | sequential | tests follow the final contract |
| Tuyau + review | sequential | review follows the final contract and tests |
| testing + review | sequential | testing first, then review with evidence |

Independent read-only scouts for different modules may use **parallel-read-only**. They must return file/line evidence and may not edit, install, or mutate external state.

## Write targets per skill

Use this to verify that parallel agents will not modify the same project files.

| Skill | Typical write targets |
|-------|----------------------|
| architecture | decision record only when requested |
| backend | routes, controllers, validators, models, migrations, services, providers, config |
| Tuyau | routes, controllers, validators, registry/client integration, response types |
| testing | test files, test helpers, factories |
| review | none (advisory only, produces verdict) |

## Different features

Different features may be analyzed concurrently, but their implementation still needs explicit non-overlapping ownership and sequential writes in a shared worktree. If the runtime provides isolated worktrees, follow that runtime's merge and review contract instead of inventing one here.

## Synthesis after parallel analysis

1. Verify each finding against the current worktree.
2. Resolve disagreements before assigning a writer.
3. Select one owner for the next write.
4. Re-read the resulting diff before the next phase.

## Default workflow (sequential)

For a single feature flowing through the full suite:

```
architecture → backend or tuyau → testing → review
```

This order is the default for one feature. Do not reverse testing and review: the reviewer needs the focused test evidence.
