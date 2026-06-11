# Parallel dispatch guide

When dispatching AdonisJS skills as concurrent subagents, use this matrix to decide which pairs can run safely in parallel.

## Labels

- **parallel-safe** — can run at the same time without conflict.
- **sequential** — one must finish before the other starts.

## Concurrency matrix

| Pair | Label | Condition |
|------|-------|-----------|
| architecture + backend | sequential | architecture first |
| architecture + tuyau | sequential | architecture first |
| architecture + testing | sequential | architecture first |
| architecture + review | sequential | review judges what architecture recommends |
| backend + tuyau | parallel-safe | different features only |
| backend + testing | sequential | testing after implementation |
| backend + review | sequential | review after implementation |
| tuyau + testing | sequential | testing after contracts |
| tuyau + review | sequential | review after contracts |
| review + testing | sequential | review first |

Any skill dispatched solo is always safe.

## Write targets per skill

Use this to verify that parallel agents will not modify the same project files.

| Skill | Typical write targets |
|-------|----------------------|
| architecture | none (advisory only, may produce a decision record) |
| backend | routes, controllers, validators, models, migrations, services, providers, config |
| tuyau | routes, controllers, validators, response types |
| testing | test files, test helpers, factories |
| review | none (advisory only, produces verdict) |

## When backend + tuyau can run in parallel

Only when working on **different features**. Example:

- Agent A runs `backend` on the `/users` endpoint
- Agent B runs `tuyau` on the `/invoices` endpoint

If both agents touch the **same route, controller, or validator**, dispatch them sequentially — backend first, then tuyau.

## Merge strategy for parallel results

When two agents complete in parallel:

1. Check for file conflicts (same file modified by both agents).
2. If no conflicts, merge both outputs.
3. If conflicts exist, prefer the agent whose skill owns the primary concern for that file, then reconcile manually.

## Default workflow (sequential)

For a single feature flowing through the full suite:

```
architecture → backend or tuyau → testing → review
```

Parallel dispatch is most valuable when working on **multiple independent features** simultaneously.
