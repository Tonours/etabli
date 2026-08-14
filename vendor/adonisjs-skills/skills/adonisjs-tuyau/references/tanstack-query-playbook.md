# Tuyau TanStack Query playbook

Use this reference when a Tuyau route feeds React Query or Vue Query.

## Setup

- use `@tuyau/react-query` with `@tanstack/react-query`
- use `@tuyau/vue-query` with `@tanstack/vue-query`
- keep the Tuyau adapter on a compatible major and prerelease tag with `@tuyau/core`
- create the core Tuyau client first, then create the framework-specific query client from it

Do not install an umbrella package name unless it exists in the registry and the dedicated official guide uses it.

## Query and mutation options

- use `queryOptions()` for standard queries
- use `mutationOptions()` for mutations
- use `infiniteQueryOptions()` only when the backend validates the pagination field named by `pageParamKey`
- use route-generated options instead of duplicating request functions or query keys

## Retry ownership

The framework adapters disable Ky retries so TanStack Query owns retry policy. Do not re-enable both layers; compounded retries increase latency and duplicate risk.

## Invalidation

- `queryKey()` targets one query with known parameters
- `pathKey()` targets one endpoint path when a parameter-specific key is unnecessary
- `pathFilter()` targets a broader route subtree

Choose the narrowest scope that makes stale data correct. Over-broad invalidation turns type-safe calls into avoidable network churn.

## Review checks

- route names, params, query, and body remain generated and typed
- mutation success invalidates every stale view, but no unrelated subtree
- Vue reactive inputs are passed through the adapter-supported reactive pattern
- infinite-query `pageParamKey` matches the Vine validator and response metadata
- tests cover the contract branch that drives cache behavior
