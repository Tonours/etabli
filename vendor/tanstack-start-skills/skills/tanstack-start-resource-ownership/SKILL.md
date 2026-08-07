---
name: tanstack-start-resource-ownership
description: Enforce resource ownership and permission checks in TanStack Start through server-side validation rather than route-level assumptions or UI-only guards.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Resource Ownership

Use this skill when a TanStack Start app has user-owned or org-owned resources such as:
- projects
- tasks
- invoices
- workspaces
- notes
- uploaded files
- API keys

## Goal
Make ownership checks explicit, server-side, and hard to forget.

This skill is about:
- ownership and authorization rules
- secure reads and writes
- route params vs actual permission checks
- consistent server-function patterns

## Canonical rule
**Route loaders are isomorphic, not server-only.**

Therefore:
- route loaders are not the final security boundary
- protected routes are useful for UX and high-level gating
- actual ownership enforcement belongs in server functions or server routes

## Core principle
Every sensitive read or mutation should answer:
- who is acting?
- what resource are they touching?
- why are they allowed to access or modify it?

If those answers are not explicit in server-side code, the app is relying on hope.

## When to use
Use this skill when:
- routes include params like `$projectId`, `$taskId`, `$workspaceId`
- different users or orgs should only see their own resources
- admin vs member vs owner roles matter
- a protected route tree already exists, but you need real data-level authorization

## When not to use
Do not use this skill as the main guide when:
- the task stops at route protection or sign-in UX
- the app has no per-resource ownership or tenant scope yet

## Hard rules
1. Never trust a route param by itself.
2. Never assume that reaching a protected page proves resource access.
3. Resolve the current actor on the server.
4. Check ownership/role/org scope before returning or mutating sensitive data.
5. Keep ownership rules close to the server function or server-only helper that touches the resource.

## Secure mental model
A route like `/app/projects/$projectId` only tells you:
- which page the user asked for

It does **not** prove:
- that the project belongs to them
- that they are in the right workspace
- that they can update/delete/share it

## Recommended pattern

### Step 0: Centralize repeated auth in server function middleware when helpful
If many server functions require the same session or membership lookup, use TanStack Start server function middleware to:
- resolve the actor once
- validate required scope
- pass actor/workspace/org context into the handler

### Step 1: Resolve actor server-side
Examples:
- current user
- current organization membership
- current workspace context

### Step 2: Constrain the resource query
Do not fetch the resource broadly and hope to reject later when the resource is already exposed.

Prefer:
- query by `id + ownerId`
- query by `id + orgId`
- query by `id + membership constraints`

### Step 3: Fail closed
If the record is not found inside the permitted scope:
- return not found
- or return forbidden

Choose deliberately based on product/security posture.

## Read pattern

```ts
// projects.server.ts
export async function getProjectForUser(userId: string, projectId: string) {
  return db.project.findFirst({
    where: {
      id: projectId,
      ownerId: userId,
    },
  })
}
```

```ts
// projects.functions.ts
export const getProject = createServerFn({ method: 'GET' })
  .validator((input: { projectId: string }) => input)
  .handler(async ({ data }) => {
    const user = await requireUser()
    const project = await getProjectForUser(user.id, data.projectId)

    if (!project) {
      throw notFound()
    }

    return project
  })
```

### Why this is good
- actor resolution is server-side
- ownership is part of the query itself
- route params do not bypass permission checks

## Mutation pattern

```ts
// projects.server.ts
export async function renameProjectForUser(userId: string, projectId: string, name: string) {
  const project = await db.project.findFirst({
    where: {
      id: projectId,
      ownerId: userId,
    },
  })

  if (!project) {
    throw notFound()
  }

  return db.project.update({
    where: { id: project.id },
    data: { name },
  })
}
```

### Mutation rules
- validate input first
- resolve user/session on the server
- scope the resource by ownership or role
- where your DB supports it, prefer write paths constrained by actor scope rather than broad writes by bare `id`
- only then perform the write
- return a shaped result for the UI

## Organization / workspace model
Ownership is not always user = owner.

Common valid models:
- user-owned resources
- workspace-owned resources
- org-owned resources with membership roles
- mixed model with owner + collaborators

The important part is not the exact model.
The important part is that the model is enforced server-side every time.

## Good patterns

### Good pattern 1
Constrain reads by both resource id and actor scope.

### Good pattern 2
Centralize repeated ownership checks in server-only helpers when they are truly reused.

### Good pattern 3
Use separate helpers or middleware-backed patterns for:
- `requireUser()`
- `requireWorkspaceMember()`
- `requireOrgAdmin()`

### Good pattern 4
Keep route files orchestration-focused and push real authorization into server functions.

## Heuristic: not found vs forbidden
Use `notFound` when:
- you do not want to reveal whether the resource exists outside the actor's scope

Use `forbidden` when:
- the product benefits from explicit permission messaging
- the actor is authenticated and knows the resource exists but lacks the right role

Pick one policy per resource type where practical.

## Safe defaults
- start with strict owner-scoped queries
- add role exceptions deliberately
- keep permission helpers small and explicit
- avoid magical generic authorization layers too early
- prefer boring repeated checks over hidden insecure cleverness

## Anti-patterns

### Anti-pattern 1
Reading by `id` alone and trusting the UI to hide unauthorized records.

### Anti-pattern 2
Checking auth at the page level but not at the data access level.

### Anti-pattern 3
Fetching the record first, then realizing too late that it belongs to another user.

### Anti-pattern 4
Putting ownership logic in client components or route loaders only.

### Anti-pattern 5
Creating a vague `canAccessResource()` abstraction that hides the actual ownership rules and becomes impossible to audit.

### Anti-pattern 6
Using admin overrides without making them visible and deliberate in server-side code.

## Definition of done
Resource ownership is in good shape when:
- route params never act as proof of access
- actor resolution happens server-side
- reads and writes are scoped by ownership, org, or role
- unauthorized access fails closed
- authorization rules are understandable in code review
- protected routes improve UX, but server-side checks provide the real safety
