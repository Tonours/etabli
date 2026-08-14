# AdonisJS 7 review map

Use this map to spot missed framework opportunities.

## If you see manual request parsing

Check whether Vine should own validation and normalization.

## If you see repeated SQL-heavy services

Check whether Lucid models, relationships, scopes, preload, query builder, or transactions would simplify the code.

## If you see custom auth/token logic

Check whether official auth guards/providers already cover the need.

## If you see raw SMTP or mail wrappers

Check whether Adonis Mail should replace it.

## If you see hand-built response objects or raw model dumps

Check whether the v7 Transformer layer (`@adonisjs/core/transformers`) should own the response contract.

## If you see a custom queue or background worker

Check whether the first-party experimental `@adonisjs/queue` (`Job<T>`, `dispatch()`, worker, scheduler, dedup) covers the need and whether the project accepts its API-stability trade-off.

## If you see a sensitive endpoint with no rate limiting

Check whether `@adonisjs/limiter` (`limiter.multi()` + `.penalize()`, weighted when cost varies) should guard it.

## If you see custom return-to or referrer redirects after login

Check whether auth/session intended-URL storage and open-redirect-safe helpers should own the bounce.

## If you see a third-party cache, lock, or SSE stack

Check whether `@adonisjs/cache`, `@adonisjs/lock`, or `@adonisjs/transmit` covers the need.

## If you see ad hoc logging standing in for tracing

Check whether `@adonisjs/otel` should provide structured traces instead.

## If you see `process.env` inside feature code

Check whether config/env files should own the setting.

## If you see huge controllers

Check whether orchestration should move into actions/services while keeping validation and HTTP boundaries clean.

## If you see generic Node patterns

Check whether the code ignored a documented Adonis convention for:

- routing (auto-naming, barrel files, `urlFor`)
- middleware
- providers and `adonisrc.ts` hooks
- validation
- ORM (schema classes)
- auth
- authorization and rate limiting
- mail
- serialization (Transformers + `serialize()`)
- background work (queues)
- cache / locks / transmit / core and integration health checks
- observability (`@adonisjs/otel`)
- testing
- commands/scheduler/events

## High-value review comments

Prefer comments that identify:

1. the current smell,
2. the missed Adonis primitive,
3. the risk created,
4. the smallest idiomatic fix.
