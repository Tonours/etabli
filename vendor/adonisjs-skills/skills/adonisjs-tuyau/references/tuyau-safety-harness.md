# Tuyau v1.2 safety harness

Use this before and after any contract change.

## Runtime over type illusion

Type inference is not enough.
A contract is safe only if runtime validation, serialization, and HTTP semantics match what the client believes.

## Required checks

1. Is input validation enforced with Vine?
2. Are params, query, and body all validated at the boundary?
3. Is the response shape intentional rather than incidental?
4. Could a Lucid model change break the client unexpectedly?
5. Are hidden fields, computed props, and relations controlled deliberately?
6. Does the endpoint remain understandable without knowing Tuyau internals?
7. Are typed error branches handled deliberately when clients depend on them?
8. Is there at least one contract-sensitive test?

## Recommended response policy

In v7, "explicit serialized objects" means the Transformer layer (`@adonisjs/core/transformers`) exposed through `serialize()`: its output is the type the Tuyau client depends on, so a transformer is the safest way to make a contract stable by design. Use `@tuyau/superjson` only when rich types must survive the wire; still keep transformers as the shape authority.

Prefer transformer-backed responses when:

- the endpoint is shared by multiple clients,
- the model includes private or unstable fields,
- relations may evolve,
- the contract is business-critical.

## Smells

- relying on raw model serialization by default,
- letting inferred client types outrun backend validation,
- treating `.safe()` or `isStatus()` branches as optional when the UI depends on failure payloads,
- spreading contract assumptions into frontend code without tests,
- using Tuyau to hide weak controller/service boundaries.

## Final question

If the backend model changed tomorrow, would the client contract remain stable by design? If not, block or redesign before shipping.
