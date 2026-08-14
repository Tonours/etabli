# AdonisJS 7 module map

Use this file to map a problem to the closest AdonisJS 7 primitive before designing custom code.

## Core mindset

AdonisJS aims to be a batteries-included backend framework, closer to Laravel-style conventions than to a minimal Express setup. Prefer the official module or framework convention first. v7 added several first-party packages — reach for them before any third-party or hand-rolled equivalent.

## Runtime and tooling baseline

- AdonisJS 7 requires Node.js 24+ and npm 11+, supports TypeScript 5.9 or 6.0 with ESLint 10, and uses Vite 7 when Vite is in play. Check the project's actual toolchain before diagnosing v7-only failures as application bugs.

## HTTP and application flow

- Routing: define endpoints, group middleware, name resources cleanly. v7 auto-names controller-backed routes (`controller.method`) and exposes controllers/events/policies through generated barrel files (`#generated/*`), so prefer the barrel import over manual lazy imports.
- URL building: use the type-safe `urlFor` helper (`@adonisjs/core/services/url_builder`) instead of the deprecated `router.makeUrl`. Use `signedUrlFor` plus `request.hasValidSignature()` when externally shared URLs need tamper protection. The Edge `route()` helper is also replaced by `urlFor`.
- Controllers: coordinate request -> validation -> domain action -> response. They may return platform-native `Response` instances directly (e.g. streaming from an AI SDK) — no manual conversion needed.
- Middleware: cross-cutting HTTP concerns only.
- Exception handling: use the framework error pipeline instead of ad hoc response logic. Status pages are skipped for JSON `Accept` clients; HTML exception messages are escaped.
- Redirect safety: prefer framework redirect helpers; open-redirect hardening and `isValidRedirectUrl` exist on the HTTP layer — do not hand-roll referrer/back redirects.
- Providers: register framework services and app bootstrapping.
- Wiring: v7 registers type-safety and indexing via `adonisrc.ts` init hooks (`indexEntities` always; `generateRegistry` for Tuyau; `indexPolicies` for Bouncer; `indexPages` for Inertia) and a `buildStarting` hook for Vite.

## Validation

- Vine is the default validation layer.
- Use Vine schemas/validators for request payloads, params, query strings, and structured input normalization.
- Do not hand-roll validation unless the case is truly outside Vine.

## Database and ORM

- Lucid ORM is the primary persistence model.
- v7 is migrations-first: after migrations run, Lucid generates strongly typed schema classes (`#database/schema`). Models extend the schema class and inherit column definitions — stop redeclaring columns with `@column`.
- Migrations define schema changes. `make:migration` auto-detects create vs alter from the name.
- Seeders populate known data.
- Models express relationships, hooks, serialization, and reusable query logic.
- Query builder covers complex queries when model APIs are not enough.
- Transactions protect multi-step writes.

## Authentication and authorization

- Use official auth capabilities and guards for session/token flows.
- v7 auth helpers: `withAuthFinder(hash)` (defaults to `email`/`password`), `user.validatePassword()`, `auth.checkUsing()` for multiple guards, `TokensProvider.deleteAll()`.
- Unauthorized redirects can store the intended URL (auth + session helpers) — prefer that path over custom return-to query hacks.
- Keep authorization in the framework-approved layer used by the project, commonly Bouncer or equivalent policy/gate style.
- Do not create parallel auth systems.

## Mail and notifications

- Mail handles email composition and delivery. v7 lets you set the default sender from env (`MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME`).
- Keep mailers/templates and trigger boundaries explicit.
- Do not introduce ad hoc SMTP wrappers if Mail covers the use case.

## Files, storage, and uploads

- Use Drive or the project's Adonis-aligned storage path.
- Keep upload validation at the request boundary.
- v7 hardening: `MultipartFile.move()` renames files with a random UUID by default (the client filename is ignored unless explicitly accepted). Keep this default.
- Keep storage concerns out of controllers when workflows grow.

## Security primitives

