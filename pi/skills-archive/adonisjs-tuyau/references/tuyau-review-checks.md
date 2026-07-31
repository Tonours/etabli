# Tuyau review checks

## Contract integrity

- Does the backend truly enforce the shape the frontend trusts?
- Are inferred types backed by real validation and serialization?

## Adonis alignment

- Are routes, controllers, validators, and models still used idiomatically?
- Did Tuyau introduce framework bypasses?

## Response stability

- Could a Lucid model change break the client unexpectedly?
- Should the response be normalized into an explicit DTO-like object?

## Coupling risk

- Is the frontend too dependent on backend internals?
- Are private fields, relation names, or serialization quirks leaking into the public contract?

## Tests

- Is there at least one test path proving contract behavior?
- Are validation, auth, and error responses covered where important?

## Final question

Would this API still be understandable and maintainable if Tuyau were removed tomorrow? If not, the layering is probably too implicit.
