---
name: tanstack-start-database
description: Integrate a database into TanStack Start through server functions and server routes without violating execution boundaries or leaking secrets.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Database

Use this skill when wiring a database into a TanStack Start application.

## When to use
Use this skill when:
- a TanStack Start app needs a database integration strategy
- you want to place DB work on the correct side of the server/client boundary
- you need framework-level guidance before picking ORM-specific details

## When not to use
Do not use this skill as the main guide when:
- Prisma or Drizzle is already chosen and you want tool-specific patterns
- the task is only about auth or route-tree design

## Canonical rule
TanStack Start is database-agnostic.
The framework does **not** prescribe the database layer.

Official TanStack Start database docs are currently high-level.
They confirm the framework works with many database providers and that DB access should happen through server functions or server routes.
The ORM/provider-specific structure in this skill is therefore a **recommended convention**, not official TanStack Start doctrine.

## Hard rule
Database access belongs in:
- server functions
- server routes

Not in:
- client components
- route loaders used as if they were secure boundaries
- generic isomorphic utilities that may land in client bundles

Because route loaders are isomorphic, they may call server functions for DB reads, but they are not themselves the secure DB boundary.

## Good provider choices
Official docs say TanStack Start works with many suitable providers.
They explicitly mention vetted partners such as:
- Neon
- Convex

They also mention Prisma Postgres.

Use this skill's provider/ORM structure as architecture guidance, not as a claim that TanStack officially blesses one exact ORM shape.

## Selection heuristic

### Choose Postgres-style SQL when
- you want relational data
- joins and migrations matter
- the product model is structured and durable

### Choose something more specialized when
- real-time sync is dominant
- the product model fits the provider’s strengths
- you are deliberately accepting tighter coupling for speed

## Recommended layering

### 1. Keep DB client creation server-only
Put DB setup in `*.server.ts` or equivalent server-only modules.

### 2. Expose reads/mutations through server functions
The route layer should call typed server functions, not the DB directly.

### 3. Keep loaders orchestration-only
A loader may call `getSkills()`.
It should not construct DB clients with secrets directly.

## Read pattern

```tsx
// skills.server.ts
export async function listSkills() {
  return db.query.skills.findMany()
}
```

```tsx
// skills.functions.ts
import { createServerFn } from '@tanstack/react-start'
import { listSkills } from './skills.server'

export const getSkills = createServerFn({ method: 'GET' }).handler(async () => {
  return listSkills()
})
```

```tsx
// route file
export const Route = createFileRoute('/skills')({
  loader: () => getSkills(),
  component: SkillsPage,
})
```

## Mutation pattern
- validate input first
- perform DB write in server function/server-only helper
- return a result shaped for the UI
- then invalidate the cache layer that owns the displayed data:
  - route loader / Router cache owns it → `router.invalidate()`
  - TanStack Query owns it → `queryClient.invalidateQueries({ queryKey })`
  - if post-submit UX depends on fresh loader data before continuing → `await router.invalidate({ sync: true })`

## Security rules
1. connection strings stay in server env vars
2. no DB credentials in `VITE_*`
3. resource ownership/permissions must be checked server-side
4. do not trust route access alone for write permissions

## Safe defaults
- start with a simple schema
- keep DB logic boring and explicit
- centralize connection setup
- avoid scattering raw queries through route files
- prefer typed access patterns where practical

## Anti-patterns

### Anti-pattern 1
Reading `process.env.DATABASE_URL` in client-safe code.

### Anti-pattern 2
Calling the DB directly inside route components.

### Anti-pattern 3
Using loaders as the security boundary for DB access.

### Anti-pattern 4
Mixing schema definitions, network boundaries, and UI logic in the same file.

## Definition of done
Database integration is in good shape when:
- DB access is clearly server-only
- reads and writes pass through explicit server boundaries
- env vars are safe
- permissions are enforced server-side
- the route/UI layers stay thin and predictable
