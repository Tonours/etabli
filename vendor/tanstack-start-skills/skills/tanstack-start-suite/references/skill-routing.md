# TanStack Start suite routing

Pick from the dominant risk. When two skills look equally valid, the tie-breakers
at the bottom decide.

## Choose `tanstack-start-bootstrap` when

- the project does not exist yet, or its structure is unshaped
- the root route, router wiring, or Tailwind setup is the thing being created
- an existing app needs normalizing back to a conventional layout

## Choose `tanstack-start-route-patterns` when

- routes exist and the question is how to organize them
- nested layouts, pathless routes, or route groups are in play
- the app has grown and the route tree has stopped being readable

## Choose `tanstack-start-server-functions` when

- a loader, server function, or server route is being written or moved
- something might leak a secret or run on the wrong side of the boundary
- the bug is "this worked locally but broke in the browser bundle"

This is the default when the risk is a boundary violation, whatever the ticket's
subject line says.

## Choose `tanstack-start-middleware` when

- a policy must apply across many routes or server functions
- request context has to propagate down a chain
- logging, tracing, or a cross-cutting guard is the deliverable

## Choose `tanstack-start-auth` when

- authentication is being added and no provider is chosen yet
- the question is how server-driven auth should work in this framework
- protected route trees and server-side checks need designing together

## Choose `tanstack-start-public-private-route-trees` when

- the access boundary exists but is scattered or invisible
- public and protected areas need a structural split
- a reviewer cannot tell from the tree which routes are protected

## Choose `tanstack-start-resource-ownership` when

- the identity is known and the question is what it may touch
- a check exists at the route level but not on the server
- a UI guard is doing work that authorization should do

## Choose `tanstack-start-teams-and-orgs` when

- data is scoped per team, organization, or tenant
- membership and role checks decide access
- tenant context has to reach server functions reliably

## Choose `tanstack-start-database` when

- database access is being introduced and no ORM is chosen
- the concern is keeping queries behind server boundaries
- connection handling or secret exposure is the risk

## Choose `tanstack-query` when

- server state, caching, or query keys are the subject
- mutations, optimistic updates, or SSR hydration need designing
- the bug is stale data, a cache collision, or a hydration mismatch

## Choose `tanstack-start-query-invalidation` when

- a mutation already works and the UI does not reflect it
- the question is precisely what to invalidate after a server function
- router and query invalidation have to agree

## Choose `tanstack-start-file-uploads` when

- files move from client to durable storage
- upload size, type, or destination needs constraining
- the runtime limits what an upload path can do

## Choose `tanstack-start-seo` when

- head metadata, social cards, or structured data are the deliverable
- SSR output must be crawlable
- sitemap or robots support is missing

## Choose `tanstack-start-hosting` when

- the hosting target is not decided
- runtime constraints might rule out an approach
- SSR versus SPA rewrites need settling

## Choose a provider or host skill when

- the provider is actually decided: `tanstack-start-better-auth`,
  `tanstack-start-clerk`, `tanstack-start-prisma`, `tanstack-start-drizzle`
- the host is actually decided: `tanstack-start-deployment-recipes`

Before that decision, the generic skill is the better starting point. The
specific skills assume the boundary rules the generic ones teach.

## Tie-breakers

- **Boundary beats subject.** A Prisma question whose real risk is a leaked
  connection string is a `tanstack-start-server-functions` task first.
- **Authorization beats structure.** If a route tree is being reshaped to enforce
  access, read `tanstack-start-resource-ownership` before
  `tanstack-start-public-private-route-trees`. Structure makes a boundary
  visible; it does not enforce it.
- **Generic beats specific while a choice is open.** Reading `-clerk` before the
  team has picked Clerk produces a plan nobody agreed to.
- **Cache beats invalidation for design, invalidation beats cache for bugs.** Use
  `tanstack-query` to design cache ownership; use
  `tanstack-start-query-invalidation` when a specific mutation fails to refresh.
