---
name: tanstack-start-query-invalidation
description: Use the correct TanStack Router and TanStack Query invalidation patterns after TanStack Start server-function mutations.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Query Invalidation

Use this skill when a TanStack Start mutation succeeds but the UI still needs fresh data.

## When to use
Use this skill when:
- a mutation succeeded but the page still shows stale data
- you need to decide between Router invalidation and Query invalidation
- a route loader seeds Query cache and ownership of visible data is unclear

## When not to use
Do not use this skill as the main guide when:
- you are still designing the mutation boundary itself
- the task is purely about DB access or auth and not about refresh behavior

## Goal
Refresh the **right cache layer** after a mutation instead of guessing.

## Canonical rule
A successful server function mutation does **not** automatically refresh your UI state.
You must explicitly invalidate the cache layer that owns the displayed data.

## The three cases

### 1. Route loader / TanStack Router cache owns the data
Use:
- `router.invalidate()`

Use this when:
- the page renders from route loader data
- you are not using TanStack Query as the owning cache for that data

### 2. TanStack Query owns the data
Use:
- `queryClient.invalidateQueries({ queryKey })`

Use this when:
- components render from Query hooks such as `useQuery` or `useSuspenseQuery`
- Query is the actual source of truth for that UI state

### 3. Loader seeds TanStack Query cache
Use the mixed pattern:
- loader ensures query data
- component reads from Query cache
- mutation invalidates Query keys
- only also call `router.invalidate()` if route-level loader logic itself must rerun

## Official Router guidance
TanStack Router has built-in SWR-style loader caching.

Important behaviors:
- default route loader `staleTime` is `0`
- stale matches reload in the background
- `router.invalidate()` marks cached route data stale and reloads active routes
- invalidation is coarse and route-oriented

If the next step depends on fresh loader data before continuing, use:

```ts
await router.invalidate({ sync: true })
```

## Official Query guidance
When TanStack Query owns the data, invalidate query keys in mutation callbacks.

```ts
const mutation = useMutation({
  mutationFn: createProject,
  onSuccess: async () => {
    await queryClient.invalidateQueries({ queryKey: ['projects'] })
  },
})
```

If multiple query keys depend on the mutation:

```ts
onSuccess: async () => {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: ['projects'] }),
    queryClient.invalidateQueries({ queryKey: ['project-counts'] }),
  ])
}
```

## Recommended Start + Query integration pattern

### Loader seeds Query cache
```ts
loader: ({ context }) => {
  return context.queryClient.ensureQueryData(projectsQueryOptions)
}
```

### Component reads from Query
```ts
const { data } = useSuspenseQuery(projectsQueryOptions)
```

### Mutation invalidates Query cache
```ts
const mutation = useMutation({
  mutationFn: createProject,
  onSuccess: async () => {
    await queryClient.invalidateQueries({ queryKey: ['projects'] })
  },
})
```

## Decision table
- page uses loader-returned data directly → `router.invalidate()`
- page uses Query cache directly → `queryClient.invalidateQueries(...)`
- loader preloads Query cache for SSR/SEO/smoother hydration → usually invalidate Query keys
- mutation changes route-scoped context beyond Query data → Query invalidation plus `router.invalidate()` if route logic must rerun

## Search-param-driven data
If route loader data depends on search params, make that dependency explicit with `loaderDeps` so Router cache behavior stays correct.

## Safe defaults
- choose one clear owner for each important data surface
- use stable query keys
- keep invalidation close to the mutation success path
- await invalidation when post-submit UX depends on fresh data
- avoid mixing Router cache and Query cache casually without knowing which one owns the visible state

## Anti-patterns

### Anti-pattern 1
Mutate data and assume the UI will refresh on its own.

### Anti-pattern 2
Calling only `router.invalidate()` when the component actually renders from TanStack Query cache.

### Anti-pattern 3
Calling only `queryClient.invalidateQueries(...)` when route loader logic itself must rerun.

### Anti-pattern 4
Using unstable or inconsistent query keys.

### Anti-pattern 5
Skipping `loaderDeps` for search-param-based loader data.

## Definition of done
Invalidation is in good shape when:
- the cache owner is explicit
- Router cache is invalidated with `router.invalidate()` when loader-owned data changes
- Query cache is invalidated with `queryClient.invalidateQueries(...)` when Query-owned data changes
- sync invalidation is used deliberately when UX depends on fresh results before continuing
- there is no hidden assumption that server functions auto-refresh rendered state
