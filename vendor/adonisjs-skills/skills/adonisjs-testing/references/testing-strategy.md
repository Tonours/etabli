# AdonisJS 7 testing strategy

## Default bias

Prefer functional/integration tests for framework behavior.
Use unit tests selectively for isolated domain logic.

## What to test first

### HTTP endpoints

- use Japa's API client against the running AdonisJS server
- prefer `client.visit()` with generated route names so URL and HTTP-method drift is type-checked
- success response
- validation failure
- auth failure
- authorization failure
- rate-limit behavior on abuse-prone endpoints (`@adonisjs/limiter`)
- important edge case

### Browser journeys

- use Playwright-backed Japa browser tests for material Hypermedia or Inertia flows
- prove the user-visible end state, navigation, and client-side interaction that API assertions cannot observe
- keep pure API behavior in the faster API suite

### Lucid workflows

- write success
- transaction rollback or partial failure scenario
- relation loading or scope behavior when important

### Mail and side effects

- trigger conditions
- no-send or denial path when relevant
- post-persistence ordering when the workflow requires it

### Commands, scheduler, and queues

- command prompts, output, exit code, and side effects through Japa console tests when they matter
- recurring flow safety for cleanup/import/batch tasks
- job dispatch asserted with the queue fake (`QueueManager.fake()`, `assertPushed` / `assertNotPushed` / `assertPushedCount` / `assertNothingPushed`) without running the worker
- retry/failure-path behavior for jobs that must not silently drop
- dedup behavior when the product depends on single-enqueue under retries

### Tuyau contracts

- request validation
- success payload shape (assert the transformer output via `serialize()`, not the raw model)
- important error payload shape
- auth-sensitive contract behavior
- SuperJSON-backed types only when the product requires rich wire fidelity

## Test design rules

- assert behavior, not implementation trivia
- keep setup realistic but focused
- use factories/seeders where they increase clarity
- write regression tests for real bugs
- isolate state with the project's Japa/Adonis test utilities and test-specific drivers instead of relying on suite order

## Review rule

If a feature changes behavior at a boundary and no matching test exists, treat that as a release risk.
