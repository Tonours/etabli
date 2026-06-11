---
name: adonisjs-tuyau
description: Build and review AdonisJS 7 plus Tuyau typed API flows. Use for route contracts, typed client/server integration, payload validation, response shaping, and contract safety.
---

# AdonisJS Tuyau

Treat Tuyau as a typed contract layer built on top of idiomatic AdonisJS. Do not let it erase framework boundaries.

Read [Tuyau patterns](references/tuyau-patterns.md) before editing Tuyau code.
Read [contract patterns](references/contract-patterns.md) when designing or normalizing a typed endpoint contract.
Read [Tuyau review checks](references/tuyau-review-checks.md) when auditing an implementation.
Read [Tuyau safety harness](references/tuyau-safety-harness.md) before shipping contract changes.
Read [serialization and DTO policy](../adonisjs-backend/references/serialization-and-dto-policy.md) when response shaping is the main risk.
Read [anti-patterns](../adonisjs-backend/references/anti-patterns.md) when checking API drift against core Adonis conventions.
Read [examples and prompts](references/examples-and-prompts.md) when the user needs a ready-to-send Tuyau prompt.
Use [adonisjs-testing](../adonisjs-testing/SKILL.md) when contract-sensitive tests are weak or missing.
Use [adonisjs-architecture](../adonisjs-architecture/SKILL.md) when the endpoint design itself is structurally unclear.

## Safety harness

Before changing a Tuyau endpoint, confirm:

- the route remains a normal AdonisJS route,
- the controller remains an HTTP boundary,
- Vine remains the authority for accepted input,
- the response shape is intentional and stable,
- the frontend is not coupled to raw Lucid internals accidentally,
- inferred types match real runtime behavior,
- contract-sensitive tests exist or are added.

If strong typing hides weak runtime guarantees, treat that as a bug.

## Goals

- preserve AdonisJS route, controller, and validation conventions,
- keep Vine-backed validation explicit,
- keep route contracts and inferred client types trustworthy,
- avoid leaking persistence models as unstable public API contracts unless intentional,
- make contract drift visible early.

## Flow

1. Identify the backend route and its HTTP semantics.
2. Define or verify the input contract.
3. Ensure Vine validation is explicit and authoritative.
4. Define or verify the response contract deliberately.
5. Check typed client usage on the consumer side.
6. Add tests for contract-sensitive changes.
7. Run the Tuyau safety harness before finalizing.

## Conventions

- controllers stay HTTP boundaries, even with strong typing,
- Vine stays the source of request validation,
- Lucid models stay internal unless there is an intentional serialization contract,
- DTO-like response shapes are preferred when model internals should not leak,
- explicit response design beats magical inference for long-lived or widely reused endpoints.

## Block when

- typing is inferred from unstable shapes,
- validation is weaker than the client contract suggests,
- a model schema change could silently break the client,
- hidden or private fields may leak through serialization,
- the frontend is coupled to relation internals or incidental model structure,
- Tuyau is being used to bypass normal Adonis architecture.

## Output

When implementing or reviewing, state:

- the route or contract changed,
- how validation is enforced,
- how response typing is stabilized,
- any coupling risks introduced or removed,
- whether the contract is safe to ship.
