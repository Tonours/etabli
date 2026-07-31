---
name: tanstack-query
description: Use TanStack Query v5 correctly for server state, cache ownership, query keys, mutations, invalidation, optimistic updates, SSR hydration, and TanStack Start integration.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Query

Use this skill when designing, implementing, reviewing, or debugging server-state behavior with TanStack Query.

## Source base
Use the official TanStack Query v5 React docs as canonical:
- Overview
- Important Defaults
- Queries, Query Functions, Query Options
- Query Keys
- Mutations
- Query Invalidation and Invalidations from Mutations
- Updates from Mutation Responses
- Optimistic Updates
- Prefetching and Router Integration
- Server Rendering and Hydration
- Render Optimizations
- Testing

## When to use
Use this skill when:
- UI reads remote/server state through `useQuery`, `useSuspenseQuery`, `useInfiniteQuery`, or `useQueries`
- a mutation must update, invalidate, or optimistically change cached data
- stale data, duplicated fetching, waterfalls, hydration, retries, pagination, or cache ownership is unclear
- a TanStack Start app mixes route loaders, server functions, and Query cache
- query keys or query option factories are drifting across features

## When not to use
Do not use this skill as the main guide when:
- the state is purely client-owned UI state; use local state, reducer, store, or URL/search params instead
- the task is only about TanStack Start server/client boundaries; use `tanstack-start-server-functions`
- the task is only about Router loader cache without Query owning rendered data

## Canonical rule
TanStack Query manages **server state**, not arbitrary client state.

Server state is remote, async, shared, cacheable, and can become stale without user action. Query's job is to fetch, cache, synchronize, invalidate, retry, garbage collect, and update that state without hand-rolled effect/cache code.

## Mental model
- query = read server state
- mutation = create/update/delete or server side effect
- query key = identity of cached data
- query function = how to fetch that identity
- staleTime = how long data is considered fresh
- gcTime = how long inactive data remains cached
- invalidation = explicit statement that cached data is no longer trustworthy
- optimistic update = temporary UI/cache update before the mutation result is confirmed

## QueryClient setup
Create one stable browser `QueryClient` for the app runtime. Do not create a new client inside render.

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
    },
  },
})

export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  )
}
```

Default `staleTime` is `0`, so cached data is stale immediately. Set a domain-appropriate `staleTime` instead of turning off refetch behavior blindly.

For SSR, create a request-scoped server `QueryClient` instead of reusing this browser singleton.

## Query keys
Query keys must be arrays, serializable, and unique to the data they represent.

Good:
```ts
export const projectKeys = {
  all: ['projects'] as const,
  lists: () => [...projectKeys.all, 'list'] as const,
  list: (filters: ProjectFilters) => [...projectKeys.lists(), filters] as const,
  details: () => [...projectKeys.all, 'detail'] as const,
  detail: (projectId: string) => [...projectKeys.details(), projectId] as const,
}
```

Rules:
- include every variable used by the query function in the query key
- use key factories for non-trivial domains
- use objects for optional filters so object key order does not matter
- do not put functions, class instances, non-serializable values, or unstable objects in keys
- use prefixes intentionally so invalidation can target a list, detail, or entire resource family

## Query option factories
Prefer reusable option factories over duplicating `queryKey` and `queryFn` pairs.

```ts
import { queryOptions } from '@tanstack/react-query'

export function projectListOptions(filters: ProjectFilters) {
  return queryOptions({
    queryKey: projectKeys.list(filters),
    queryFn: () => fetchProjects(filters),
    staleTime: 60_000,
  })
}
```

Use these factories from components, prefetching, route loaders, tests, and invalidation decisions.

## Query functions
Query functions should:
- return data or throw an error
- be deterministic for the query key
- avoid writing server state
- accept cancellation when using `fetch`
- not return `undefined`

```ts
async function fetchProjects({ signal }: { signal?: AbortSignal }) {
  const response = await fetch('/api/projects', { signal })

  if (!response.ok) {
    throw new Error('Failed to load projects')
  }

  return response.json() as Promise<Project[]>
}
```

## Reads
Use `useQuery` for normal component reads.

```tsx
const projectsQuery = useQuery(projectListOptions(filters))

if (projectsQuery.isPending) return <PendingState />
if (projectsQuery.isError) return <ErrorState error={projectsQuery.error} />

