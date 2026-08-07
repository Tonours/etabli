# TanStack Start workflow order

For work spanning several phases, read in this order. Stop as soon as the change
is covered — a full pass is rarely needed.

## New app

1. `tanstack-start-bootstrap` — structure first
2. `tanstack-start-route-patterns` — the route tree
3. `tanstack-start-server-functions` — the server boundary
4. `tanstack-start-database` or the chosen ORM skill
5. `tanstack-start-auth`, then `tanstack-start-public-private-route-trees`
6. `tanstack-query` — cache ownership
7. `tanstack-start-hosting`, then the recipe for the chosen host

## Adding a protected feature to an existing app

1. `tanstack-start-server-functions` — where the data comes from
2. `tanstack-start-resource-ownership` — who may touch it
3. `tanstack-start-public-private-route-trees` — where the boundary lives
4. `tanstack-start-query-invalidation` — what refreshes after a mutation

## Shipping

1. `tanstack-start-hosting` — target and runtime constraints
2. `tanstack-start-deployment-recipes` — the minimum host-specific change
3. `tanstack-start-seo` — only if the surface is public

## Rule

Authorization is never the last step. A feature that reaches the deployment
phase without a server-side ownership check ships an open door.
