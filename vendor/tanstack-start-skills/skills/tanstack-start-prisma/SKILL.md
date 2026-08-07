---
name: tanstack-start-prisma
description: Use Prisma with TanStack Start through explicit server boundaries, predictable schema ownership, and safe route integration.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Prisma

Use this skill when integrating **Prisma** into a TanStack Start app.

## Goal
Use Prisma in a way that stays aligned with TanStack Start's execution model:
- Prisma client stays server-only
- route loaders remain orchestration-only
- reads and writes go through explicit server boundaries
- auth and ownership checks happen on the server

## When to use
Use Prisma when:
- you want a mature TypeScript ORM for SQL databases
- you want schema-based modeling and generated types
- you want clear migrations and relational modeling
- your app benefits from a central data model and explicit services

## When not to use
Do **not** reach for Prisma by default when:
- you specifically want SQL-query-builder ergonomics over ORM modeling
- you want lower-level SQL composition and closer control of generated queries
- your team already standardized on Drizzle and you gain no value from Prisma's generated client

## Canonical rule
**Route loaders are isomorphic, not server-only.**

Therefore:
- do not instantiate Prisma in route files
- do not put Prisma calls directly in loaders
- do not treat a loader as the secure data boundary

Instead:
- loader = route data orchestration
- server function = application boundary
- `*.server.ts` = internal Prisma/data access implementation

## Hard rules
1. Prisma client creation belongs in a server-only module.
2. Prisma access should happen inside server functions or helpers called by server functions.
3. Secrets such as `DATABASE_URL` must never appear under a public env prefix (`VITE_*` or `PUBLIC_*`).
4. Auth and resource ownership checks must happen server-side before returning sensitive data or applying writes.
5. Route files should depend on typed server functions, not on Prisma directly.

## Recommended file organization

```text
src/
├── db/
│   ├── client.server.ts
│   └── schema-notes.md
├── features/
│   └── projects/
│       ├── projects.server.ts
│       ├── projects.functions.ts
│       └── projects.schemas.ts
├── routes/
│   └── app/
│       └── projects/
│           ├── index.tsx
│           └── $projectId.tsx
prisma/
├── schema.prisma
└── migrations/
```

This file layout is a pragmatic repo convention, not an official TanStack Start requirement.

### Meaning
- `db/client.server.ts` → Prisma client singleton, server-only
- `*.server.ts` → internal business/data access helpers
- `*.functions.ts` → `createServerFn()` wrappers used by routes/components
- `*.schemas.ts` → shared Zod/input types safe for client+server import
- `prisma/schema.prisma` → Prisma schema and datasource config

## Baseline setup shape

### Server-only Prisma client
```ts
// src/db/client.server.ts
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as {
  prisma?: PrismaClient
}

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: ['warn', 'error'],
  })

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma
}
```

Why:
- avoids hot-reload client explosion in dev
- keeps Prisma creation in a server-only file

## Read pattern

```ts
// src/features/projects/projects.server.ts
import { prisma } from '~/db/client.server'

export async function listProjectsForUser(userId: string) {
  return prisma.project.findMany({
    where: { ownerId: userId },
    orderBy: { createdAt: 'desc' },
  })
}
```

```ts
// src/features/projects/projects.functions.ts
import { createServerFn } from '@tanstack/react-start'
import { requireUser } from '~/features/auth/session.server'
import { listProjectsForUser } from './projects.server'

export const getProjects = createServerFn({ method: 'GET' }).handler(async () => {
  const user = await requireUser()
  return listProjectsForUser(user.id)
})
```

```tsx
// src/routes/app/projects/index.tsx
import { createFileRoute } from '@tanstack/react-router'
import { getProjects } from '~/features/projects/projects.functions'

export const Route = createFileRoute('/app/projects/')({
  loader: () => getProjects(),
  component: ProjectsPage,
})
```

## Mutation pattern

```ts
// src/features/projects/projects.schemas.ts
import { z } from 'zod'

export const CreateProjectInput = z.object({
  name: z.string().min(1).max(120),
})
```

```ts
// src/features/projects/projects.functions.ts
import { createServerFn } from '@tanstack/react-start'
import { requireUser } from '~/features/auth/session.server'
import { CreateProjectInput } from './projects.schemas'
import { createProjectForUser } from './projects.server'

export const createProject = createServerFn({ method: 'POST' })
  .validator(CreateProjectInput)
  .handler(async ({ data }) => {
    const user = await requireUser()
    return createProjectForUser(user.id, data)
  })
```

### Mutation rules
- validate input before touching Prisma
- re-check auth/ownership server-side
- return UI-ready data, not raw hidden internals
- explicitly invalidate the owning cache after successful writes:
  - route loader / Router cache owns the data → `router.invalidate()`
  - TanStack Query owns it → `queryClient.invalidateQueries({ queryKey })`
  - if navigation should wait for fresh loader data → `await router.invalidate({ sync: true })`

## Migrations and schema ownership
Prisma becomes much easier to manage when schema ownership is boring and explicit.

### Recommended baseline
- Prisma schema is the canonical application schema artifact
- migrations are committed to git
- app code does not silently depend on untracked local schema changes
- production deploys run migrations deliberately, not as accidental side effects

### Good commands to remember
```bash
npx prisma migrate dev
npx prisma generate
npx prisma studio
npx prisma migrate deploy
```

## Safe defaults
- start with one shared Prisma client
- keep feature-level data access in feature-local `*.server.ts` files
- prefer explicit `select`/`include` when payload shape matters
- keep transactions close to the business operation they protect
- log warnings/errors, not noisy query logs by default in production

## Auth and ownership pattern
Prisma does **not** replace authorization.

Always ask:
- who is the actor?
- what resource are they touching?
- what server-side check proves access?

Good example:
- resolve current user in a server function
- fetch only rows owned by that user or permitted by role
- reject unauthorized access before mutation

Bad example:
- load `projectId` from the URL and trust that route membership alone grants access

## Anti-patterns

### Anti-pattern 1
Importing `PrismaClient` directly into route files or components.

### Anti-pattern 2
Creating a new Prisma client inside every server function call.

### Anti-pattern 3
Calling Prisma from a loader as if the loader were guaranteed server-only.

### Anti-pattern 4
Mixing validation, auth, Prisma access, and UI rendering in one file.

### Anti-pattern 5
Returning giant unshaped records when the UI only needs a small stable payload.

### Anti-pattern 6
Treating Prisma schema changes as local experiments instead of versioned app changes.

## Definition of done
Prisma integration is in good shape when:
- Prisma client lives in a server-only module
- route loaders only orchestrate data fetching
- reads and writes go through explicit server functions
- schema and migrations are committed and reproducible
- auth and ownership checks happen server-side
- route/UI files stay thin and readable
