---
name: tanstack-start-server-functions
description: Use TanStack Start loaders, server functions, and server routes correctly without leaking secrets or mixing execution boundaries.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Server Functions

Use this skill when implementing data loading, mutations, backend access, or any code that crosses the server/client boundary.

## When to use
Use this skill when:
- a route needs data that crosses the server/client boundary
- secrets, DB access, or mutations are involved
- you need to choose between loader, server function, and server route
- a component needs to call server logic through `useServerFn()`
- you need progressive enhancement, request headers, redirects, or typed server responses

## When not to use
Do not use this skill as the main guide when:
- the task is purely client-side UI logic
- you are already deep inside ORM-specific or provider-specific details
- the task is only about TanStack Query cache design; use `tanstack-query` first, then return here for Start boundaries

## Canonical rule

**TanStack Start route loaders are isomorphic, not server-only.**

They run:
- on the server during the initial SSR request
- on the client during later navigations

Therefore:
- do not put secrets in loaders
- do not use loaders as your security boundary
- do not access DB/filesystem directly inside loaders unless you are certain the code is safe for both bundles

## Correct primitive selection

### Use a route loader when
- a route needs data to render
- you are orchestrating route-scoped data dependencies
- you can call a server function for sensitive work

### Use a server function when
- you need DB access
- you need secrets from `process.env`
- you need filesystem/server-only APIs
- you are doing a secure mutation
- you want a typed RPC-style backend surface
- you want a function callable from loaders, hooks, components, event handlers, or another server function

### Use a server route when
- you need a raw HTTP endpoint
- you need to return a `Response`
- you are building webhooks, XML, text, file/binary, robots, sitemap, etc.

## Recommended file organization

```text
src/utils/
├── skills.functions.ts
├── skills.server.ts
└── schemas.ts
```

### Meanings
- `*.functions.ts` → exported `createServerFn` wrappers
- `*.server.ts` → internal server-only helpers
- `*.ts` → shared client-safe code like Zod schemas/types/constants

TanStack Start import protection makes this convention enforceable:
- `*.server.*` files are denied in the client environment by default
- `*.client.*` files are denied in the server environment by default
- `@tanstack/react-start/server` is denied in the client environment by default
- `import '@tanstack/react-start/server-only'` and `import '@tanstack/react-start/client-only'` can mark files explicitly when naming is not enough

Type-only imports may cross boundaries when they stay type-only. Mixed imports that include runtime values still count as runtime imports.

## Read pattern

### Good pattern

```tsx
import { createFileRoute } from '@tanstack/react-router'
import { getSkills } from '~/utils/skills.functions'

export const Route = createFileRoute('/skills')({
  loader: async () => getSkills(),
  component: SkillsPage,
})
```

```tsx
import { createServerFn } from '@tanstack/react-start'
import { listSkills } from './skills.server'

export const getSkills = createServerFn({ method: 'GET' }).handler(async () => {
  return listSkills()
})
```

### Component call pattern

When calling a server function from a component, wrap it with `useServerFn()` so the component uses the React-aware call surface.

```tsx
import { useServerFn } from '@tanstack/react-start'
import { useQuery } from '@tanstack/react-query'
import { getSkills } from '~/utils/skills.functions'

function SkillsList() {
  const getSkillsFn = useServerFn(getSkills)

  const skillsQuery = useQuery({
    queryKey: ['skills'],
    queryFn: () => getSkillsFn(),
  })

  return <SkillsTable skills={skillsQuery.data ?? []} />
}
```

Call server functions directly from loaders and other server functions. Use `useServerFn()` from React components and hooks.

## Mutation pattern

```tsx
import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'
import { createSkillInDb } from './skills.server'

const CreateSkillInput = z.object({
  title: z.string().min(1),
  description: z.string().min(1),
})

export const createSkill = createServerFn({ method: 'POST' })
  .validator(CreateSkillInput)
  .handler(async ({ data }) => {
    return createSkillInDb(data)
  })
```

Server functions accept one `data` payload. Call validated functions with the Start call shape:

```ts
await createSkill({
  data: {
    title: 'TanStack Query',
    description: 'Server-state cache discipline',
  },
})
```

## Route invalidation pattern
After a successful mutation, invalidate the cache layer that actually owns the displayed data.

- route loader / Router cache owns the data → `router.invalidate()`
- component reads from TanStack Query cache → `queryClient.invalidateQueries({ queryKey })`
- if the next step depends on fresh loader data before continuing → `await router.invalidate({ sync: true })`

Do not assume the UI will refresh itself.

## Headers / request access
If you need request or response details inside a server function, use the server utilities from Start rather than inventing your own ad hoc global state.

