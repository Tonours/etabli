---
name: adonisjs-suite
description: Route AdonisJS 7 work to the right skill. Use when a task touches AdonisJS but the main need—architecture, backend, Tuyau, testing, or review—is not yet clear.
---

# AdonisJS Suite

Use this skill as the router for the AdonisJS 7 skill set.

Read [skill routing](references/skill-routing.md) first.
Read [workflow order](references/workflow-order.md) when the task spans multiple phases.
Read [parallel dispatch](references/parallel-dispatch.md) when dispatching concurrent subagents.
Read [examples and prompts](references/examples-and-prompts.md) when the user needs a ready-to-send meta prompt.

## Core rule

Choose the specialist from the main risk, not from the first file you saw.

## Routing guide

- Use [adonisjs-architecture](../adonisjs-architecture/SKILL.md) for layer ownership, module choice, structural drift, or large refactors.
- Use [adonisjs-backend](../adonisjs-backend/SKILL.md) for backend implementation or refactor work.
- Use [adonisjs-tuyau](../adonisjs-tuyau/SKILL.md) for typed contracts, typed client/server coupling, or response-shape safety.
- Use [adonisjs-testing](../adonisjs-testing/SKILL.md) for coverage, ship confidence, or test design.
- Use [adonisjs-review](../adonisjs-review/SKILL.md) for audits, verdicts, and framework-alignment review.

## Default order

For non-trivial work:

1. architecture if structure is unclear,
2. backend or Tuyau implementation,
3. testing,
4. review.

## Safety rule

If the task starts turning into generic Node inside AdonisJS, route back through [adonisjs-architecture](../adonisjs-architecture/SKILL.md) or [adonisjs-review](../adonisjs-review/SKILL.md).
