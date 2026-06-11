# AdonisJS 7 architecture principles

## Principle 1: framework first

Start from AdonisJS primitives before inventing custom structure.

## Principle 2: obvious placement

A future maintainer should be able to guess where code lives without reading the whole app.

## Principle 3: explicit boundaries

Keep request validation, persistence, boot wiring, and response shaping explicit.

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