return <ProjectTable projects={projectsQuery.data} />
```

Use `useSuspenseQuery` only when the route/app has deliberate Suspense and error-boundary behavior. Do not use Suspense to hide unclear loading/error ownership.

## Dependent and disabled queries
Use `enabled` when a query cannot run until required data exists.

```ts
const projectQuery = useQuery({
  ...projectDetailOptions(projectId),
  enabled: Boolean(projectId),
})
```

Do not use `enabled: false` as a default fetch button pattern unless the product workflow is genuinely manual. Prefer declarative keys and dependencies.

## Parallel and dynamic queries
- use multiple `useQuery` calls for a fixed small set of independent reads
- use `useQueries` for a dynamic list of reads
- watch for request waterfalls; prefetch or route-load parent data when the UI can know the dependency earlier

## Pagination and infinite queries
For page-indexed data, include page and filters in the key.

```ts
useQuery({
  queryKey: ['projects', 'list', { page, filters }],
  queryFn: () => fetchProjectsPage({ page, filters }),
  placeholderData: (previousData) => previousData,
})
```

For cursor-based feeds, use `useInfiniteQuery` with `initialPageParam`, `getNextPageParam`, and a stable base key that includes filters.

```ts
useInfiniteQuery({
  queryKey: ['activity', { projectId }],
  queryFn: ({ pageParam }) => fetchActivity({ projectId, cursor: pageParam }),
  initialPageParam: null as string | null,
  getNextPageParam: (lastPage) => lastPage.nextCursor,
})
```

Do not mix page-indexed and infinite data under the same query key.

## Mutations
Use `useMutation` for writes and side effects. A mutation does not automatically update every dependent query.

```ts
const queryClient = useQueryClient()

const createProjectMutation = useMutation({
  mutationFn: createProject,
  onSuccess: async () => {
    await queryClient.invalidateQueries({ queryKey: projectKeys.lists() })
  },
})
```

Return the invalidation promise when the UI should remain pending until fresh data has been requested.

## Updating from mutation responses
If the mutation returns the exact updated resource, update precise cache entries directly and invalidate broader derived data.

```ts
const updateProjectMutation = useMutation({
  mutationFn: updateProject,
  onSuccess: (project) => {
    queryClient.setQueryData(projectKeys.detail(project.id), project)
    void queryClient.invalidateQueries({ queryKey: projectKeys.lists() })
  },
})
```

Use direct cache writes for exact data. Use invalidation for lists, counts, derived totals, search results, permissions, or anything the mutation response cannot fully prove.

## Optimistic updates
Use optimistic UI when latency matters and rollback semantics are clear.

```ts
const updateProjectNameMutation = useMutation({
  mutationFn: updateProjectName,
  onMutate: async (input) => {
    await queryClient.cancelQueries({ queryKey: projectKeys.detail(input.projectId) })

    const previousProject = queryClient.getQueryData<Project>(
      projectKeys.detail(input.projectId),
    )

    queryClient.setQueryData<Project>(projectKeys.detail(input.projectId), (old) =>
      old ? { ...old, name: input.name } : old,
    )

    return { previousProject }
  },
  onError: (_error, input, context) => {
    if (context?.previousProject) {
      queryClient.setQueryData(projectKeys.detail(input.projectId), context.previousProject)
    }
  },
  onSettled: (_data, _error, input) => {
    return queryClient.invalidateQueries({ queryKey: projectKeys.detail(input.projectId) })
  },
})
```

Rules:
- cancel related queries before writing optimistic cache
- snapshot previous cache data
- rollback on error
- invalidate or refetch after settlement unless the mutation response fully reconciles the cache
- keep optimistic updates narrow; broad optimistic list rewrites are easy to get wrong

## Invalidation strategy
Invalidate the smallest stable key prefix that covers the stale data.

```ts
queryClient.invalidateQueries({ queryKey: projectKeys.lists() })
queryClient.invalidateQueries({ queryKey: projectKeys.detail(projectId), exact: true })
```

Use:
- list prefix after create/delete/reorder/filter-impacting writes
- detail key after updating a single resource
- broader resource prefix when membership, permissions, or derived aggregates changed
- `exact: true` when only one exact cache entry should be affected

Do not call `queryClient.invalidateQueries()` globally unless the mutation truly invalidates the entire app cache.

## TanStack Start integration
Use Start server functions for private reads/writes and Query for client cache ownership.

```tsx
import { useServerFn } from '@tanstack/react-start'
import { useQuery } from '@tanstack/react-query'
import { getProjects } from '~/utils/projects.functions'

