# AdonisJS 7 module playbooks

Use these playbooks to choose the correct AdonisJS path quickly.

## Routes and controllers

Use when exposing or changing HTTP behavior.

### Default path

- declare the route clearly; rely on v7 auto-naming (`controller.method`) instead of manual `.as()`
- import controllers/events/policies from the generated barrel (`#generated/*`) rather than hand-written lazy imports
- build URLs with the type-safe `urlFor` helper, not the deprecated `router.makeUrl`
- attach middleware explicitly
- keep controller methods action-oriented
- validate at the boundary
- delegate business workflow out of the controller
- return a deliberate response shape

### Watch for

- controllers doing validation inline
- controllers building complex SQL directly
- controllers branching on unrelated concerns
- hand-built URL strings where `urlFor` exists

## Vine validation

Use when accepting body, params, query, or uploaded data.

### Default path

- create a validator/schema per use case or boundary
- validate body, params, and query deliberately
- use coercion intentionally
- keep accepted shape explicit

### Watch for

- manual `request.input()` checks spread through code
- weak validation hidden behind TypeScript types
- inconsistent validation between similar endpoints

## Lucid ORM

Use when reading or writing persistence state.

### Default path

- v7 is migrations-first: run migrations, then extend the generated schema class (`#database/schema`) instead of redeclaring columns with `@column`
- model relationships explicitly
- use scopes for reusable filters
- use preload/pagination/aggregates instead of manual glue
- use transactions for multi-step writes
- keep migrations focused and reversible

### Watch for

- raw SQL used by default
- duplicated query logic across services/controllers
- response contracts tied directly to model internals
- redeclared columns that drift from the migration

## Auth and authorization

Use when protecting endpoints or actions.

### Default path

- use the project guard strategy; v7 simplifies `withAuthFinder(hash)` (defaults to `email`/`password`)
- authenticate at the right boundary
- prefer `user.validatePassword()` and `auth.checkUsing()` over hand-rolled checks
- use framework intended-URL redirect storage after unauthorized access instead of custom return-to hacks
- perform authorization explicitly on sensitive actions
- test denial paths, not only success paths

### Watch for

- custom token parsing when official auth already covers it
- open redirects or hand-rolled referrer-based bounce logic
- implicit authorization hidden in unrelated code
- missing tests for access control

## Rate limiting

Use when protecting sensitive or abuse-prone endpoints (login, signup, password reset, paid actions).

### Default path

- use the first-party `@adonisjs/limiter`
- combine several limiters in one call with `limiter.multi()` (e.g. per-IP and per-IP+email), coordinated via `.penalize()`
- use weighted limiting when one action should cost more than a single hit
- apply limiting at the route or controller boundary

### Watch for

- endpoints with no limiting where brute force or credential stuffing is possible
- hand-rolled counters where the limiter exists
- limiting applied inconsistently across equivalent endpoints

## Mail

Use when sending transactional or workflow emails.

### Default path

- validate input first
- persist state if needed
- compose/send through Adonis Mail
- trigger at a visible workflow boundary

### Watch for

- SMTP wrappers or random SDK calls when Mail is enough
- mail sends hidden inside unrelated model code

## Providers

Use when registering services, bindings, boot wiring, or startup logic.

### Default path

- keep registration and boot responsibilities explicit
- centralize startup behavior in providers
- register type-safety and indexing via the `adonisrc.ts` init hooks (`indexEntities`, `generateRegistry` for Tuyau, `indexPolicies` for Bouncer)
- avoid side effects in random imports

### Watch for

- hidden boot logic in module top-level code
- feature setup scattered through controllers/services
- missing `indexEntities` hook (always required in v7)

## Events and listeners

Use for coherent reactions after a domain/application event.

### Default path

- emit from a visible workflow point
- keep listeners focused
- keep the main business flow explicit even if listeners exist

### Watch for

- events used to hide primary business logic
- listeners creating surprising side effects without tests

## Commands, scheduler, and queues

Use for operator tasks, maintenance, cleanup, imports, recurring work, and background jobs.

### Default path

- put operational entry points in commands
- use the first-party experimental `@adonisjs/queue` for background jobs: typed `Job<T>` classes, `dispatch()` / `dispatchMany()`, a worker process (`queue:work`) with heartbeats for long jobs, Redis/Database/Sync adapters, retries/backoff, batching, and dispatch-time dedup when retries can double-enqueue
- use the queue scheduler (`start/scheduler.ts`) for recurring jobs (cron or interval)
- when Ace commands dispatch under the sync adapter, load job locations before dispatching
- reach for the official queue before any third-party or project-native integration; pin the package while it is experimental
- keep execution entry points explicit and observable

### Watch for

- cron-like logic hidden in web requests
- recurring behavior buried in imports or providers without clarity
- a custom queue/worker setup where `@adonisjs/queue` covers the need and the project accepts its experimental API surface
- async work with no clear failure, retry, or visibility path
- duplicate job storms on webhook/HTTP retries when `.dedup()` would fit

## Config and env

Use for runtime settings, secrets, limits, provider config, and feature flags.

### Default path

- validate env centrally; use `schema.secret()` for sensitive values and the `file:` modifier for file-backed secrets
- expose settings through config
- consume config in feature code, not raw env

### Watch for

- `process.env` in controllers/services/models
- inconsistent default values across files
- secrets that can leak through logging or serialization

## Response and serialization

Use whenever data crosses the API boundary.

### Default path

- use the v7 Transformer layer (`@adonisjs/core/transformers`): define output shape in `toObject`, expose via the `serialize()` helper on `HttpContext`
- keep models persistence-only; let transformers own presentation
- prefer variants, `whenLoaded` relations, and paginated transformer helpers over ad hoc shaping
- serialize only what the client should depend on
- avoid leaking private fields or unstable relations

### Watch for

- returning raw model instances casually
- hand-built DTOs/arrays where a transformer gives a typed, stable contract
- exposing fields because they happen to exist rather than by contract

## Observability

Use when you need to understand request flow, latency, or failures across middleware, DB, and external calls.

### Default path

- install `@adonisjs/otel` and point it at an OTel-compatible backend (Jaeger, Tempo, Datadog, Honeycomb)
- prefer the framework's diagnostic channels over custom instrumentation where available

### Watch for

- ad hoc logging masquerading as tracing
- missing tracing on flows that are hard to reproduce locally

## Cache, locks, transmit, and health

Use when caching results, serializing critical sections, pushing realtime updates, or exposing probes.

### Default path

- cache through `@adonisjs/cache` before inventing a store wrapper
- mutex/critical sections through `@adonisjs/lock`
- server-to-client push through `@adonisjs/transmit` (SSE) when full websockets are unnecessary
- readiness-style checks through the framework health module instead of ad hoc `/health` hacks

### Watch for

- third-party cache/lock/SSE packages where the first-party module covers the need
- health endpoints that only check process uptime and ignore DB/redis/queue dependencies

## Testing

Use for every change that affects behavior.

### Default path

- add integration/functional tests for HTTP flows
- cover validation failure, auth failure, and happy path
- add transaction-sensitive or side-effect-sensitive tests where needed
- assert dispatched jobs with the queue fake (`QueueManager.fake()`, `assertPushed` / `assertNotPushed` / `assertPushedCount` / `assertNothingPushed`)
- use factories/seeders when realistic setup helps

### Watch for

- tests that only cover success paths
- unit tests replacing more valuable integration checks
- brittle assertions on internal implementation details
