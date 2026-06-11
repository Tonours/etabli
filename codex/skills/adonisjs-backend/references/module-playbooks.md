# AdonisJS 7 module playbooks

Use these playbooks to choose the correct AdonisJS path quickly.

## Routes and controllers

Use when exposing or changing HTTP behavior.

### Default path

- declare the route clearly
- attach middleware explicitly
- keep controller methods action-oriented
- validate at the boundary
- delegate business workflow out of the controller
- return a deliberate response shape

### Watch for

- controllers doing validation inline
- controllers building complex SQL directly
- controllers branching on unrelated concerns

## Vine validation

Use when accepting body, params, query, or uploaded data.

### Default path

- create a validator/schema per use case or boundary
- validate body, params, and query deliberately
- use coercion intentionally
- keep accepted shape explicit

### Watch for

- manual `request.input()` checks spread through code
- weak validation hidden behind TypeScript types
- inconsistent validation between similar endpoints

## Lucid ORM

Use when reading or writing persistence state.

### Default path

- model relationships explicitly
- use scopes for reusable filters
- use preload/pagination/aggregates instead of manual glue
- use transactions for multi-step writes
- keep migrations focused and reversible

### Watch for

- raw SQL used by default
- duplicated query logic across services/controllers
- response contracts tied directly to model internals

## Auth and authorization

Use when protecting endpoints or actions.

### Default path

- use the project guard strategy
- authenticate at the right boundary
- perform authorization explicitly on sensitive actions
- test denial paths, not only success paths

### Watch for

- custom token parsing when official auth already covers it
- implicit authorization hidden in unrelated code
- missing tests for access control

## Mail

Use when sending transactional or workflow emails.

### Default path

- validate input first
- persist state if needed
- compose/send through Adonis Mail
- trigger at a visible workflow boundary

### Watch for

- SMTP wrappers or random SDK calls when Mail is enough
- mail sends hidden inside unrelated model code

## Providers

Use when registering services, bindings, boot wiring, or startup logic.

### Default path

- keep registration and boot responsibilities explicit
- centralize startup behavior in providers
- avoid side effects in random imports

### Watch for

- hidden boot logic in module top-level code
- feature setup scattered through controllers/services

## Events and listeners

Use for coherent reactions after a domain/application event.

### Default path

- emit from a visible workflow point
- keep listeners focused
- keep the main business flow explicit even if listeners exist

### Watch for

- events used to hide primary business logic
- listeners creating surprising side effects without tests

## Commands and scheduler

Use for operator tasks, maintenance, cleanup, imports, and recurring jobs.

### Default path

- put operational entry points in commands
- use the scheduler for recurring work
- keep commands explicit and observable

### Watch for

- cron-like logic hidden in web requests
- recurring behavior buried in imports or providers without clarity

## Config and env

Use for runtime settings, secrets, limits, provider config, and feature flags.

### Default path

- validate env centrally
- expose settings through config
- consume config in feature code, not raw env

### Watch for

- `process.env` in controllers/services/models
- inconsistent default values across files

## Response and serialization

Use whenever data crosses the API boundary.

### Default path

- make response shapes deliberate
- serialize only what the client should depend on
- avoid leaking private fields or unstable relations

### Watch for

- returning raw model instances casually
- exposing fields because they happen to exist rather than by contract

## Testing

Use for every change that affects behavior.

### Default path

- add integration/functional tests for HTTP flows
- cover validation failure, auth failure, and happy path
- add transaction-sensitive or side-effect-sensitive tests where needed
- use factories/seeders when realistic setup helps

### Watch for

- tests that only cover success paths
- unit tests replacing more valuable integration checks
- brittle assertions on internal implementation details