function Projects() {
  const getProjectsFn = useServerFn(getProjects)

  const projectsQuery = useQuery({
    queryKey: projectKeys.lists(),
    queryFn: () => getProjectsFn(),
  })

  if (projectsQuery.isPending) return <PendingState />
  if (projectsQuery.isError) return <ErrorState error={projectsQuery.error} />

  return <ProjectTable projects={projectsQuery.data} />
}
```

For mutations backed by Start server functions, wrap the function and preserve the server-function call shape.

```tsx
const createProjectFn = useServerFn(createProject)

const createProjectMutation = useMutation({
  mutationFn: (input: CreateProjectInput) => createProjectFn({ data: input }),
  onSuccess: () => {
    return queryClient.invalidateQueries({ queryKey: projectKeys.lists() })
  },
})
```

When a route loader seeds Query cache:
- loader calls `queryClient.ensureQueryData(options)`
- component reads with `useSuspenseQuery(options)` or `useQuery(options)`
- mutation invalidates Query keys
- call `router.invalidate()` only if route-level loader logic, route context, or loader-returned data must rerun

Do not assume a successful Start server function mutation refreshes Router or Query caches.

## SSR and hydration
For server rendering:
- create a request-scoped QueryClient on the server
- prefetch or ensure needed data
- dehydrate on the server and hydrate on the client
- set a non-zero `staleTime` for SSR-prefetched data to avoid immediate refetch churn

Never reuse a cross-request server QueryClient. That risks data leaking between users.

## Defaults to challenge before changing
TanStack Query defaults are intentionally aggressive:
- cached data is stale by default
- stale queries refetch on mount, window focus, and reconnect
- inactive queries are garbage collected after 5 minutes
- failed queries retry 3 times with backoff
- structural sharing keeps stable references for JSON-compatible data

Change defaults per domain. Do not cargo-cult `staleTime: Infinity`, `retry: false`, or disabled focus refetching across the whole app.

Use:
- short `staleTime` for fast-changing collaborative data
- longer `staleTime` for reference/config data
- `Infinity` when manual invalidation remains the refresh mechanism
- `staleTime: 'static'` only for data that cannot change while the app is running
- lower `retry` for user-triggered writes or non-idempotent flows

## Performance and render discipline
- use `select` to subscribe to a derived slice of large data
- avoid rest destructuring query results because tracked properties optimize renders
- keep query option objects stable through factories
- prefetch to avoid waterfalls when parent route/context already knows the next data need
- avoid duplicating remote state into local state unless editing a draft form

## Testing checklist
Test behavior, not implementation details:
- loading, success, empty, and error states
- query key changes when variables change
- mutation success invalidates or updates the intended keys
- optimistic update rolls back on failure
- SSR-prefetched data hydrates without a duplicate unactionable refetch
- auth/tenant data is not reused across users or tenants

For integration tests, create a fresh `QueryClient` per test and disable retries unless retry behavior itself is under test.

## Safe defaults
- one clear cache owner per data surface
- query keys live near the domain API
- reads use `useQuery` / `useSuspenseQuery`; writes use `useMutation`
- invalidation lives in mutation callbacks or domain mutation hooks
- server functions/server routes own secrets and authorization in Start apps
- SSR QueryClients are request-scoped
- defaults are changed locally before globally

## Anti-patterns

### Anti-pattern 1
Using TanStack Query for local modal state, form drafts, tabs, toggles, or animation state.

### Anti-pattern 2
Omitting variables from query keys and wondering why data does not refetch or caches collide.

### Anti-pattern 3
Creating a `QueryClient` inside a React component render path.

### Anti-pattern 4
Invalidating every query after every mutation.

### Anti-pattern 5
Doing broad optimistic cache rewrites without cancellation, snapshot, rollback, and settlement invalidation.

### Anti-pattern 6
Copying query data into local state just to render it.

### Anti-pattern 7
Setting `staleTime: Infinity`, `retry: false`, or `refetchOnWindowFocus: false` globally to silence symptoms.

### Anti-pattern 8
Using the same query key for normal and infinite queries.

### Anti-pattern 9
Treating TanStack Start route loader cache and TanStack Query cache as if they invalidate each other automatically.

## Definition of done
TanStack Query usage is in good shape when:
- each server-state surface has one explicit cache owner
- query keys are stable, serializable, complete, and domain-organized
- query functions are pure reads that return data or throw
- mutations intentionally update exact data, invalidate stale data, or both
- optimistic updates have cancellation, snapshot, rollback, and settlement behavior
- SSR uses request-scoped QueryClients and hydration deliberately
- Start server functions enforce server-side auth and Query handles client cache
- tests cover the cache behavior users can observe