Officially useful primitives include request/response helpers such as:
- `getRequest()`
- `getRequestHeader()` / `getRequestHeaders()`
- `getRequestHost()` / `getRequestIP()` / `getRequestProtocol()` / `getRequestUrl()` when host/IP/URL context matters
- `setResponseHeader()` / `setResponseHeaders()`
- `setResponseStatus()`

Do not set shared public cache headers for responses that depend on cookies, sessions, auth headers, users, teams, or tenants. Use private/no-store semantics for identity-bound data.

## Security and strict configuration
- Start protects server functions against CSRF with a default `createCsrfMiddleware()` registered automatically when there is no custom `src/start.ts`. If you provide your own `src/start.ts`, keep CSRF protection on the request middleware stack.
- `createServerFn({ strict: false })` (or `{ strict: { input: false } }`) disables strict serialization checks. Leave `strict` on unless you have a measured reason; it catches payloads that would not survive the network boundary.
- A custom fetch (`serverFns: { fetch }` in `createStart`, or `next({ fetch })` from a client middleware) routes server-function calls through a CDN or proxy. Use it deliberately, not by default.

## Error, redirect, and not-found handling
Server functions may throw:
- normal errors for failed operations
- `redirect(...)` for auth or post-action navigation
- `notFound()` for missing resources

Keep the thrown value intentional and avoid leaking private implementation details in error messages serialized back to the client.

## Progressive enhancement and advanced primitives
TanStack Start server functions also support advanced patterns. Use them deliberately:

- `.url` for HTML form progressive enhancement when the flow must work without JavaScript
- streamed typed data when the payload benefits from progressive delivery
- raw `Response` values or binary/custom content only when a server route is not the clearer HTTP surface
- static server functions for build-time cached results
- server components returned from server functions only when the route/component architecture is designed for that model
- request cancellation with `AbortSignal` for long-running work
- custom `generateFunctionId` only when production function IDs need deterministic control

If the requirement is just a normal app read or mutation, keep the server function boring.

## Safe defaults
- keep loaders orchestration-only
- prefer small server functions with explicit validation
- keep request/response manipulation inside server-side primitives
- avoid dynamic imports for server functions
- prefer `.validator(...)` over ad hoc handler validation for input crossing the network boundary
- use `.validator(...)` for `createServerFn(...)` input crossing the network boundary; current TanStack Start function middleware also uses `.validator(...)`, so do not use `.inputValidator(...)` in new Start code
- enforce auth on the server function itself; route guards do not protect the RPC endpoint

## Safety rules
1. Secrets live in server functions or server routes.
2. Validation happens before mutation logic.
3. Keep server-only helpers in `*.server.ts`.
4. Static imports of server functions are safe; avoid dynamic imports for server functions.
5. Favor small, composable server functions.
6. Server functions can be called from loaders, components, hooks, event handlers, or other server functions.
7. If a route loader needs auth- or session-based data, keep the loader orchestration-only and call a server function that re-validates access.
8. A protected route is UX gating, not server function authorization.
9. Do not read secrets from `process.env` at module scope in isomorphic files. Edge/Worker SSR injects env per request; module-level reads can be `undefined` on the server and may leak into client bundles. Read env inside handlers, middleware `.server()`, or server-only helpers.

## Anti-patterns

### Anti-pattern 1
Using a loader as if it were guaranteed server-only.

### Anti-pattern 2
Putting `process.env.SECRET` directly in code that may land in an isomorphic path.

### Anti-pattern 3
Making the route component call a DB client directly.

### Anti-pattern 4
Using a server route when a typed server function is the cleaner internal interface.

### Anti-pattern 5
Returning unvalidated user data straight into the server mutation layer.

### Anti-pattern 6
Putting auth only in `beforeLoad` and leaving the server function callable without the same server-side permission check.

### Anti-pattern 7
Using a server function for a webhook, binary download, XML document, or integration endpoint where a server route is the clearer contract.

## Quick decision table
- page data for route → loader calling server function
- secure mutation → server function `POST`
- webhook / XML / raw response → server route
- browser-only logic → client-only primitive
- component-owned Query data → `useServerFn()` plus TanStack Query
- no-JS form flow → server function `.url` or a server route, depending on HTTP needs

## Definition of done
A change is correctly implemented when:
- sensitive work is server-only
- route loaders stay orchestration-focused
- mutation inputs are validated
- file organization makes bundle boundaries obvious
- no secrets leak to client-safe code
- route guards are backed by server function auth/ownership checks
- component calls use the appropriate server function call surface
- cache invalidation is explicit after writes
