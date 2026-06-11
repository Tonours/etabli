# AdonisJS 7 testing strategy

## Default bias

Prefer functional/integration tests for framework behavior.
Use unit tests selectively for isolated domain logic.

## What to test first

### HTTP endpoints

- success response
- validation failure
- auth failure
- authorization failure
- important edge case

### Lucid workflows

- write success
- transaction rollback or partial failure scenario
- relation loading or scope behavior when important

### Mail and side effects

- trigger conditions
- no-send or denial path when relevant
- post-persistence ordering when the workflow requires it

### Commands and scheduler

- command behavior and outcomes
- recurring flow safety for cleanup/import/batch tasks

### Tuyau contracts

- request validation
- success payload shape
- important error payload shape
- auth-sensitive contract behavior

## Test design rules

- assert behavior, not implementation trivia
- keep setup realistic but focused
- use factories/seeders where they increase clarity
- write regression tests for real bugs

## Review rule

If a feature changes behavior at a boundary and no matching test exists, treat that as a release risk.
