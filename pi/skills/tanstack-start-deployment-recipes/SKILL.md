---
name: tanstack-start-deployment-recipes
description: Choose and execute a deployment recipe for TanStack Start with the minimum host-specific changes needed for Node, Nitro, Netlify, Railway, Vercel, or Cloudflare.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Deployment Recipes

Use this skill when the hosting target is known and you need a practical deployment path instead of generic hosting advice.

## When to use
Use this skill when:
- the hosting target is already chosen
- you need the minimum viable deployment recipe for a specific platform
- the main question is execution, not host selection

## When not to use
Do not use this skill as the main guide when:
- you still need to choose the right host/runtime
- the task is mainly about app architecture rather than deployment

## Scope
This skill is the operational companion to `tanstack-start-hosting`.
Use it after the team has already decided where the app should run.

There is no separate official TanStack Start "deployment recipes" guide; the main official grounding here is the Hosting guide plus linked provider/runtime docs.

The goal here is not broad platform comparison; it is to provide a compact execution recipe per target.

## Canonical rule
Use the official TanStack Start Hosting guide as the source of truth for platform support, then apply the smallest host-specific recipe that preserves the intended rendering/runtime behavior.

## Before any deployment
Verify:
- the app builds locally
- env vars are classified correctly
- SSR/SPA/static strategy is intentional
- no secrets are client-exposed
- route/server function behavior is stable in local/prod-like mode
- the current official TanStack Start hosting docs still match the chosen target and adapter/plugin names

## Recipe selection

### Recipe A — Netlify
Choose when:
- you want a simple managed deployment path
- you are comfortable with Netlify’s plugin-based setup

High-level actions:
1. install `@netlify/vite-plugin-tanstack-start`
2. add the Netlify plugin to `vite.config.ts`
3. configure build/deploy settings or let Netlify initialize them
4. set env vars in Netlify
5. deploy and verify SSR behavior

Primary files/surfaces to inspect:
- `vite.config.ts`
- optional `netlify.toml`
- Netlify environment variable settings

Validation focus:
- public pages SSR correctly
- server functions still work after deploy
- env vars are present and classified correctly

### Recipe B — Railway
Choose when:
- you want fast managed deployment with low ops overhead
- Node-style hosting is acceptable

High-level actions:
1. follow the official Nitro deployment path first
2. ensure build/start scripts are correct
3. push the repo
4. connect the repo in Railway
5. set env vars
6. verify runtime behavior

Primary files/surfaces to inspect:
- `package.json`
- hosting/runtime settings in Railway
- environment variable configuration

Validation focus:
- app boots correctly in the managed runtime
- SSR pages and server functions behave as expected

### Recipe C — Node / Docker via Nitro
Choose when:
- you want infra control
- you want a portable Node deployment shape

High-level actions:
1. wire Nitro if required by the chosen setup
2. ensure `vite build` output matches the runtime expectation
3. set the start command to the generated server entry
4. containerize if needed
5. verify SSR and static asset serving

Primary files/surfaces to inspect:
- `vite.config.ts`
- `package.json`
- Dockerfile / process manager / deployment manifest if used

Validation focus:
- build output exists where expected
- server entry starts cleanly
- static assets and SSR responses are both served correctly

### Recipe D — Vercel
Choose when:
- the team already standardizes on Vercel
- the runtime constraints are acceptable

High-level actions:
1. use the Nitro/Vercel path documented by Start
2. set env vars in Vercel
3. verify routing, SSR, and server function behavior after deploy

Primary files/surfaces to inspect:
- `vite.config.ts`
- Vercel project env vars
- any Vercel-specific deployment configuration

### Recipe E — Bun
Choose when:
- you want Bun as the runtime
- React 19 compatibility is acceptable

High-level actions:
1. follow the Nitro Bun deployment path documented by Start
2. confirm the project/runtime meets the React 19 requirement from the official docs
3. set env vars and deploy
4. verify runtime behavior

### Recipe F — Cloudflare Workers
Choose when:
- edge deployment really matters
- the app/runtime dependencies fit Workers

High-level actions:
1. install `@cloudflare/vite-plugin` and Wrangler
2. configure Vite appropriately
3. add `wrangler.jsonc`
4. point the worker entry to `@tanstack/react-start/server-entry`
5. authenticate/deploy
6. verify runtime assumptions against Worker constraints

Primary files/surfaces to inspect:
- `vite.config.ts`
- `wrangler.jsonc`
- Cloudflare env/bindings configuration

Validation focus:
- app works within Worker runtime constraints
- SSR or server behavior still matches expectations
- no hidden Node-only assumptions remain

## Safe defaults
- prefer the documented official host/plugin path over custom deployment cleverness
- verify SSR/server-function behavior after deployment, not just local builds
- keep env setup explicit per platform

## Deployment validation checklist
After deploy, always test:
- homepage loads correctly
- SSR pages render expected HTML
- server functions work
- protected routes behave correctly
- env vars are present
- no secret leaks in client output
- SEO metadata appears correctly on public pages

## Anti-patterns

### Anti-pattern 1
Using a generic recipe without confirming SSR/runtime needs.

### Anti-pattern 2
Assuming “build succeeds” means “deployment is correct”.

### Anti-pattern 3
Deploying without validating server functions and protected routes in the real target environment.

### Anti-pattern 4
Treating hosting docs as interchangeable across edge and Node runtimes.

## Definition of done
A deployment recipe has been applied correctly when:
- host-specific setup is minimal but sufficient
- the rendering strategy still matches product needs
- env vars are correct
- post-deploy validation confirms the app behaves as intended
