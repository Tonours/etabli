# AdonisJS Tuyau examples and prompts

Use these prompts to trigger safe Tuyau v1.2 work in an AdonisJS 7 application.

## Build prompts

- Implement this typed endpoint with AdonisJS 7 + Tuyau v1.2. Keep Vine as validation authority and make the response contract explicit and stable.
- Add a Tuyau endpoint and typed client flow, but stop if the design leaks Lucid internals or depends on unstable serialization.
- Refactor this Tuyau route so the backend remains idiomatic AdonisJS and the client contract stays trustworthy.

## Review prompts

- Review this Tuyau endpoint as a contract safety harness. Check validation, response stability, client coupling, and tests.
- Audit this typed API flow and block it if typing is stronger than runtime guarantees.
- Check whether this Tuyau usage bypasses normal Adonis route/controller/validator boundaries.

## Example asks

### Typed list endpoint

Add a typed list endpoint with:
- query validation through Vine,
- pagination,
- explicit response shape,
- typed consumer usage,
- tests for invalid query and success payload.

### Typed mutation

Implement a typed mutation endpoint with:
- body validation in Vine,
- auth check,
- Lucid persistence,
- explicit success/error response contract,
- test coverage for validation and authorization failure.

### Contract audit

Review this Tuyau implementation and answer:
- Is validation authoritative?
- Is the response stable?
- Could a Lucid model change break the client?
- Is the contract safe to ship?
