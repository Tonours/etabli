---
name: adonisjs-testing
description: Plan, add, and review AdonisJS 7 tests. Use for Japa API and browser flows, Vine validation, Lucid persistence, auth, mail, events, Ace commands, scheduler work, and Tuyau contract safety.
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

Prefer tests that validate behavior at the narrowest real framework boundary over tests that mirror implementation details. Use the typed Japa API client for JSON endpoints, Playwright-backed browser tests for material Hypermedia/Inertia journeys, and console tests for Ace commands.

## Testing priorities

1. HTTP/API behavior through Japa's real server boundary and route names
2. Browser behavior for material Hypermedia or Inertia user journeys
3. Vine validation success and failure paths
4. Auth and authorization behavior
5. Lucid persistence and transaction-sensitive flows
6. Mail, events, queues, or side effects at visible workflow boundaries
7. Ace command behavior through console tests
8. Contract stability for Tuyau endpoints
9. Focused unit tests only when isolated domain logic justifies them

## Required checks

Before calling a change safe, verify:

- happy path is covered,
- validation failure is covered,
- auth or authorization failure is covered when relevant,
- persistence side effects are covered when relevant,
- contract-sensitive response shape is covered when relevant,
- a browser test covers the true user end state when server-side assertions cannot prove it,
- Ace commands are exercised through the console-test surface when command interaction or exit behavior matters,
- regression tests exist for previously broken behavior when applicable.

## Smells

- heavily unit-testing controllers instead of exercising real HTTP flow,
- using browser tests for behavior that a faster API test proves completely,
- testing an Ace command by calling internal methods while ignoring prompts, output, or exit code,
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
