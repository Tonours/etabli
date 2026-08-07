---
name: tanstack-start-middleware
description: Apply TanStack Start request middleware and server-function middleware correctly for auth, logging, context propagation, and cross-cutting policies.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Middleware

Use this skill when adding cross-cutting concerns to a TanStack Start app.

## When to use
Use this skill when:
- auth, logging, context propagation, or tracing repeats across many requests or server functions
- the task is truly cross-cutting
- you need to choose between request middleware and server function middleware

## When not to use
Do not use this skill as the main guide when:
- only one handler needs a simple local check
- the real problem is resource-level business logic, not middleware

## Canonical rule
TanStack Start has **two middleware types**:
- **request middleware**
- **server function middleware**

They are not interchangeable.

## When to use request middleware
Use request middleware when the concern applies to:
- SSR requests
- server routes
- server functions
- broad request lifecycle behavior

Typical uses:
- session extraction
- logging
- CSP/security headers
- observability
- global request context

## When to use server function middleware
Use server function middleware when the concern applies specifically to `createServerFn()` calls.

Typical uses:
- auth around server functions
- input validation
- client-side header injection
- request tracing for RPC-style calls
- permission checks wrapped around many mutations/reads

## Selection rule
- broad server request policy → request middleware
- server function policy or RPC wrapping → function middleware

## Core mechanics

### Creation
Request middleware is the default:

```ts
import { createMiddleware } from '@tanstack/react-start'

export const requestLogger = createMiddleware().server(async ({ next }) => {
  return next()
})
```

Server function middleware is explicit:

```ts
import { createMiddleware } from '@tanstack/react-start'

export const authMiddleware = createMiddleware({ type: 'function' })
  .server(async ({ next }) => {
    const user = await requireUser()

    return next({
      context: { user },
    })
  })
```

Function middleware can use `.validator(...)`, `.client(...)`, and `.server(...)`. TypeScript enforces method order for inference.

> Do not confuse middleware validation with server-function validation: current TanStack Start uses `.validator(...)` for both `createMiddleware({ type: 'function' })` and `createServerFn(...)`; the middleware validator belongs to the middleware chain, while the server-function validator validates `data` before `.handler(...)`.

### Composition
Middleware is composable and dependency-first.
A middleware can depend on another middleware.

### next()
You must call `next()` to continue the chain.
Use it to:
- continue execution
- enrich context
- inspect results
- short-circuit if necessary

### Context propagation
- `next({ context })` merges context forward
- client context is **not** sent to server by default
- if you use `sendContext`, validate any untrusted dynamic data on the server

## Recommended patterns

### Pattern 1: global request middleware for session/logging
Use `src/start.ts` with `createStart(() => ({ requestMiddleware: [...], functionMiddleware: [...] }))` when a concern should apply everywhere.

When no custom `src/start.ts` exists, Start auto-registers a default CSRF request middleware (`createCsrfMiddleware()`). If you add your own `src/start.ts`, keep CSRF protection on the request middleware stack so server functions stay protected against cross-site calls.

Good examples:
- request logging
- session extraction
- tracing IDs

### Pattern 2: function middleware for authorization
If many server functions require user/session/permission checks, wrap them with function middleware instead of duplicating checks in every handler.

```ts
export const getProjects = createServerFn({ method: 'GET' })
  .middleware([authMiddleware])
  .handler(async ({ context }) => {
    return listProjectsForUser(context.user.id)
  })
```

If the policy must wrap every server function, register it through the Start app's global `functionMiddleware` configuration instead of relying on every handler to remember it.

### Pattern 3: middleware factories for permissions
Use a middleware factory when requirements vary by feature/resource.
For example:
- read project
- edit project
- manage billing

### Pattern 4: choose this, not that
- use **request middleware** for session extraction from cookies on every request
- use **server function middleware** for wrapping many `createServerFn()` handlers with auth or permission policies
- do **not** use middleware as a substitute for resource-level permission checks inside handlers

## Safe defaults
- choose request middleware for broad request concerns
- choose server function middleware for repeated `createServerFn()` policies
- keep middleware narrow, explicit, and easy to audit

## Practical rules
1. Keep middleware narrow and explicit.
2. Prefer one responsibility per middleware.
3. Use request middleware for broad infrastructure concerns.
4. Use function middleware for RPC-specific concerns.
5. Validate client-sent context on the server.

## Anti-patterns

### Anti-pattern 1
Using request middleware when only a few server functions need the behavior.

### Anti-pattern 2
Stuffing business logic into middleware.

### Anti-pattern 3
Relying on context sent from the client without server validation.

### Anti-pattern 4
Creating long, opaque middleware chains no one can debug.

## Definition of done
Middleware is correctly implemented when:
- the correct middleware type is chosen
- auth/logging/context concerns are centralized
- context propagation is explicit
- client-provided context is validated
- business logic remains in handlers/domain code, not smeared across middleware
