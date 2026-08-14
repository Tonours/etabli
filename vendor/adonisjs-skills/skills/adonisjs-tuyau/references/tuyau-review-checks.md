# Tuyau review checks

## Contract integrity

- Does the backend truly enforce the shape the frontend trusts?
- Are inferred types backed by real validation and serialization?

## Adonis alignment

- Are routes, controllers, validators, and models still used idiomatically?
- Did Tuyau introduce framework bypasses?

## Response stability

- Could a Lucid model change break the client unexpectedly?
- Is the response transformer-backed (`serialize()` + transformer), so the client type comes from an intentional contract rather than a raw model dump?
- Should the response be normalized into an explicit transformer shape?
- If the client needs Date/Map/Set/Luxon fidelity, is `@tuyau/superjson` configured both sides instead of a one-off codec?
- For TanStack Query consumers, is the integration `@tuyau/react-query` or `@tuyau/vue-query`?
- Are non-2xx responses typed and handled with `.safe()`, `isStatus()`, or `isValidationError()` where the client branches on them?
- Are transport failures distinguished with `error.kind` when they need different recovery?

## Coupling risk

- Is the frontend too dependent on backend internals?
- Are private fields, relation names, or serialization quirks leaking into the public contract?

## Tests

- Is there at least one test path proving contract behavior?
- Are validation, auth, and typed error responses covered where important?
- For TanStack Query, is there one retry owner and the narrowest correct `queryKey()`, `pathKey()`, or `pathFilter()` invalidation?

## Final question

Would this API still be understandable and maintainable if Tuyau were removed tomorrow? If not, the layering is probably too implicit.
