# Tuyau 1.x patterns with AdonisJS 7

## Core principle

Tuyau should strengthen a well-structured AdonisJS API. It should not become an excuse to skip validation, HTTP semantics, or stable response design.

## Good pattern

- Route defined clearly
- Controller/action owns HTTP orchestration
- Vine validates input
- Domain/action layer performs work
- Response shape is explicit
- Tuyau exposes trustworthy inferred types to the client

## Input contracts

- Use Vine as the authoritative validator.
- Keep params, query, and body rules explicit.
- Prefer deliberate coercion over loose acceptance.
- Use the request validation path that Tuyau can infer from; if the backend skips typed request validation, the client contract becomes weaker than it looks.

## Output contracts

- Return stable shapes through the v7 Transformer layer — transformer output becomes the response type the Tuyau client consumes.
- Prefer transformer-backed shapes when model fields or relations may drift.
- Avoid exposing internal-only fields by accident.

## Backend and frontend coupling

- v7 ships Tuyau as a first-party type-safe API client: the backend exports a generated registry, the frontend imports it via `@tuyau/core/client` (`createTuyau`), and `@tuyau/react-query` or `@tuyau/vue-query` wires it into TanStack Query (use the framework-specific package names on npm, not a generic tanstack package rename).
- Prefer generated helpers over duplicated types: `client.api.*`, `client.request(...)`, `client.urlFor`, route introspection (`has` / `current`), and the `Path.*` / `Route.*` type helpers all come from the registry.
- Handle typed failures intentionally with `.safe()`, `error.isStatus(...)`, and `error.isValidationError()` when the endpoint exposes meaningful non-2xx responses.
- Branch on `error.kind === 'network'` when transport recovery differs from handling an HTTP response; network failures have no status or response payload.
- When rich JS types must survive the HTTP boundary, prefer `@tuyau/superjson` (server middleware + client plugin) over a custom codec; teach SuperJSON any Luxon/custom classes both sides.
- Let Tuyau reduce duplication, not eliminate design discipline.
- If the frontend depends on a field, make that field part of the intentional contract (a transformer), not an incidental model field.
- If the contract changes, update tests and consumers together.

## TanStack Query integration

- Use `@tuyau/react-query` or `@tuyau/vue-query` and keep its major/prerelease tag compatible with `@tuyau/core`.
- Generate `queryOptions()`, `mutationOptions()`, and `infiniteQueryOptions()` from route names instead of duplicating query functions or keys.
- Let TanStack Query own retries; the adapters disable Ky retries to prevent compounded attempts.
- Use `queryKey()` for one exact query, `pathKey()` for one endpoint, and `pathFilter()` only when a mutation can stale a broader route subtree.
- Match `pageParamKey` to the Vine-validated pagination query field for infinite queries.

## Lucid interaction

- Use Lucid for data access, but do not expose raw model instances as public API shape unless the project deliberately standardizes that.
- Be careful with serialization, hidden fields, relations, and computed properties.

## Testing focus

- Validate request failures.
- Validate success response shape.
- Validate breaking contract changes where possible.
- Cover auth-sensitive or policy-sensitive typed endpoints.
- Cover important typed error branches, especially validation errors and authorization failures.
