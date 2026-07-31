---
name: tanstack-start-route-patterns
description: Use TanStack Start file-based routing, root routes, nested layouts, and protected route trees in a way that keeps apps understandable as they grow.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Route Patterns

Use this skill when designing or refactoring route structure in a TanStack Start app.

## When to use
Use this skill when:
- route structure is growing beyond a tiny app
- you need to clarify layout boundaries or protected subtrees
- file-based routing organization is becoming hard to scan

## When not to use
Do not use this skill as the main guide when:
- the task is mostly about provider setup or DB access
- the app is so small that extra structure would only add ceremony
- the task is specifically about public vs protected access boundaries across
  the tree — use `tanstack-start-public-private-route-trees` instead

## Goal
Keep routing readable, scalable, and aligned with how TanStack Router and Start actually work.

This skill is specifically about:
- file-tree design
- layout boundaries
- protected subtrees
- dynamic route organization

It is **not** the place for DB/auth business logic beyond how those concerns shape the route tree.

## Canonical rule
Route trees should make UI boundaries and auth/navigation structure visible without pretending route files are the final security boundary.

## Core primitives
- `router.tsx`
- `src/routes/__root.tsx`
- file-based route tree
- nested routes/layouts
- pathless layout routes for shared layout/auth logic without changing the URL
- grouped routes for file organization when useful

## Baseline rules
1. Root route owns the document shell, not product complexity.
2. Route files should express page structure and route behavior, not become dumping grounds.
3. Use nesting to express actual UI/layout ownership.
4. Use protected subtrees for authenticated areas.
5. Keep route naming boring and predictable.

## Recommended route structure progression

### Small app
```text
src/routes/
  __root.tsx
  index.tsx
  about.tsx
```

### Product app
```text
src/routes/
  __root.tsx
  index.tsx
  auth/
    sign-in.tsx
    sign-up.tsx
  app/
    route.tsx
    dashboard.tsx
    skills/
      index.tsx
      $skillId.tsx
      new.tsx
```

## Root route responsibilities
Good responsibilities:
- document shell
- global providers
- stylesheet links
- metadata defaults
- global app shell pieces that truly belong everywhere

Bad responsibilities:
- feature-specific business logic
- unrelated queries/mutations
- page-specific state

## Layout route guidance
Use layout routes when a group of routes shares:
- shell/navigation
- access control
- context/provider needs
- common route-level behavior

If a layout route exists to protect access, put the redirect/session gate in `beforeLoad`.
Use loaders for data orchestration, not as the primary auth gate.

Examples:
- marketing vs app shell
- authenticated workspace shell
- admin shell
- pathless protected layout when you want a visible boundary without `/app` in the URL

## Protected subtree pattern
Prefer a protected subtree or pathless protected layout over ad hoc checks in
many child pages — one parent layout owns the authenticated shell and the
`beforeLoad` session gate. For the full public/protected tree design (admin
areas, role boundaries, gating patterns), use
`tanstack-start-public-private-route-trees`, the access-boundary specialist.

Sensitive read/write authorization still belongs in server functions, not in the route tree alone.

## Dynamic route guidance
Use dynamic routes for entity detail pages.
Examples:
- `/skills/$skillId`
- `/projects/$projectId`

Rules:
- keep param naming explicit
- avoid overly deep, accidental nesting
- use route-level loaders only for route data orchestration
- route loaders are isomorphic, not server-only; they should not become auth or DB security boundaries

## Route design heuristics

### Use a new route when
- the URL meaningfully changes
- metadata/head should differ
- data loading concerns differ
- sharing/deep-linking matters

### Use a component instead when
- the URL does not need to change
- it is purely local UI composition

## Safe defaults
- keep route names boring and predictable
- use parent layouts or pathless layouts for shared shells and gating
- keep route files focused on route concerns, not domain logic

## Anti-patterns

### Anti-pattern 1
A gigantic `__root.tsx` acting as the whole app.

### Anti-pattern 2
Flat route sprawl with no grouping once the app grows.

### Anti-pattern 3
Scattering auth checks across many pages instead of using a protected subtree.

### Anti-pattern 4
Pushing too much domain logic into route files.

## Definition of done
Route structure is good when:
- the route tree is easy to scan
- layouts reflect actual UI/security boundaries
- dynamic routes are explicit
- protected areas are visibly grouped
- route files remain understandable instead of becoming mini-frameworks of their own
