# Serialization and DTO policy for AdonisJS 7

Use this file when deciding what crosses the API boundary.

## Core rule

Treat response shape as a deliberate contract.
Do not let database structure define the public API by accident.

## v7 Transformer layer

AdonisJS 7 separates persistence from presentation with a first-party Transformer layer (`@adonisjs/core/transformers`):

- a transformer extends `BaseTransformer` and defines the output shape in `toObject`
- the `serialize()` helper on `HttpContext` exposes the transformed result as a response (confirmed first-party path)
- variants, conditional relations (`whenLoaded`), and paginated helpers keep contracts intentional across list/detail views
- transformer output becomes the typed contract consumed by Inertia and the Tuyau client
- when Date/Map/Set/Luxon must survive the wire for Tuyau clients, prefer `@tuyau/superjson` over a custom codec

Prefer a transformer over a hand-built DTO: it is the framework-native way to make this policy explicit and type-checked. Models stay persistence-only.

## When explicit DTO-like shaping is strongly preferred

- multiple clients depend on the endpoint
- the endpoint is long-lived
- the model contains hidden, internal, or unstable fields
- relations may evolve over time
- Tuyau or typed clients depend on the shape

## Returning models directly

Only accept this when all of the following are true:
- the shape is intentionally stable,
- hidden/private fields are controlled,
- relation exposure is deliberate,
- the endpoint is not likely to drift quickly.

## Review questions

- is the client depending on incidental model shape?
- would a Lucid relation rename break the contract?
- should this response go through a transformer instead of a raw model?
- are computed fields and hidden fields understood?

## Anti-patterns

- returning model instances by habit
- hand-built DTOs/arrays where a transformer gives a typed, stable contract
- exposing everything because serialization makes it easy
- letting typed clients depend on unstable relation trees
- changing response shape without contract-sensitive tests
