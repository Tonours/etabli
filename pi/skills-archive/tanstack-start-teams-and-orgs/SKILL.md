---
name: tanstack-start-teams-and-orgs
description: Model teams and organizations in TanStack Start with explicit tenant context, server-side membership checks, and route trees that improve UX without replacing authorization.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Teams and Orgs

Use this skill when a TanStack Start app supports:
- multi-user workspaces
- organizations
- teams
- tenant-scoped resources
- role-based access inside a shared product

## When to use
Use this skill when:
- the app is multi-tenant or org-scoped
- membership, roles, and tenant context must be explicit
- you need a pattern for org/team-aware route and data boundaries

## When not to use
Do not use this skill as the main guide when:
- the app is still single-user/single-tenant
- you only need provider-specific auth setup without tenant modeling

## Important scope note
There does **not** appear to be a dedicated official TanStack Start teams/orgs guide.
This skill is a grounded pattern skill built from official framework primitives:
- authentication overview/authentication
- middleware
- server functions
- server routes
- route protection patterns
- database scoping principles

## Goal
Make tenant context explicit and authorization enforceable.

## Canonical rule
Protected routes improve navigation UX, but **server-side membership and permission checks are the real boundary**.

## Core domain model
Most teams/orgs apps need some version of:
- users
- organizations or workspaces
- teams (optional)
- memberships
- roles
- permissions
- invites

## Core TanStack Start posture
- use `beforeLoad` for route-entry gating and redirect behavior
- use server functions or server routes for membership/permission enforcement
- keep tenant-scoped DB queries server-side
- do not trust route params alone

## Recommended route shape

### App with org context in URL
```text
src/routes/
  __root.tsx
  auth/
    sign-in.tsx
  _authed.tsx
  _authed/
    orgs/
      $orgSlug/
        dashboard.tsx
        projects/
          index.tsx
          $projectId.tsx
        settings.tsx
```

## Why this shape works
- authenticated UX is grouped
- tenant context is visible in the URL
- route entry can be gated in `_authed.tsx`
- data access still has to prove org membership on the server

## Server-side enforcement pattern
Every sensitive read/write should answer:
- who is the actor?
- which org/team/workspace is in scope?
- what role or permission allows this action?

Typical flow:
1. resolve current user on the server
2. resolve tenant membership on the server
3. constrain queries by tenant scope
4. reject access when membership/role is insufficient

## Middleware pattern
If many server functions need the same tenant context, use server function middleware to:
- resolve session once
- attach active org/team context
- fail fast when membership is missing

## Route gating pattern
Use `beforeLoad` for:
- redirecting unauthenticated users
- redirecting users away from org routes they should not enter at all
- ensuring signed-in UX assumptions before the route renders

Do **not** use `beforeLoad` as the only authorization layer for sensitive data.

## DB scoping rules
- org-owned resources should carry org/workspace foreign keys
- team-owned resources should carry team foreign keys
- queries should be tenant-scoped, not broad-by-default
- route params like `$orgSlug` or `$teamSlug` identify requested context, not proven permission

## Role model guidance
Keep the first role system boring.

A common starting point:
- owner
- admin
- member
- viewer

Then map actions to explicit permission checks in server-only code.

## Provider integrations
If using a provider with org/team primitives such as Clerk or WorkOS:
- let the provider accelerate identity/session/org UX where helpful
- still keep app-level resource scoping explicit in your own server-side logic

## Safe defaults
- put tenant context in the URL when deep-linking and auditability matter
- centralize membership checks enough to stay consistent
- keep permission helpers explicit and reviewable
- scope reads and writes by org/team membership directly in server code
- treat UI hiding as convenience, not security

## Anti-patterns

### Anti-pattern 1
Treating `/orgs/$orgSlug/...` as proof that the user belongs to that org.

### Anti-pattern 2
Checking tenant access in the UI but not in server-side data access.

### Anti-pattern 3
Using one vague `canAccess()` abstraction that hides every real rule.

### Anti-pattern 4
Mixing personal and org-owned resources without an explicit ownership model.

### Anti-pattern 5
Letting provider org membership UX replace app-level authorization and DB scoping.

## Definition of done
Teams/orgs support is in good shape when:
- tenant context is explicit
- authenticated route entry is handled cleanly with `beforeLoad`
- membership and role checks happen server-side
- DB queries are tenant-scoped
- provider-specific org features remain subordinate to explicit app-level authorization rules
