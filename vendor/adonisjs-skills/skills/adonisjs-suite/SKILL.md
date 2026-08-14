---
name: adonisjs-suite
description: Route and maintain the AdonisJS 7 skill suite. Use when a task touches AdonisJS but the main need—architecture, backend, Tuyau, testing, or review—is unclear, or when auditing and refreshing the suite itself.
---

# AdonisJS Suite

Use this skill as the router for the AdonisJS 7 skill set.

Read [skill routing](references/skill-routing.md) first.
Read [workflow order](references/workflow-order.md) when the task spans multiple phases.
Read [parallel dispatch](references/parallel-dispatch.md) before coordinating concurrent read-only analysis or any delegated implementation.
Read [source baseline](references/source-baseline.md) only when auditing version-sensitive guidance or maintaining this suite.
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

## Coordination rule

Parallelize independent read-only analysis only. Sequence architecture decisions, implementation, testing, and review for one feature, and keep a single writer in a shared worktree.

## Safety rule

If the task starts turning into generic Node inside AdonisJS, route back through [adonisjs-architecture](../adonisjs-architecture/SKILL.md) or [adonisjs-review](../adonisjs-review/SKILL.md).
