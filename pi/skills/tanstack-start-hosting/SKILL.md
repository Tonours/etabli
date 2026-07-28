---
name: tanstack-start-hosting
description: Deploy TanStack Start safely by choosing the right hosting target, respecting runtime constraints, and configuring SSR or SPA rewrites correctly.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Hosting

Use this skill when preparing a TanStack Start app for deployment or choosing a deployment target.

## When to use
Use this skill when:
- you still need to choose the right runtime/host for a TanStack Start app
- SSR vs SPA vs edge constraints are part of the decision
- you need framework-level hosting guidance before platform-specific execution

## When not to use
Do not use this skill as the main guide when:
- the host is already chosen and you only need the recipe
- the problem is primarily inside app code rather than deployment/runtime selection

This skill is for **host selection and runtime trade-offs**.
If the target host is already chosen and you need a more operational path, use `tanstack-start-deployment-recipes`.

## Canonical rule
TanStack Start is portable across multiple hosts, but the hosting target changes runtime constraints and deployment shape.

The official TanStack Start Hosting guide is the canonical deployment reference for framework-supported targets. Host adapters and provider-specific setup can change quickly, so verify the current official hosting docs before applying host-specific configuration.

Documented targets include:
- Cloudflare Workers
- Netlify
- Railway
- Nitro
- Vercel
- Node.js / Docker
- Bun
- Appwrite Sites

## Official provider notes
- Cloudflare Workers → official guide uses `@cloudflare/vite-plugin`, Wrangler, and a `wrangler.jsonc` setup that points to `@tanstack/react-start/server-entry`.
- Netlify → official guide uses `@netlify/vite-plugin-tanstack-start`.
- Railway / Vercel / Node / Bun → official docs often route through Nitro deployment guidance.
- Bun currently carries an extra caveat in official docs: the documented path requires React 19.

## Selection heuristic

### Choose Netlify or Railway when
- you want a simple deployment path
- you want minimal platform friction
- you do not need a very custom runtime story immediately

### Choose Cloudflare Workers when
- edge deployment matters
- you want strong CDN/edge integration
- your runtime constraints fit Workers

### Choose Nitro + Node/Docker when
- you want traditional server control
- you want more flexibility over infra/runtime
- you are comfortable owning deployment details

## Safe defaults
- prefer SSR-capable deployment for public SEO-sensitive apps
- keep secrets server-only and platform env config explicit
- verify host/runtime constraints before assuming Node-style behavior
- move to deployment recipes once the target is chosen

## Deployment discipline
Before hosting, confirm:
- app builds locally
- env vars are separated into client-safe vs server-only
- SSR/SEO decisions are intentional
- server functions and routes behave correctly

## Environment rules
- `VITE_*` only for client-safe build-time values
- secrets stay server-only
- production host must define required secrets explicitly

## SPA mode warning
If using SPA mode, your host must support rewrites correctly.
You generally need:
1. real static assets served directly
2. server function/server route paths exempted from blanket rewrites
3. unknown application paths rewritten to the SPA shell

## SSR mode guidance
If you care about SEO/public content, prefer SSR-capable deployment.
Do not accidentally ship a public app in SPA mode just because local dev felt easier.

## Node/Docker pattern
If using a Node-style deployment path, ensure your scripts are coherent and your output/runtime expectations match the docs.

## Nitro note
Nitro is a useful portability layer for multiple targets, but treat it as an extra moving part that should be verified, not assumed.

## Anti-patterns

### Anti-pattern 1
Choosing a host before understanding whether the app needs SSR, edge, or a classic Node runtime.

### Anti-pattern 2
Shipping wrong env vars because client/server boundaries were not respected.

### Anti-pattern 3
Using SPA mode without rewrite rules.

### Anti-pattern 4
Assuming a hosting target behaves like local Node when it is actually edge-constrained.

## Definition of done
Hosting is correctly prepared when:
- target runtime is chosen intentionally
- env vars are correct
- SSR/SPA/static strategy matches the product needs
- deployment instructions are specific to the chosen host
- post-deploy validation confirms the app actually serves the expected rendering mode
