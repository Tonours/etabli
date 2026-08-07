---
name: tanstack-start-suite
description: "Route TanStack Start work to the right skill. Use when a task touches TanStack Start or TanStack Query but the dominant need — scaffolding, routing, server functions, auth, database, middleware, caching, multi-tenancy, uploads, SEO, or deployment — is not yet clear. Also use when the task names a specific integration (Better Auth, Clerk, Prisma, Drizzle) or a host (Node, Nitro, Netlify, Railway, Vercel, Cloudflare) and the generic skill might be the better starting point."
---

# TanStack Start suite

Router for the TanStack Start skill set.

Read [skill routing](references/skill-routing.md) first.
Read [workflow order](references/workflow-order.md) when the task spans several phases.

## Core rule

Choose from the dominant risk, not from the first file you opened or the
technology the ticket happens to name.

Nearly every skill here repeats one concern: **what runs on the server stays on
the server**. When a task's real risk is a leaked secret or a client/server
boundary crossing, start at `tanstack-start-server-functions` even when the
subject sounds like something else.

## Routing guide

| Dominant need | Use |
|---|---|
| New or unshaped project, root route, router setup, Tailwind, project structure | [tanstack-start-bootstrap](../tanstack-start-bootstrap/SKILL.md) |
| File-based routing, root routes, nested layouts, keeping routes understandable | [tanstack-start-route-patterns](../tanstack-start-route-patterns/SKILL.md) |
| Loaders, server functions, server routes, execution boundaries, secret leakage | [tanstack-start-server-functions](../tanstack-start-server-functions/SKILL.md) |
| Request or server-function middleware, logging, context propagation, cross-cutting policy | [tanstack-start-middleware](../tanstack-start-middleware/SKILL.md) |
| Authentication and route protection, no provider chosen yet | [tanstack-start-auth](../tanstack-start-auth/SKILL.md) |
| Where the public/protected split lives structurally | [tanstack-start-public-private-route-trees](../tanstack-start-public-private-route-trees/SKILL.md) |
| Who may touch this record — ownership and permission checks | [tanstack-start-resource-ownership](../tanstack-start-resource-ownership/SKILL.md) |
| Teams, organizations, tenant context, membership checks | [tanstack-start-teams-and-orgs](../tanstack-start-teams-and-orgs/SKILL.md) |
| Database access through server boundaries, no ORM chosen yet | [tanstack-start-database](../tanstack-start-database/SKILL.md) |
| Server state, query keys, cache ownership, mutations, optimistic updates, SSR hydration | [tanstack-query](../tanstack-query/SKILL.md) |
| What to invalidate after a server-function mutation | [tanstack-start-query-invalidation](../tanstack-start-query-invalidation/SKILL.md) |
| File uploads, durable storage, runtime-aware upload security | [tanstack-start-file-uploads](../tanstack-start-file-uploads/SKILL.md) |
| Head metadata, SSR discipline, social cards, structured data, sitemap and robots | [tanstack-start-seo](../tanstack-start-seo/SKILL.md) |
| Choosing a hosting target, runtime constraints, SSR vs SPA rewrites | [tanstack-start-hosting](../tanstack-start-hosting/SKILL.md) |

## Provider and host specifics

Reach for a specific skill only once the provider or host is actually decided.
Until then the generic skill above is the better starting point, because it
carries the boundary rules the specific one assumes you already know.

| Decided on | Use |
|---|---|
| Better Auth | [tanstack-start-better-auth](../tanstack-start-better-auth/SKILL.md) |
| Clerk | [tanstack-start-clerk](../tanstack-start-clerk/SKILL.md) |
| Prisma | [tanstack-start-prisma](../tanstack-start-prisma/SKILL.md) |
| Drizzle | [tanstack-start-drizzle](../tanstack-start-drizzle/SKILL.md) |
| A concrete host — Node, Nitro, Netlify, Railway, Vercel, Cloudflare | [tanstack-start-deployment-recipes](../tanstack-start-deployment-recipes/SKILL.md) |

## Rules

More than one row can apply. Read them in the order the task needs and stop as
soon as you have what the change requires.

Auth splits three ways and the distinction matters: `tanstack-start-auth` is
*can this request prove who it is*, `tanstack-start-resource-ownership` is *may
this identity touch this record*, and `tanstack-start-public-private-route-trees`
is *where that boundary lives in the route tree*. A route tree that looks
protected is not authorization; pair it with a server-side check.

A routed skill does not widen the task. Adjacent work it suggests stays out of
scope.

If no row fits, say so and proceed without a skill rather than forcing the
closest match.
