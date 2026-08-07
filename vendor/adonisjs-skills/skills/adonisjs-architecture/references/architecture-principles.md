# AdonisJS 7 architecture principles

## Principle 1: framework first

Start from AdonisJS primitives before inventing custom structure.

## Principle 2: obvious placement

A future maintainer should be able to guess where code lives without reading the whole app.

## Principle 3: explicit boundaries

Keep request validation, persistence, boot wiring, and response shaping explicit. In v7, type-safety and indexing are wired explicitly through `adonisrc.ts` hooks (`indexEntities`, `generateRegistry` for Tuyau, `indexPolicies` for Bouncer) — treat them as part of the architecture, not invisible magic.

## Principle 4: small actions, thin controllers

Controllers should coordinate. Complex business workflows should move into focused actions/services.

## Principle 5: no fake decoupling

Do not add abstraction layers that only rename framework behavior without reducing coupling or complexity.

## Principle 6: stable contracts

Public response shapes and typed contracts should be deliberate, not accidental by-products of models.

## Principle 7: local consistency beats theoretical purity

If the app already has a coherent pattern, prefer the smallest safe path toward more Adonis alignment instead of a full rewrite.

## Principle 8: drift compounds

Every generic Node shortcut inside Adonis increases future review and maintenance cost. Treat drift as architectural debt early.

## Principle 9: persistence is not presentation

Models own persistence; the v7 Transformer layer owns the response shape. Keeping them separate is what makes API contracts stable and type-checkable end to end.

## Principle 10: type-safety is a design constraint

Route names, response shapes, and client types are generated, not hand-written. Make decisions that play into the codegen (`urlFor`, transformers, generated barrel files) instead of fighting it with string-based or manual equivalents.

## Principle 11: first-party modules before ecosystem substitutes

Before adopting a third-party cache, lock, queue, rate limiter, SSE, or tracing stack, check the official set: experimental `@adonisjs/queue`, `@adonisjs/limiter`, `@adonisjs/cache`, `@adonisjs/lock`, `@adonisjs/transmit`, `@adonisjs/otel`, `@adonisjs/health`, Transformers, `@adonisjs/content`.
