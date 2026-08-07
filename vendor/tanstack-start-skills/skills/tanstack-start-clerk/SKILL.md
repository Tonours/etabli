---
name: tanstack-start-clerk
description: Add Clerk to a TanStack Start app in a way that keeps auth fast to ship, but still server-safe and maintainable.
version: 0.1.0
author: Moka
license: Proprietary
---

# TanStack Start Clerk

Use this skill when integrating Clerk into a TanStack Start project.

## When to use
Use this skill when:
- you chose Clerk as the auth provider
- you want hosted auth, prebuilt UI, or org features
- you need TanStack Start-specific guidance for keeping Clerk integration server-safe

## When not to use
Do not use this skill as the main guide when:
- you want provider-agnostic auth architecture
- you are using Better Auth or another provider
- the task is only about resource-level authorization after auth is already wired

## Why this skill exists
Clerk is one managed authentication option for TanStack Start when you want:
- sign-in / sign-up
- user management
- organizations/teams
- social login

But speed should not become sloppy architecture.

## Canonical rule
Clerk can accelerate auth significantly, but you should still:
- keep the server as source of truth for sensitive operations
- protect route subtrees intentionally
- re-check permissions in server functions

## Recommended rollout

### 1. Install the official TanStack Start SDK
Use Clerk's Start integration package:

```bash
npm install @clerk/tanstack-react-start
```

### 2. Store env vars correctly
- `CLERK_PUBLISHABLE_KEY` for the browser-safe publishable key
- `CLERK_SECRET_KEY` for the server-only secret key
- never expose secret keys in client bundles

Only use a public env prefix for unrelated custom client config that truly must be exposed (`VITE_*` on Vite, `PUBLIC_*` on Rsbuild by default).

### 3. Register Clerk request middleware
Create or update `src/start.ts` and add `clerkMiddleware()` to the Start middleware chain so Clerk can handle request/session state at the framework boundary.

### 4. Add the provider in the app shell
Wrap the app shell/root with `ClerkProvider` from `@clerk/tanstack-react-start`.
Do not spread provider setup across random feature files.

### 5. Create public and protected route trees
Separate:
- public pages
- authenticated pages

In TanStack Start, prefer `beforeLoad` on the protected parent layout or pathless layout route for redirect-based gating during navigation.

### 6. Guard sensitive server functions
Clerk UI state or protected routes do not replace server-side enforcement.

## Good architectural pattern
- Clerk handles identity/session UX
- `beforeLoad` handles route-entry gating for protected areas
- TanStack Start route structure keeps protected app segmentation visible
- server functions or server function middleware enforce actual read/write permissions
- route loaders remain orchestration-only because they are isomorphic, not server-only

## Practical rules
1. Keep Clerk initialization centralized.
2. Do not make every component responsible for auth logic.
3. Use protected layouts for route grouping.
4. Re-check authorization inside server mutations.
5. Keep user/resource ownership logic server-side.
6. Treat official TanStack Start docs as canonical for framework behavior, and verify current Clerk docs for provider-specific SDK/setup details.

## Clerk-specific implementation checklist
- install/use `@clerk/tanstack-react-start`
- use `CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY` for the official Start SDK path
- register `clerkMiddleware()` in `src/start.ts`
- wrap the app shell/root with `ClerkProvider`
- create a small auth utility layer for current user/session helpers
- protect authenticated route subtrees with a dedicated layout
- require server-side checks for any mutation or sensitive read tied to a user/org/workspace

## Safe defaults
- centralize Clerk setup at the app shell level
- use `beforeLoad` for route-entry gating on protected areas
- keep authorization and ownership checks in server functions
- keep env boundaries explicit between publishable and secret keys

## Anti-patterns

### Anti-pattern 1
Treating Clerk UI components as the whole security model.

### Anti-pattern 2
Spreading session logic across many components.

### Anti-pattern 3
Letting the client decide whether a mutation is allowed.

### Anti-pattern 4
Leaking Clerk secret configuration into client-safe env vars.

## Definition of done
A Clerk integration is in good shape when:
- provider setup is centralized
- route protection is structured
- env var boundaries are correct
- sensitive reads/writes are enforced server-side
- the app gains speed without losing architectural clarity
