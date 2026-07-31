# AdonisJS 7 module map

Use this file to map a problem to the closest AdonisJS 7 primitive before designing custom code.

## Core mindset

AdonisJS aims to be a batteries-included backend framework, closer to Laravel-style conventions than to a minimal Express setup. Prefer the official module or framework convention first.

## HTTP and application flow

- Routing: define endpoints, group middleware, name resources cleanly.
- Controllers: coordinate request -> validation -> domain action -> response.
- Middleware: cross-cutting HTTP concerns only.
- Exception handling: use the framework error pipeline instead of ad hoc response logic.
- Providers: register framework services and app bootstrapping.

## Validation

- Vine is the default validation layer.
- Use Vine schemas/validators for request payloads, params, query strings, and structured input normalization.
- Do not hand-roll validation unless the case is truly outside Vine.

## Database and ORM

- Lucid ORM is the primary persistence model.
- Migrations define schema changes.
- Seeders populate known data.
- Models express relationships, hooks, serialization, and reusable query logic.
- Query builder covers complex queries when model APIs are not enough.
- Transactions protect multi-step writes.

## Authentication and authorization

- Use official auth capabilities and guards for session/token flows.
- Keep authorization in the framework-approved layer used by the project, commonly Bouncer or equivalent policy/gate style.
- Do not create parallel auth systems.

## Mail and notifications

- Mail handles email composition and delivery.
- Keep mailers/templates and trigger boundaries explicit.
- Do not introduce ad hoc SMTP wrappers if Mail covers the use case.

## Files, storage, and uploads

- Use Drive or the project's Adonis-aligned storage path.
- Keep upload validation at the request boundary.
- Keep storage concerns out of controllers when workflows grow.

## Security primitives

- Hashing: use the official hashing package.
- Encryption: use framework primitives for secrets or encrypted payloads.
- Auth secrets/tokens: stay inside the official auth setup.

## Social auth and integrations

- Ally covers provider-based social authentication when needed.
- Providers register or configure integrations cleanly.

## Async and lifecycle

- Events/listeners: domain and application reactions.
- Scheduler/commands: recurring work and operational tasks.
- Jobs/queues: use the project's chosen setup, but prefer official or framework-aligned integrations.
- Providers own boot-time wiring.

## Config and environment

- Centralize env reads and validation.
- Expose runtime values through config modules.
- Avoid scattered `process.env` access.

## Testing

- Functional/integration tests for routes, middleware, auth, validation, and persistence behavior.
- Factories and seeders for realistic data setup.
- Unit tests for isolated domain logic only when useful.

## Response and serialization

- Treat response shape as an explicit contract.
- Do not expose raw model internals accidentally.
- Normalize output when relations, hidden fields, or computed properties could drift.

## Convention checks

Ask these questions during implementation:

1. Is there an official Adonis module for this?
2. Is this concern placed at the right layer?
3. Does validation live in Vine?
4. Does persistence use Lucid before raw SQL?
5. Are auth, mail, config, env, and lifecycle concerns handled by framework primitives?
6. Is the naming aligned with the framework and the current app style?
7. Would this choice reduce or increase framework drift over time?
