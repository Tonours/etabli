# Contract patterns for AdonisJS 7 + Tuyau v1.2

Use this file when designing a typed endpoint contract.

## Core rule

A strong contract needs three aligned layers:
- runtime validation,
- explicit response shaping,
- typed client consumption.

If one layer is weaker than the others, the contract is unsafe.

## Stable endpoint pattern

- validate params/query/body with Vine
- keep controller as the route boundary
- perform persistence through Lucid or domain actions
- shape the response explicitly
- let Tuyau expose the trustworthy contract to clients
- test invalid input and stable success payload

## Mutation endpoint pattern

- validate body explicitly
- perform auth and authorization explicitly
- use transactions where consistency matters
- return a stable success or failure shape
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
