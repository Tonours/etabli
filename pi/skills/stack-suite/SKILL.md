---
name: stack-suite
description: "Route Node.js, TypeScript, React and web-UI work to the vendored skill that already covers it, before writing code or reviewing a diff. Use when the task touches Node.js (streams, async, error handling, graceful shutdown, type stripping, profiling, flaky tests), TypeScript types (generics, `any` removal, type guards, conditional or mapped types, compiler errors), Fastify or a REST API, OAuth 2.0/2.1 and token flows, ESLint flat config or neostandard, React or Next.js performance, React component architecture and composition, React view transitions and animation, web accessibility and UI review, Node core internals or C++ addons, or technical documentation structure."
version: 0.1.0
author: Anthony Guimard
license: Proprietary
---

# Stack suite

Router for language- and framework-level work: Node.js, TypeScript, React, and
web UI. It carries no rules of its own — it points at the vendored skill that
does.

Project-specific work routes elsewhere: `ember-employer-suite` for the
employer Ember frontend, `employer-backend-suite` for the employer backend and
integrations. Those win when the task is about *this* codebase rather than about
the language or framework. They ship in the Claude `work` scope only; on a
surface where they are not linked, say so and use the generic rows below
instead of reporting a missing skill.

## Route by subject

| Task touches | Use |
| --- | --- |
| A React project's overall health, chasing a react-doctor score to 100 | `react-doctor-100` |
| An AdonisJS 7 app | `adonisjs-suite`, itself a router over 5 skills |

The AdonisJS row is itself a router, and it ships in the `personal` scope.
On a machine that does not declare it, it is simply absent — proceed without
a skill rather than reporting a missing one.

## Rules

Pick from the dominant risk, not from the first file you opened. A React
health-audit pass is a `react-doctor-100` task, not an `adonisjs-suite` one.

More than one row can apply. Read them in the order the task needs, and stop as
soon as you have what the change requires.

A routed skill does not widen your scope. It tells you how to do the work you
were already asked to do; adjacent work it suggests stays out of scope, and
`PLAN.md` still decides what gets implemented.

If no row fits, say so and proceed without a skill rather than forcing the
closest match.
