# Code snippet guidance for AdonisJS 7 skills

Use this file when providing examples or generating code.

## Rule

Prefer short, representative snippets over long speculative scaffolds.

## Snippet policy

- show the framework-native path first
- avoid pseudocode that hides real layer placement
- keep examples small but idiomatic
- make validation, persistence, and response boundaries visible

## Avoid

- giant templates with invented project structure
- generic Express-like examples dressed up as Adonis
- snippets that skip auth, validation, or response shaping where those are the real risks

## Good example traits

- route/controller boundary is visible
- Vine usage is visible when input exists
- Lucid or transaction usage is visible when persistence matters
- response contract is visible when API shape matters — prefer a transformer-backed shape over a raw model dump
- when a v7 type-safe primitive applies (`urlFor`, Transformers, experimental `@adonisjs/queue`), name it rather than showing a generic workaround
