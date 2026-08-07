---
name: tanstack-start-public-private-route-trees
description: Structure public and protected route trees in TanStack Start so access boundaries stay visible, maintainable, and consistent with the framework's execution model.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Public / Private Route Trees

Use this skill when designing the route tree for an app that has a mix of:
- public pages
- auth pages
- signed-in product areas
- admin or role-restricted areas

## Goal
Make access boundaries obvious in the route tree itself.

This skill is about:
- route-tree structure
- layout ownership
- public vs protected grouping
- where to put `beforeLoad`-based session checks

It is **not** a replacement for server-side authorization.

## Canonical rule
**Route loaders are isomorphic, not server-only.**

Therefore:
- a route tree helps communicate access boundaries
- a protected layout can enforce session gating for navigation UX
- but route structure alone is not the final security boundary
- sensitive reads/writes still require server-side checks in server functions or server routes

## Core principle
Prefer a route tree that makes access structure visible at a glance.

Good route trees answer:
- which pages are public?
- which pages require a session?
- which subtree owns the authenticated shell?
- which subtree is admin-only or role-restricted?

## When to use
Use this skill when:
- the app has both marketing/public pages and a logged-in product area
- auth checks are starting to scatter across many route files
- you want one protected app shell instead of many page-level redirects
- role-specific areas such as admin/billing/settings are emerging

## When not to use
Do not use this skill as the main guide when:
- the task is primarily about provider-specific auth setup
- the app is too small to justify separate public/protected trees
- you need resource-level authorization patterns more than route-tree structure

## Baseline rules
1. Public pages and signed-in app pages should usually live in separate subtrees.
2. Shared authenticated shell belongs in a protected layout route.
3. Admin or special-role areas should be visibly grouped, not hidden as ad hoc checks inside random pages.
4. Route files should stay focused on route behavior, layout, and orchestration.
5. Real authorization stays server-side.

## Recommended shape

### Small product app
```text
src/routes/
  __root.tsx
  index.tsx
  pricing.tsx
  auth/
    sign-in.tsx
    sign-up.tsx
  app/
    route.tsx
    dashboard.tsx
    projects/
      index.tsx
      $projectId.tsx
```

### App with admin area
```text
src/routes/
  __root.tsx
  index.tsx
  pricing.tsx
  auth/
    sign-in.tsx
    sign-up.tsx
  app/
    route.tsx
    dashboard.tsx
    projects/
      index.tsx
      $projectId.tsx
    settings/
      index.tsx
  admin/
    route.tsx
    users.tsx
    audits.tsx
```

### Pathless protected layout
```text
src/routes/
  __root.tsx
  index.tsx
  login.tsx
  _protected.tsx
  _protected/
    dashboard.tsx
    projects/
      index.tsx
      $projectId.tsx
```

## Responsibilities by subtree

### Public subtree
Good fit for:
- landing pages
- docs
- pricing
- blog
- auth entry pages

Should not assume:
- session-only providers
- protected shell state
- privileged data access

### Protected app subtree
Good fit for:
- dashboard/workspace pages
- product navigation shell
- signed-in data views
- account settings

Parent layout should own:
- session lookup or redirect flow
- shared app shell
- common providers for signed-in areas
- route-level orchestration for the authenticated experience

### Admin subtree
Use a separate subtree when:
- the shell differs materially
- the role boundary is important enough to make visible
- admin pages should not be mixed into normal user navigation

## Layout pattern
A parent layout route is the right place for:
- signed-in shell chrome
- redirect-to-login flow
- common navigation
- high-level route gating for UX

It is **not** the place to assume that every child action is now authorized.

## Session gating pattern
Typical TanStack Start pattern:
- protected parent layout uses `beforeLoad`
- `beforeLoad` calls a server function such as `getSession`
- unauthenticated users are redirected away
- child routes can assume a signed-in user exists for UI flow
- server functions still validate ownership and permissions for real data access

## Good route examples

### Public marketing + private app
```text
src/routes/
  __root.tsx
  index.tsx
  features.tsx
  auth/
    sign-in.tsx
  app/
    route.tsx
    dashboard.tsx
    invoices/
      index.tsx
      $invoiceId.tsx
```

### Private app + explicit admin
```text
src/routes/
  __root.tsx
  index.tsx
  auth/
    sign-in.tsx
  app/
    route.tsx
    dashboard.tsx
    projects/
      index.tsx
  admin/
    route.tsx
    users.tsx
```

## Decision heuristics

### Create a separate protected subtree when
- many pages share the same signed-in shell
- auth redirects are repeating across routes
- the app has a true product/workspace area

### Create a separate admin subtree when
- role separation matters operationally
- the shell/navigation differs
- you want reviewers to see the privilege boundary in the file tree

### Keep a page in the public tree when
- it must be shareable without auth
- it is marketing/content-first
- it should not pull in authenticated app shell assumptions

## Safe defaults
- keep public and protected UX visibly separated
- use `beforeLoad` on parent protected layouts
- prefer visible route structure over clever nesting tricks
- keep real authorization in server functions

## Safety rules
1. Do not confuse route grouping with authorization.
2. Do not put secrets or direct DB access in route loaders.
3. Use server functions to re-check access for reads and mutations.
4. Keep route naming boring and predictable.
5. Favor visible structure over clever nesting tricks.

## Anti-patterns

### Anti-pattern 1
Mixing public landing pages and authenticated product pages into one flat route tree.

### Anti-pattern 2
Repeating redirect/session checks in every child page instead of using a protected parent layout.

### Anti-pattern 3
Hiding admin pages inside the normal app subtree with only vague UI guards.

### Anti-pattern 4
Assuming that because a page is under `/app` or `/admin`, every data read/write is automatically authorized.

### Anti-pattern 5
Pushing business logic and permission logic into route files until the route tree becomes hard to reason about.

## Definition of done
Public/private route structure is in good shape when:
- the route tree makes access boundaries easy to scan
- public pages are clearly separate from signed-in areas
- protected areas share a parent shell/layout
- special-role areas are visibly grouped when needed
- server-side authorization still handles sensitive reads and writes
- route files remain readable instead of becoming security theater
