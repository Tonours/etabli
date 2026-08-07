---
name: tanstack-start-bootstrap
description: Scaffold and normalize a TanStack Start project with a clean root route, router, Tailwind setup, and safe project structure.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Bootstrap

Use this skill when starting a new TanStack Start codebase or cleaning a freshly scaffolded one.

## When to use
Use this skill when:
- creating a new TanStack Start project
- normalizing a fresh scaffold before feature work
- cleaning starter boilerplate into a stable baseline

## When not to use
Do not use this skill as the main guide when:
- auth, DB, or deployment concerns are already the primary task
- the app structure is already stable and you only need one feature change

## Goal

Produce a clean foundation with:
- correct `getRouter()` setup
- correct `__root.tsx` shell
- optional Tailwind v4 integration
- starter cleanup
- first routes working

## Canonical rule
Treat official TanStack Start docs as canonical, and keep the initial project baseline boring, runnable, and free of premature feature complexity.

## Core rules

1. Treat official TanStack Start docs as canonical.
2. Keep the root route minimal and infrastructure-focused.
3. Route loaders are isomorphic, not server-only. Keep them orchestration-focused; never treat them as a secure place for secrets, DB credentials, or private server logic.
4. Make the project runnable early, before adding auth/DB/features.
5. TanStack Start supports both Vite (`@tanstack/react-start/plugin/vite`) and Rsbuild (`@tanstack/react-start/plugin/rsbuild`) as build tools. Pick one per project and keep the plugin import consistent.

## Recommended workflow

### 1. Scaffold
Preferred official path:
- TanStack Builder

Also valid official paths:

```bash
npx @tanstack/cli@latest create
```

- clone an official example
- wire from scratch only if you explicitly need to understand the low-level setup

### 2. Verify baseline
Run:

```bash
npm install
npm run dev
```

Confirm:
- app starts
- `src/routeTree.gen.ts` exists
- no broken starter routes

### 3. Normalize router
Expected pattern:

```tsx
import { createRouter } from '@tanstack/react-router'
import { routeTree } from './routeTree.gen'

export function getRouter() {
  const router = createRouter({
    routeTree,
    scrollRestoration: true,
  })

  return router
}
```

Rule:
- `getRouter()` must return a fresh router instance each time.

### 4. Normalize root route
Expected responsibilities of `src/routes/__root.tsx`:
- document shell
- global metadata
- global providers
- stylesheet links
- `<HeadContent />`
- `<Outlet />`
- `<Scripts />`

Minimal pattern:

```tsx
/// <reference types="vite/client" />
import type { ReactNode } from 'react'
import {
  Outlet,
  createRootRoute,
  HeadContent,
  Scripts,
} from '@tanstack/react-router'

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: 'My TanStack Start App' },
    ],
  }),
  component: RootComponent,
})

function RootComponent() {
  return (
    <RootDocument>
      <Outlet />
    </RootDocument>
  )
}

function RootDocument({ children }: { children: ReactNode }) {
  return (
    <html>
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  )
}
```

### 5. Add Tailwind v4 if desired
Official Tailwind integration path is:

Install:

```bash
npm install tailwindcss @tailwindcss/vite
```

Vite plugin:
- add `@tailwindcss/vite`

CSS file:

```css
@import 'tailwindcss' source('../');
```

Then import the stylesheet from `__root.tsx` with `?url` and expose it through `head().links`.

### 6. Clean starter noise
Remove or simplify:
- demo routes you will not keep
- placeholder components
- decorative boilerplate
- logic in root route that belongs in app-specific modules

### 7. Add first real routes
Create a tiny route set first:
- `/`
- `/about` or `/health`
- one feature route

Verify file-based routing works before adding data loading.

## Safe defaults
- choose the official CLI or Builder unless you have a reason not to
- verify the app runs before adding auth, DB, or feature complexity
- keep `__root.tsx` infrastructure-focused
- add only a tiny first route set before scaling the app tree

## Definition of done
- project boots locally
- route tree is generated
- root route shell is correct
- router setup is correct
- first routes render
- optional Tailwind is active
- no unnecessary starter clutter remains

## Anti-patterns
- forgetting `<Scripts />`
- forgetting `<HeadContent />`
- returning a shared router singleton instead of a new instance
- pushing business logic into `__root.tsx`
- adding auth/DB before the baseline app actually runs

## Hand-off note
After bootstrap, the next likely skills are:
- `tanstack-start-server-functions`
- `tanstack-start-auth`
- `tanstack-start-seo`
