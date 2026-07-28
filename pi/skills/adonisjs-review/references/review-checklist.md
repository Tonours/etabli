# AdonisJS 7 review checklist

## 1. Framework shape

- Does the feature live in the expected Adonis layer?
- Is the code using framework-native modules before custom abstractions?
- Does the structure remain recognizable to an Adonis developer?
- Does the change reduce drift or increase drift?

## 2. Vine validation

- Are inputs validated with Vine?
- Are validation rules explicit and close to the request boundary?
- Is there any duplicated or hand-written validation logic?
- Are params, query, and body handled deliberately?

## 3. Lucid ORM

- Are models, relationships, scopes, preload, pagination, and transactions used appropriately?
- Is raw SQL used only where justified?
- Are migrations focused and reversible?
- Is response serialization safe relative to model internals?

## 4. Auth and authorization

- Is the official auth approach respected?
- Are authorization checks explicit and coherent?
- Are sensitive actions covered by tests?

## 5. Mail and framework services

- Is Mail used instead of ad hoc SMTP wrappers?
- Are framework services configured centrally?
- Are providers used for boot wiring rather than random imports?
- Is side-effect timing understandable?

## 6. Commands, events, scheduler

- Are operational flows using commands/scheduler appropriately?
- Are events/listeners used as reactions rather than hidden main logic?

## 7. Config and env

- Is feature code free from scattered `process.env` reads?
- Are config concerns centralized and named clearly?

## 8. Controller and service boundaries

- Are controllers thin?
- Is business logic split into coherent actions/services?
- Are there any god objects or generic utils hiding domain logic?
- Is middleware limited to cross-cutting HTTP concerns?

## 9. Error handling

- Are failures handled consistently?
- Does the code rely on framework error flow instead of random response branches?

## 10. Tests

- Are happy path and failure path both covered?
- Are auth, validation, persistence, and transaction-sensitive flows exercised?
- Do tests assert behavior rather than implementation trivia?

## 11. Idiomatic verdict

Ask plainly: if this code were shown to an AdonisJS maintainer, would it look native, acceptable, or off-pattern?

## 12. Ship decision

Choose one:

- PASS
- PASS WITH FIXES
- BLOCK
