# Serialization and DTO policy for AdonisJS 7

Use this file when deciding what crosses the API boundary.

## Core rule

Treat response shape as a deliberate contract.
Do not let database structure define the public API by accident.

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
- should this response be normalized into an explicit object?
- are computed fields and hidden fields understood?

## Anti-patterns

- returning model instances by habit
- exposing everything because serialization makes it easy
- letting typed clients depend on unstable relation trees
- changing response shape without contract-sensitive tests
