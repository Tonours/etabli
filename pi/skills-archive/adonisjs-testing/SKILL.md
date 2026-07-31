---
name: adonisjs-testing
description: Plan, add, and review AdonisJS 7 tests. Use for HTTP flows, Vine validation, Lucid persistence, auth, mail, events, commands, scheduler work, and Tuyau contract safety.
---

# AdonisJS Testing

Treat tests as the final safety harness for AdonisJS 7 behavior.

Read [testing strategy](references/testing-strategy.md) first.
Read [test checklists](references/test-checklists.md) before implementing or reviewing tests.
Read [Tuyau testing playbook](references/tuyau-testing-playbook.md) when typed contract safety is part of the risk.
Read [examples and prompts](references/examples-and-prompts.md) when the user needs a ready-to-send testing prompt.
Use [adonisjs-review](../adonisjs-review/SKILL.md) when a verdict is needed on whether the remaining gaps should block ship.
Use [adonisjs-tuyau](../adonisjs-tuyau/SKILL.md) when the test plan must protect a typed contract.

## Core rule

Prefer tests that validate behavior at framework boundaries over tests that mirror implementation details.

## Testing priorities

1. HTTP behavior
2. Vine validation success and failure paths
3. Auth and authorization behavior
4. Lucid persistence and transaction-sensitive flows
5. Mail, events, or side effects at visible workflow boundaries
6. Contract stability for Tuyau endpoints
7. Focused unit tests only when isolated domain logic justifies them

## Required checks

Before calling a change safe, verify:

- happy path is covered,
- validation failure is covered,
- auth or authorization failure is covered when relevant,
- persistence side effects are covered when relevant,
- contract-sensitive response shape is covered when relevant,
- regression tests exist for previously broken behavior when applicable.

## Smells

- heavily unit-testing controllers instead of exercising real HTTP flow,
- skipping denial or failure paths,
- asserting internal method calls instead of observable outcomes,
- missing tests around transactions, serialization, or typed contracts.

## Output

When planning or reviewing tests, return:

- required test layers,
- critical cases,
- gaps,
- ship risk if tests are missing,
- smallest safe test set.
