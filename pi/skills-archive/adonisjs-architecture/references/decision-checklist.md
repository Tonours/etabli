# AdonisJS architecture decision checklist

## Map the concern

- Is this HTTP, validation, persistence, auth, bootstrapping, async reaction, command, scheduler, or contract design?
- Which Adonis primitive should own it first?

## Place the responsibility

- What belongs in the route?
- What belongs in middleware?
- What belongs in the controller?
- What belongs in Vine?
- What belongs in Lucid?
- What belongs in a service/action?
- What belongs in a provider/event/command?

## Check drift risk

- Are we bypassing an official module?
- Are we adding a custom layer without a real payoff?
- Will this make the code less recognizable as AdonisJS?
- Will this increase future normalization cost?

## Check stability

- Is config centralized?
- Is the response shape explicit?
- Are model internals leaking?
- Will tests be able to cover the boundary cleanly?

## Decision rule

Prefer the smallest architecture that:
- uses native Adonis primitives,
- keeps boundaries clear,
- is easy to test,
- does not create hidden drift.
