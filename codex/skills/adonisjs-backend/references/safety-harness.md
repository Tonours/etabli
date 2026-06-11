# AdonisJS 7 backend safety harness

Use this file as a pre-flight and post-flight checklist.

## Non-negotiable checks

1. Is there an official AdonisJS module or convention for this concern?
2. Is validation owned by Vine?
3. Is persistence owned by Lucid or the query builder before raw SQL?
4. Are auth and authorization using official framework paths?
5. Is config/env access centralized?
6. Are providers, commands, events, and scheduler used in the right place?
7. Would an AdonisJS maintainer recognize this as idiomatic?

## Layer placement

### Correct defaults

- route: declares HTTP entry
- middleware: cross-cutting HTTP concerns
- controller: request orchestration and response boundary
- validator: input contract and coercion
- model: persistence and model-centric behavior
- action/service: business workflow spanning multiple framework primitives
- provider: registration and boot wiring
- listener: reaction to a domain/application event
- command: operator-facing or scheduled execution path

### Suspect placements

Flag and reconsider if you see:

- manual validation inside controllers
- business logic inside middleware
- env reads inside domain logic
- mail sending deep inside models without an intentional pattern
- raw SQL in places where Lucid is enough
- huge services with unrelated responsibilities
- startup effects hidden in imports instead of providers

## Native module expectations

### Vine

- request body, params, and query shapes should be explicit
- coercion and constraints should be deliberate
- error paths should be predictable

### Lucid ORM

- relationships should be modeled explicitly
- reusable filters should move into scopes where sensible
- transactions should guard critical multi-write paths
- model serialization should not leak hidden/internal fields accidentally

### Mail

- use framework mailers/templates flow
- keep delivery trigger points understandable

### Auth and authorization

- use guards/providers already chosen by the app
- keep authorization checks explicit on sensitive actions

### Config and env

- avoid feature-level `process.env`
- expose settings through config modules

### Commands, scheduler, events

- scheduled work belongs in the scheduler path
- operational entry points belong in commands
- reactions belong in listeners/events, not hidden side effects

## Review questions before shipping

- Is this still AdonisJS, or did it turn into generic Node inside an Adonis repo?
- Did I choose a custom abstraction where the framework already had a standard one?
- Will another Adonis developer understand the placement immediately?
- Is the code safer and more maintainable because of the framework, not in spite of it?
