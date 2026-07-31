# Lucid ORM deep dive for AdonisJS 7

Use this file when persistence design or review is the hard part.

## Default Lucid policy

Prefer Lucid models, relationships, scopes, preload, aggregates, pagination, and transactions before raw SQL.

## Relationships

- model relationships explicitly
- keep relationship naming clear and predictable
- preload deliberately to avoid N+1 patterns
- avoid leaking relation structure directly into public contracts by accident

## Scopes and reusable queries

- move repeated filters into scopes when they represent stable query concepts
- avoid copying the same query chains across controllers and services

## Hooks

- use model hooks sparingly for model-centric behavior
- do not hide large cross-domain workflows in hooks

## Transactions

- use transactions for multi-write workflows or consistency-sensitive updates
- be clear about transaction boundaries
- avoid side effects that should only occur after a successful commit

## Raw SQL rule

Use raw SQL only when:
- Lucid or the query builder is clearly insufficient,
- the need is performance-justified or query-shape-specific,
- the reason is explained in code or review notes.

## Serialization and response safety

- do not return raw model instances casually
- review hidden fields, computed properties, and relations before exposing output
- prefer explicit response shaping when the API is long-lived or client-critical

## Review questions

- should this query become a scope?
- is preload missing where relation access is repeated?
- is raw SQL actually necessary?
- is transaction coverage adequate?
- could serialization leak internals?
