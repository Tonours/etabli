---
name: suite-router
description: Meta router that detects the dominant domain (design/UI, React/frontend, Node/backend, full-stack) and activates the matching suite(s) before planning or implementing. Use first on /plan-loop, /plan-implement, /ship, or any ambiguous feature request that may touch UI, React, or Node.
---

# Suite Router

Run this skill **first** on high-level commands (`plan-loop`, `plan-implement`, `ship`) and on any request that could span design, React, or backend work.

It carries no implementation rules. It only classifies the domain and points at the suite that already owns the procedure.

## Detection signals

Match signals in this priority order (stop at the highest applicable set):

1. **Project suites** — employer Ember / employer backend / Adonis tasks → prefer `ember-employer-suite`, `employer-backend-suite`, or `adonisjs-suite` over generic suites. Project suites are scope-gated (work or personal): when one is not linked on the current surface, say so and fall back to the generic suites instead of reporting a missing skill.
2. **Design / UI** — keywords: design, UI, UX, page, layout, dark mode, responsive, brand, figma, screenshot, mockup, visual, spacing, typography; or `DESIGN.md` / design tokens present → `design-suite`.
3. **React / frontend code** — `.tsx` / React / RSC / Next / TanStack component paths, or keywords tied to implementation (hook, re-render, composition) → `stack-suite` (React rows).
4. **Node / backend** — API, route, middleware, server, Fastify, Express, Hono, Nest, Prisma, Drizzle, auth backend, worker, Node → `stack-suite` (Node / Fastify / oauth rows).
5. **Full-stack** (UI + API + data) → activate both `design-suite` and `stack-suite` (design-suite first for visual generation, then stack-suite for implementation constraints).

Also inspect `package.json` dependencies and open / changed files. Prefer path and dependency evidence over a bare keyword like "component" (which can mean pure CSS).

## Procedure

1. Read the user brief + `git status --short` + relevant paths.
2. Match domains with the priority list above.
3. Announce activated suite(s) in one short line, e.g. `Activated: design-suite + stack-suite (React)`.
4. **Invoke** the matched suite skill(s) via the Skill tool (same model — suites are not subagents). Do not implement yourself.
5. If matches are ambiguous and the work is risky, ask one narrow clarification; otherwise invoke the highest-priority suite(s) and continue.

## Rules

- Prefer the narrowest accurate suite.
- Project-specific suites win over generic ones when the task is about this codebase rather than the language or framework.
- A suite does not widen scope; `PLAN.md` still decides what gets implemented.
- Hand React/Node detail routing to `stack-suite` only (it already points at `react-doctor-100`, Fastify, etc.).
- If nothing fits, say so and proceed without a domain suite rather than forcing a match.
