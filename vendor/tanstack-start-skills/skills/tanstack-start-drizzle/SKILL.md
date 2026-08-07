---
name: tanstack-start-drizzle
description: Use Drizzle with TanStack Start through explicit server boundaries, typed SQL-first patterns, and predictable schema ownership.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Drizzle

Use this skill when integrating **Drizzle** into a TanStack Start app.

## Goal
Use Drizzle in a way that respects TanStack Start's execution model while preserving Drizzle's SQL-first strengths:
- DB client/server adapter stays server-only
- route loaders remain orchestration-only
- reads and writes cross the network through explicit server functions
- schema, queries, and permissions stay understandable as the app grows

## When to use
Use Drizzle when:
- you want a TypeScript-first SQL toolkit with explicit query control
- you prefer composable SQL-ish ergonomics over a classic ORM client
- you want clear ownership of schema, relations, and migrations
- you care about close-to-SQL mental models without giving up types

## When not to use
Do **not** reach for Drizzle by default when:
- your team already standardized on Prisma and values generated-client workflows more
- you want the ORM-style generated API Prisma gives you
- your codebase would be harmed by introducing another DB abstraction style

## Canonical rule
**Route loaders are isomorphic, not server-only.**

Therefore:
- do not instantiate the Drizzle DB client in route files
- do not place SQL access directly in loaders
- do not treat loaders as the secure boundary for database work

Instead:
- loader = route data orchestration
- server function = application boundary
- `*.server.ts` = internal Drizzle/data access implementation

## Hard rules
1. Drizzle DB setup belongs in a server-only module.
2. DB queries and writes belong in server functions or helpers they call.
3. Database secrets must never appear in client-safe env vars.
4. Authorization and resource ownership checks must happen server-side.
5. Shared schema/type modules should stay safe to import, but connection code must remain server-only.

## Recommended file organization

```text
src/
├── db/
│   ├── index.server.ts
│   ├── schema/
│   │   ├── users.ts
│   │   ├── projects.ts
│   │   └── index.ts
│   └── queries/
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
drizzle/
└── meta/
```

This file layout is a pragmatic repo convention, not an official TanStack Start requirement.

### Meaning
- `db/index.server.ts` → DB connection + `drizzle(...)`, server-only
- `db/schema/*` → table definitions and exported inferred types
- `*.server.ts` → business/data access helpers using Drizzle queries
- `*.functions.ts` → `createServerFn()` wrappers used by routes/components
- `*.schemas.ts` → Zod/input validation safe to share
- `drizzle/` → migration artifacts managed by Drizzle Kit

## Baseline setup shape

### Server-only Drizzle client
```ts
// src/db/index.server.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from './schema'

const connectionString = process.env.DATABASE_URL

if (!connectionString) {
  throw new Error('DATABASE_URL is required')
}

const client = postgres(connectionString)

export const db = drizzle(client, { schema })
```

Why:
- keeps connection logic server-only
- centralizes DB setup
- gives feature modules typed access through one shared boundary

## Read pattern

```ts
// src/features/projects/projects.server.ts
import { desc, eq } from 'drizzle-orm'
import { db } from '~/db/index.server'
import { projects } from '~/db/schema/projects'

export async function listProjectsForUser(userId: string) {
  return db
    .select({
      id: projects.id,
      name: projects.name,
      createdAt: projects.createdAt,
    })
    .from(projects)
    .where(eq(projects.ownerId, userId))
    .orderBy(desc(projects.createdAt))
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
// src/features/projects/projects.server.ts
import { db } from '~/db/index.server'
import { projects } from '~/db/schema/projects'

export async function createProjectForUser(userId: string, input: { name: string }) {
  const [project] = await db
    .insert(projects)
    .values({
      ownerId: userId,
      name: input.name,
    })
    .returning({
      id: projects.id,
      name: projects.name,
    })

  return project
}
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

## Query design guidance
Drizzle stays clean when query ownership is explicit.

After successful writes, invalidate the owning cache explicitly:
- route loader / Router cache owns the visible data → `router.invalidate()`
- TanStack Query owns it → `queryClient.invalidateQueries({ queryKey })`
- if navigation should wait for fresh loader data → `await router.invalidate({ sync: true })`

### Prefer
- feature-local query helpers
- explicit `.select(...)` payload shaping
- clear table imports from one schema tree
- transactions around true business units of work

### Avoid
- scattering ad hoc SQL across route files
- returning oversized payloads out of convenience
- hiding authorization assumptions inside generic low-level query utilities

## Migrations and schema ownership
### Recommended baseline
- table definitions live in versioned schema files
- migration artifacts are committed to git
- generated migration output is reviewed, not blindly trusted
- production migrations are run deliberately as deploy steps

### Good commands to remember
```bash
npx drizzle-kit generate
npx drizzle-kit migrate
npx drizzle-kit push
npx drizzle-kit studio
```

## Safe defaults
- keep one server-only DB module
- organize schema by domain once the app grows
- shape payloads explicitly at the query layer
- use inferred types where they improve clarity, not everywhere by reflex
- keep raw SQL escapes rare and justified

## Auth and ownership pattern
Drizzle gives query control, but it does **not** enforce permissions for you.

Always ask:
- who is acting?
- which rows are in scope?
- what server-side condition proves they can read or mutate them?

Good example:
- resolve the current user in a server function
- constrain queries by owner/team/role
- reject unauthorized access before executing destructive writes

Bad example:
- trust a route param and run an update because the page was under `/app`

## Anti-patterns

### Anti-pattern 1
Instantiating the DB client in a route file or component.

### Anti-pattern 2
Calling Drizzle directly from a route loader as if it were a secure server-only boundary.

### Anti-pattern 3
Mixing table definitions, query logic, auth checks, and UI rendering in one file.

### Anti-pattern 4
Building giant generic query helper layers that hide what SQL is actually doing.

### Anti-pattern 5
Using `push`/migration flows casually in production without explicit review.

### Anti-pattern 6
Treating typed queries as a substitute for validation and authorization.

## Definition of done
Drizzle integration is in good shape when:
- connection setup is clearly server-only
- routes depend on server functions, not on DB setup directly
- queries are explicit and readable
- migrations/schema changes are versioned and reviewed
- auth and ownership checks happen server-side
- UI files stay thin and focused on rendering
