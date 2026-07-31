---
name: tanstack-start-auth
description: Add authentication and route protection to TanStack Start using server-driven auth, protected route trees, and server-side permission checks.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Auth

Use this skill when adding sign-in, protected areas, session checks, or permission gating to a TanStack Start app.

## When to use
Use this skill when:
- a TanStack Start app needs sign-in or session-aware UX
- you are splitting public and protected areas
- server functions need auth or permission checks
- you need provider-agnostic auth architecture guidance

## When not to use
Do not use this skill as the main guide when:
- you need provider-specific setup details for Better Auth or Clerk
- you are only working on route-tree structure without broader auth concerns
- you need resource-level authorization details more than auth architecture

## Canonical rule

Prefer:
- server-driven auth state
- HTTP-only cookies when your provider supports them
- protected route subtrees via layout routes
- permission re-checks in server functions for sensitive operations

## What auth is responsible for
- identifying the user
- attaching session/context to requests
- protecting route groups
- protecting sensitive mutations

## What auth is not allowed to assume
- a protected client route is sufficient security
- UI hiding equals authorization
- loader-only checks are enough for sensitive server actions
- route loaders are a hard security boundary; they are isomorphic and may run in the browser after initial SSR

## Recommended architecture

### 1. Protect route subtrees with a layout route
Use a parent route/layout for all authenticated pages.
This gives one central place for:
- session lookup
- redirect to login
- common shell for signed-in users

In TanStack Start, prefer `beforeLoad` on the parent layout or pathless protected layout for route-entry gating and redirects.
Use loaders for data orchestration, not as the primary auth boundary.

### 2. Keep the server as source of truth
If the user identity matters for real access control:
- resolve it on the server
- do not trust only client context

### 3. Re-check permissions in server functions
Even if the user reached the page through a protected route, sensitive actions still need server-side validation.

## Good patterns

### Route-level protection
- public subtree for marketing/auth pages
- protected subtree for dashboard/app pages

### Function-level protection
- `createServerFn()` calls enforce ownership/role/permission before read/write

### Middleware usage
Use middleware when auth concerns are shared across many routes/functions.

TanStack Start gives you two important middleware layers:
- request middleware → shared request/SSR/server-route/server-function concerns
- server function middleware → auth/authorization checks around `createServerFn()` calls

Good uses:
- session extraction
- role injection into context
- request logging tied to user identity
- shared `requireUser` / membership enforcement across many server functions

## Suggested rollout order
1. choose auth provider
2. wire provider keys/env vars
3. add provider at app shell/root level if needed
4. create protected layout subtree
5. add server-side session resolver
6. guard server functions for sensitive reads/writes
7. test redirect + unauthorized behavior

## Provider choices
Good practical options include:
- Clerk
- WorkOS
- Better Auth
- Auth.js
- Supabase Auth
- Auth0
- DIY

Choose by tradeoff:
- managed providers when enterprise features, org UX, or prebuilt auth flows matter
- OSS libraries like Better Auth or Auth.js when you want more control without fully DIY auth
- DIY only when you truly need custom auth behavior and are willing to own the security surface

### Better Auth + TanStack Start notes
If using Better Auth:
- mount the auth handler through a TanStack Start server route such as `/src/routes/api/auth/$.ts`
- use `tanstackStartCookies()` and keep it last in the plugin array
- prefer Better Auth client helpers for sign-in/sign-up browser flows
- use a small server function to read session on the server, then call it from `beforeLoad`

## Environment variable rules
- client-safe config only via `VITE_*`
- secrets stay server-only in `process.env`
- never expose secret keys via `VITE_`

## Safe defaults
- use a protected parent layout or pathless protected layout
- put redirect/session gates in `beforeLoad`
- keep the server as the source of truth for user identity and permissions
- centralize repeated auth checks with server function middleware when useful
- keep provider-specific SDK setup in a small dedicated auth layer

## Permission rule
Every sensitive mutation should answer:
- who is the user?
- are they allowed to do this?
- does the target resource belong to them or their org/workspace?

## Anti-patterns

### Anti-pattern 1
Only guarding components/UI and not the server mutation.

### Anti-pattern 2
Relying on loader behavior as if it were a hard security boundary.

### Anti-pattern 3
Sprinkling auth checks randomly through components instead of using a protected route tree.

### Anti-pattern 4
Mixing auth provider SDK calls into many unrelated files without a clear auth layer.

## Definition of done
Auth is correctly integrated when:
- public and protected routes are clearly separated
- sensitive actions are enforced server-side
- env var handling is correct
- unauthorized users are redirected or rejected predictably
- auth logic is centralized enough to maintain
