# AdonisJS 7 anti-patterns

Treat these as warning signs or default review targets.

## Generic Node drift

- building features as if the app were Express with extra files
- adding custom wrappers around framework primitives without a real benefit
- hiding framework concepts behind vague internal abstractions

## Validation drift

- manual input checks inside controllers
- trusting TypeScript types without Vine runtime validation
- validating body but forgetting params/query

## Persistence drift

- raw SQL by default where Lucid is sufficient
- query logic duplicated across many files
- database writes spread across controllers and helpers without transactions

## Auth drift

- custom token/session logic duplicating Adonis auth
- authorization checks implicit or inconsistent
- sensitive actions lacking denial-path tests

## Config drift

- feature code reading `process.env` directly
- multiple files inventing their own defaults for the same setting

## Architectural drift

- fat controllers
- god services
- domain logic hidden in middleware
- provider responsibilities spread outside providers
- events/listeners used as hidden primary flow

## Contract drift

- returning raw model instances as public API by default
- hand-built DTOs/arrays where the v7 Transformer layer gives a typed, stable contract
- leaking hidden/private/internal fields
- making the client depend on relation names or serialization accidents

## Security and rate-limiting drift

- sensitive endpoints (login, signup, reset, paid actions) with no rate limiting via `@adonisjs/limiter`
- open redirects or hand-rolled referrer/back bounce logic that skips host validation
- disabling the v7 UUID upload-rename default or accepting client-provided filenames blindly
- accepting arbitrary user input in ways that bypass the `$`-key mass-assignment protection in `fill`/`merge`/`create`
- secrets stored without the env `schema.secret()` type, leaking through logs or serialization
- third-party cache/lock/SSE packages where `@adonisjs/cache`, `@adonisjs/lock`, or `@adonisjs/transmit` covers the need

## Background-work drift

- a third-party or hand-rolled queue/worker where the first-party experimental `@adonisjs/queue` covers the need and the project accepts its API-stability trade-off
- background jobs with no retry, failure hook, or visibility path
- duplicate job storms on retried webhooks/HTTP without dispatch-time dedup when it fits

## Testing drift

- only happy-path coverage
- no tests for validation/auth/transactions
- tests asserting implementation trivia instead of observable behavior

## Review rule

If an anti-pattern appears, identify:
1. the drift,
2. the missed Adonis primitive,
3. the risk,
4. the smallest idiomatic correction.