- Hashing: use the official hashing package.
- Encryption: v7 has a dedicated `config/encryption.ts` with multiple named drivers (`aes256gcm`, `aessiv` for deterministic/searchable encryption, `legacy` for v6 data) and key rotation. The `APP_KEY`-from-`config/app.ts` path no longer encrypts.
- Rate limiting: use the first-party `@adonisjs/limiter`. `limiter.multi()` checks several limiters (e.g. per-IP and per-IP+email) in one call with `.penalize()`. Weighted limiting is supported when cost is not one-per-hit.
- Atomic locks: use `@adonisjs/lock` for mutex/critical sections instead of inventing Redis locks.
- Caching: use `@adonisjs/cache` (Redis/DB/file/memory) before ad hoc cache layers.
- Mass-assignment safety: v7 silently ignores `$`-prefixed keys in `fill`/`merge`/`create`, protecting Lucid internals. Keep this default; never disable it to accept arbitrary input.
- Auth secrets/tokens: stay inside the official auth setup. Use the env `schema.secret()` type for sensitive values so they redact from logs and serialization.

## Social auth and integrations

- Ally covers provider-based social authentication when needed.
- Providers register or configure integrations cleanly.

## Async and lifecycle

- Events/listeners: domain and application reactions.
- Scheduler/commands: recurring work and operational tasks.
- Jobs/queues: v7 ships the first-party `@adonisjs/queue` (experimental). Jobs are typed `Job<T>` classes dispatched via `dispatch()` / `dispatchMany()`, run by a worker (`queue:work`) with heartbeats for long jobs, Redis/Database/Sync adapters, retries/backoff, batching, dispatch-time dedup (`.dedup()`), and scheduling (`start/scheduler.ts`). Ace commands that dispatch under the sync adapter should load jobs first. Reach for it before any third-party or hand-rolled queue, but pin the package and treat API drift as possible while it remains experimental.
- Realtime push: `@adonisjs/transmit` (SSE) for server-to-client streams when websockets are overkill.
- Health: core checks from `@adonisjs/core/health` plus integration-specific checks such as `RedisCheck` from `@adonisjs/redis` for readiness/liveness probes.
- Providers own boot-time wiring.

## Config and environment

- Centralize env reads and validation.
- v7 env DX: `schema.secret()` for secrets, `file:` modifier for file-backed secrets (Docker Secrets, Vault).
- Expose runtime values through config modules.
- Avoid scattered `process.env` access.

## Observability

- Use `@adonisjs/otel` for zero-config OpenTelemetry tracing (per-request timelines: middleware, DB queries, external calls). The framework is adding low-overhead diagnostic channels across packages.

## Testing

- Functional/integration tests for routes, middleware, auth, validation, and persistence behavior.
- v7 queues ship a fake adapter (`QueueManager.fake()`, `assertPushed` / `assertNotPushed` / `assertPushedCount` / `assertNothingPushed`) to assert dispatched jobs without running them.
- Factories and seeders for realistic data setup.
- Unit tests for isolated domain logic only when useful.

## Response and serialization

- v7 separates persistence from presentation via Transformers (`@adonisjs/core/transformers`): a transformer extends `BaseTransformer`, defines the output shape in `toObject`, and is exposed through the `serialize()` helper on `HttpContext`. Models stay persistence-only.
- Prefer variants (`useVariant`), conditional relations (`whenLoaded`), and paginated transformer helpers over ad hoc shaping.
- Transformer output is the single source of truth for response shape and is turned into client types used by Inertia and the Tuyau client.
- Treat response shape as an explicit contract; do not return raw model instances casually.
- Normalize output when relations, hidden fields, or computed properties could drift.
- When rich JS types must survive the HTTP boundary for Tuyau clients, prefer `@tuyau/superjson` over inventing a custom codec.

## Content and rendering

- For Edge apps: `edge-markdown` renders Markdown (MDC syntax) inside templates; `@adonisjs/content` provides typed collections of static data (VineJS schemas, JSON/GitHub loaders) for docs/blog/catalog content. Use these instead of bolting on a CMS.

## Convention checks

Ask these questions during implementation:

1. Is there an official Adonis module for this — including the v7 first-party set (queue, limiter, otel, transformers, content, cache, lock, transmit, and core/integration health checks)?
2. Is this concern placed at the right layer?
3. Does validation live in Vine?
4. Does persistence use Lucid (schema classes) before raw SQL?
5. Are auth, mail, config, env, encryption, and lifecycle concerns handled by framework primitives?
6. Is the response shape a transformer-backed contract rather than an accidental model dump?
7. Are redirects, rate limits, and secrets using the hardened framework paths?
8. Is the naming aligned with the framework and the current app style?
9. Would this choice reduce or increase framework drift over time?
