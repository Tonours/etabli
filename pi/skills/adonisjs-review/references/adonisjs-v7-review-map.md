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

## If you see `process.env` inside feature code

Check whether config/env files should own the setting.

## If you see huge controllers

Check whether orchestration should move into actions/services while keeping validation and HTTP boundaries clean.

## If you see generic Node patterns

Check whether the code ignored a documented Adonis convention for:

- routing
- middleware
- providers
- validation
- ORM
- auth
- mail
- testing
- commands/scheduler/events

## High-value review comments

Prefer comments that identify:

1. the current smell,
2. the missed Adonis primitive,
3. the risk created,
4. the smallest idiomatic fix.
