---
name: tanstack-start-better-auth
description: Integrate Better Auth with TanStack Start using server routes, cookies, beforeLoad gating, and server-side session enforcement.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Better Auth

Use this skill when integrating **Better Auth** into a TanStack Start app.

## When to use
Use this skill when:
- you chose Better Auth as the provider for a TanStack Start app
- you want first-class cookie/session handling with Better Auth
- protected routes should use `beforeLoad` while server functions enforce real auth boundaries

## When not to use
Do not use this skill as the main guide when:
- you want provider-agnostic auth architecture
- you are integrating a different auth provider
- the task is only about resource ownership after auth is already solved

## Goal
Use Better Auth in a way that matches TanStack Start's execution model:
- auth handler mounted through a server route
- cookies and session handling configured correctly
- route-entry gating handled with `beforeLoad`
- sensitive reads/writes enforced in server functions

## Scope
This is a **provider-specific** skill.
For auth architecture that is provider-agnostic, use `tanstack-start-auth`.

## Canonical rule
**Route loaders are isomorphic, not server-only.**

Therefore:
- do not treat loaders as the secure auth boundary
- use `beforeLoad` for route-entry gating UX
- use server functions and server routes for actual session/auth enforcement

## Better Auth + TanStack Start core pattern
Official Better Auth TanStack integration centers on:
1. a Better Auth server instance
2. a TanStack Start server route for the auth handler
3. `tanstackStartCookies()` in the Better Auth plugin list
4. a small server function for reading the current session with request headers
5. `beforeLoad` on protected routes/layouts for redirect-based gating

## Hard rules
1. Mount Better Auth through a TanStack Start route such as `/src/routes/api/auth/$.ts` using route `server.handlers`.
2. Keep `tanstackStartCookies()` **last** in the Better Auth plugin list.
3. Keep auth secrets server-only.
4. Use Better Auth client helpers / `authClient` for browser-side sign-in/sign-up flows.
5. Re-check session and authorization inside server functions for sensitive operations.

## Recommended file organization

```text
src/
├── lib/
│   ├── auth.server.ts
│   └── auth-client.ts
├── features/
│   └── auth/
│       ├── session.functions.ts
│       └── session.server.ts
├── routes/
│   ├── api/
│   │   └── auth/
│   │       └── $.ts
│   ├── login.tsx
│   ├── _protected.tsx
│   └── _protected/
│       ├── dashboard.tsx
│       └── settings.tsx
```

### Meaning
- `auth.server.ts` → Better Auth server instance
- `auth-client.ts` → Better Auth client/browser helpers
- `session.functions.ts` → `createServerFn()` wrappers for session reads
- `routes/api/auth/$.ts` → Better Auth handler route
- `_protected.tsx` → protected layout route with `beforeLoad`

## Baseline setup shape

### Better Auth server instance
```ts
// src/lib/auth.server.ts
import { betterAuth } from 'better-auth'
import { tanstackStartCookies } from 'better-auth/tanstack-start'

export const auth = betterAuth({
  // ...providers, database, email, etc.
  plugins: [
    // other plugins first
    tanstackStartCookies(),
  ],
})
```

### Auth handler route
```ts
// src/routes/api/auth/$.ts
import { createFileRoute } from '@tanstack/react-router'
import { auth } from '~/lib/auth.server'

export const Route = createFileRoute('/api/auth/$')({
  server: {
    handlers: {
      GET: ({ request }) => auth.handler(request),
      POST: ({ request }) => auth.handler(request),
    },
  },
})
```

### Session reader server function
```ts
// src/features/auth/session.functions.ts
import { createServerFn } from '@tanstack/react-start'
import { getRequestHeaders } from '@tanstack/react-start/server'
import { auth } from '~/lib/auth.server'

export const getSession = createServerFn({ method: 'GET' }).handler(async () => {
  const headers = getRequestHeaders()
  return auth.api.getSession({ headers })
})
```

### Protected route gating with `beforeLoad`
```ts
// src/routes/_protected.tsx
import { createFileRoute, redirect } from '@tanstack/react-router'
import { getSession } from '~/features/auth/session.functions'

export const Route = createFileRoute('/_protected')({
  beforeLoad: async () => {
    const session = await getSession()

    if (!session) {
      throw redirect({ to: '/login' })
    }

    return { session }
  },
  component: ProtectedLayout,
})
```

## Client-side auth flows
For sign-in/sign-up/sign-out, prefer Better Auth's client helpers rather than inventing ad hoc fetch calls.

Typical pattern:
- form submits in client component
- call Better Auth client SDK
- redirect or invalidate route/query state after success

## Middleware guidance
If many server functions require the same auth/session resolution, use TanStack Start **server function middleware** to:
- resolve session once
- fail fast when session is required
- pass auth context into handlers

## Safe defaults
- use pathless or clearly named protected layout routes
- keep session fetch logic small and reusable
- keep Better Auth config centralized
- use server functions for app-internal session reads
- keep provider-specific UI logic out of unrelated feature files

## Anti-patterns

### Anti-pattern 1
Using a route loader as if it were the secure auth boundary.

### Anti-pattern 2
Putting Better Auth configuration across many files without one server-owned auth module.

### Anti-pattern 3
Forgetting to keep `tanstackStartCookies()` last in the plugin list.

### Anti-pattern 4
Trusting that protected route membership alone authorizes sensitive data access.

### Anti-pattern 5
Exposing auth secrets or server-only config through client-safe env vars.

## Definition of done
Better Auth integration is in good shape when:
- Better Auth is mounted through a TanStack Start server route
- cookie/session integration is configured correctly
- protected route entry uses `beforeLoad`
- sensitive server functions still enforce auth/ownership server-side
- client auth flows use Better Auth client helpers instead of ad hoc browser logic
