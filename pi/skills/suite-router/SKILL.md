---
name: suite-router
description: Meta router that detects the dominant domain (design/UI, React/frontend, Node/backend, full-stack) and activates the matching suite(s) before planning or implementing. Use first on /plan-loop, /plan-implement, /ship, or any ambiguous feature request that may touch UI, React, or Node.
---

# Suite Router

Run this skill **first** on high-level commands (`plan-loop`, `plan-implement`, `ship`) and on any request that could span design, React, or backend work.

It carries no implementation rules. It only classifies the domain and points at the suite that already owns the procedure.

## Detection signals

Score the request from these signals (more than one suite may win):

| Signal | Points to |
|--------|-----------|
| Keywords: design, UI, UX, page, layout, dark mode, responsive, brand, figma, screenshot, mockup, visual, spacing, typography | `design-suite` |
| Keywords / paths: React, component, hook, .tsx, RSC, Server Component, TanStack, Next, composition, re-render | `stack-suite` (React rows) + existing `react-doctor-100` |
| Keywords / paths: API, route, middleware, server, Fastify, Express, Hono, Nest, Prisma, Drizzle, auth backend, worker, Node | `stack-suite` (Node / Fastify / oauth rows) |
| Full-stack feature (UI + API + data) | Activate both `design-suite` and `stack-suite` |
| employer Ember / employer backend | Prefer project suites (`ember-employer-suite`, `employer-backend-suite`) over generic ones |

Also inspect:

- `package.json` dependencies
- Open / changed files (extensions and directories)
- Presence of `DESIGN.md` or design tokens → boost design

## Procedure

1. Read the user brief + `git status --short` + relevant paths.
2. Score domains.
3. Announce activated suite(s) in one short line, e.g. `Activated: design-suite + stack-suite (React)`.
4. Hand control to the suite orchestrator(s). Do not implement yourself.
5. If scores are ambiguous and the work is risky, ask one narrow clarification; otherwise load the highest-scoring suite(s) and continue.

## Rules

- Prefer the narrowest accurate suite.
- Project-specific suites win over generic ones when the codebase is employer / Ember / Adonis / TanStack Start.
- A suite does not widen scope; `PLAN.md` still decides what gets implemented.
- If nothing fits, say so and proceed without a domain suite rather than forcing a match.
