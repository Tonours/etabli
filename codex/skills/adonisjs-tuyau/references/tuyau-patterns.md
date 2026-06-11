# Tuyau v1.2 patterns with AdonisJS 7

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

## Output contracts

- Return stable shapes.
- Prefer explicit serialized objects when model fields or relations may drift.
- Avoid exposing internal-only fields by accident.

## Backend and frontend coupling

- Let Tuyau reduce duplication, not eliminate design discipline.
- If the frontend depends on a field, make that field part of the intentional contract.
- If the contract changes, update tests and consumers together.

## Lucid interaction

- Use Lucid for data access, but do not expose raw model instances as public API shape unless the project deliberately standardizes that.
- Be careful with serialization, hidden fields, relations, and computed properties.

## Testing focus

- Validate request failures.
- Validate success response shape.
- Validate breaking contract changes where possible.
- Cover auth-sensitive or policy-sensitive typed endpoints.
