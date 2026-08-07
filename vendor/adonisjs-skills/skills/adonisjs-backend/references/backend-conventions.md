# Backend conventions for AdonisJS 7

## General

- Favor convention over invention.
- Prefer explicit, framework-native structure over clever abstractions.
- Keep files near the framework locations expected by Adonis.
- Match local naming conventions if already coherent.

## Controllers

- Keep controllers thin and action-oriented.
- Validate early.
- Delegate business work out of the controller.
- Avoid inline query building unless trivial.

## Domain and services

- Create dedicated actions/services for business workflows that span multiple concerns.
- Keep responsibilities narrow.
- Do not dump unrelated behavior into a single catch-all service.

## Validation with Vine

- Use Vine for payload shape, coercion, and constraints.
- Name validators after intent.
- Keep validator messages and transforms explicit when important.

## Lucid ORM

- Use models and relationships first.
- v7 is migrations-first: extend generated schema classes (`#database/schema`) instead of redeclaring columns with `@column`.
- Use scopes for reusable filters.
- Use preload/pagination to avoid N+1 and manual glue code.
- Use hooks sparingly and only for model-centric behavior.
- Keep migrations small, reversible, and obvious.

## Mail

- Use Adonis Mail for mailers/templates/send flow.
- Keep mail trigger points explicit.
- Avoid embedding delivery code in unrelated layers.

## Response and serialization

- Shape API output through the v7 Transformer layer (`@adonisjs/core/transformers`), exposed via the `serialize()` helper on `HttpContext`.
- Keep models persistence-only; let transformers own the public contract.
- Do not return raw model instances as the API shape by default.

## Background work

- Use the first-party experimental `@adonisjs/queue` for background jobs (`Job<T>`, `dispatch()`, worker with heartbeats, scheduler, dedup when retries can double-enqueue) when the project accepts its API-stability trade-off; pin the package while experimental.
- Use commands for operator tasks and the queue scheduler for recurring jobs.
- Prefer the official queue over third-party or hand-rolled workers.
- Prefer first-party `@adonisjs/cache`, `@adonisjs/lock`, and `@adonisjs/transmit` for caching, mutexes, and SSE push.

## Config and env

- Read configuration from Adonis config/env mechanisms.
- Avoid scattered raw `process.env` reads in feature code.
- Keep config names descriptive and grouped by concern.

## Error handling

- Use exceptions and framework handling consistently.
- Avoid inconsistent controller-level ad hoc error payloads.
- Normalize domain failures intentionally.

## Tests

- Add tests for behavior, not only coverage optics.
- Cover happy path, validation failure, auth/authorization failure, and important persistence side effects.
- Prefer integration tests for HTTP endpoints.

## Smells to flag

- Hand-written validation inside controllers
- Raw SQL where Lucid is sufficient
- Framework bypass through arbitrary utility layers
- Mixed transport and persistence concerns
- Repeated env access in domain code
- Massive services/controllers
- Missing tests around auth, validation, or transactions
