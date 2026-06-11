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
- leaking hidden/private/internal fields
- making the client depend on relation names or serialization accidents

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
