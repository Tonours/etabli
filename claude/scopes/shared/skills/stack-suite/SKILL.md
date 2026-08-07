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
the language or framework.

## Route by subject

| Task touches | Use |
|---|---|
| Node.js runtime: async, streams, error handling, graceful shutdown, env config, profiling, flaky tests, type stripping | `node` |
| Node core internals: C++ addons, N-API, V8, libuv, node-gyp, segfaults, native leaks, a `nodejs/node` PR | `nodejs-core` |
| TypeScript types: generics, `infer`, conditional and mapped types, type guards, removing `any`, compiler errors | `typescript-magician` |
| Fastify: routes, plugins, hooks, JSON Schema validation, serialization, Pino logging, a REST API | `fastify` |
| OAuth 2.0/2.1: authorization code with PKCE, client credentials, device flow, refresh rotation, JWT validation, introspection | `oauth` |
| ESLint v9 flat config, neostandard, migrating off `.eslintrc`, lint in CI | `linting-neostandard-eslint9` |
| React or Next.js performance: waterfalls, bundle size, memoization, data fetching, re-render cost | `vercel-react-best-practices` |
| React component architecture: boolean prop proliferation, compound components, render props, context, reusable APIs | `vercel-composition-patterns` |
| React animation: `<ViewTransition>`, route transitions, shared-element and enter/exit animation | `vercel-react-view-transitions` |
| Web UI review: accessibility, interface guidelines, UX audit | `web-design-guidelines` |
| A React project's overall health, chasing a react-doctor score to 100 | `react-doctor-100` |
| Documentation structure: tutorial vs how-to vs reference vs explanation, Diátaxis | `documentation` |
| A TanStack Start or TanStack Query app | `tanstack-start-suite`, itself a router over 19 skills |
| An AdonisJS 7 app | `adonisjs-suite`, itself a router over 5 skills |

The last two rows are themselves routers, and they ship in the `personal` scope.
On a machine that does not declare it they are simply absent — fall back to the
generic rows above rather than reporting a missing skill.

## Rules

Pick from the dominant risk, not from the first file you opened. A React
performance problem in a Fastify-served app is a `vercel-react-best-practices`
task, not a `fastify` one.

More than one row can apply. Read them in the order the task needs, and stop as
soon as you have what the change requires.

A routed skill does not widen your scope. It tells you how to do the work you
were already asked to do; adjacent work it suggests stays out of scope, and
`PLAN.md` still decides what gets implemented.

If no row fits, say so and proceed without a skill rather than forcing the
closest match.
