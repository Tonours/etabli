# Contract patterns for AdonisJS 7 + Tuyau 1.x

Use this file when designing a typed endpoint contract.

## Core rule

A strong contract needs three aligned layers:
- runtime validation,
- explicit response shaping,
- typed client consumption.

In v7 these layers are wired together by the framework: Vine validates input, the Transformer layer (`@adonisjs/core/transformers` + `serialize()`) shapes output, and the generated Tuyau registry turns that output into typed client types. If one layer is weaker than the others, the contract is unsafe. Optional `@tuyau/superjson` preserves rich runtime types across the wire when JSON stringification would otherwise erase them.

## Stable endpoint pattern

- validate body/query data with Vine through `request.validateUsing()` so Tuyau can infer the accepted shape; route params remain typed from the route pattern and still need runtime constraints when their semantics demand more than a string
- keep controller as the route boundary
- perform persistence through Lucid or domain actions
- shape the response through a transformer (registered via the `generateRegistry` hook so it reaches the client)
- let Tuyau expose the trustworthy contract to clients from the generated registry
- test invalid input and stable success payload
- expose and test meaningful typed failure payloads when clients branch on them

## Mutation endpoint pattern

- validate body explicitly
- perform auth and authorization explicitly
- use transactions where consistency matters
- return a stable success or failure shape
- keep client-side error handling typed with `.safe()`, `isStatus()`, or `isValidationError()` when applicable
- test denial and validation paths

## List endpoint pattern

- validate query params
- make pagination/filter semantics explicit
- return deliberate list metadata and item shape
- do not leak raw relation trees casually

## Review questions

- does runtime validation really match the inferred type?
- is the response shaped intentionally?
- is the client depending on incidental serialization?
- would a model change break the contract unexpectedly?
