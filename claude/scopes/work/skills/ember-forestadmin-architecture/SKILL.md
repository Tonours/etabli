---
name: ember-forestadmin-architecture
description: "Work inside ForestAdmin’s hybrid Ember architecture: features, shared, routes, data, legacy fallback, and MFEs."
version: 0.2.0
author: ForestAdmin Team
license: Proprietary
---

# Ember ForestAdmin Architecture

Use this skill when deciding where code belongs or reviewing an architectural change.

## Mental model

ForestAdmin is a hybrid Ember app migrating away from legacy pods toward feature-first modules.

Modern preferred structure:

```text
app/features/[feature-name]/
  components/
  services/
    feature.ts
    internal-feature/
    internal-business/
  state.ts
app/shared/
  components/
  services/
  states/
  helpers/
  modifiers/
app/routes/[route-path]/
  route.ts
  controller.ts
  template.hbs
app/data/
  models/
  adapters/
  serializers/
  transforms/
app/legacy/        # fallback only
apps/              # React MFEs
packages/          # shared React/MFE packages
```

## Resolver lookup priority

The custom resolver checks:
1. `app/data`
2. `app/shared`
3. `app/features`
4. `app/routes`
5. `app/legacy` fallback

This means a change can be resolved through non-standard paths. Always inspect `app/resolver.ts` and nearby call sites before assuming classic Ember layout. If repository summaries disagree with `app/resolver.ts`, treat the resolver source as canonical.

## Layer decision rules

- Cross-feature pure UI → `app/shared/components`.
- Cross-feature business behavior → `app/shared/services/[name].ts`, class `[Name]BusinessService`.
- Feature public API/UI orchestration → `app/features/[feature]/services/feature.ts`.
- Feature-only business behavior → `services/internal-business/[name].ts`, class `[Feature][Name]InternalBusinessService`. Private to the feature.
- Feature-only component-facing UI logic → `services/internal-feature/[name].ts`, class `[Feature][Name]InternalService`. Private to the feature.
- Feature reactive data → `state.ts`, modified only by the feature service.
- Route URL/model hooks → `app/routes/.../route.ts`, delegating to feature service.
- Ember Data schema/transport → `app/data`.
- Legacy routes/components/services → only when touching existing legacy code or migrating it.

## Dependency direction

Allowed high-level direction:

```text
Route -> Feature service -> Business service -> API/store/agent
Component -> Feature service / feature state read
Feature service -> Feature state write
Shared component -> no business service calls
Business service -> no UI/toastr/router/context
```

Forbidden:
- Component directly calling orchestrator/API/business service for feature behavior.
- Route directly loading business data beyond hook delegation.
- Business service importing UI services, toastr, router transitions, or feature-specific services.
- External feature importing another feature's internal services.
- Shared components importing any service.
- Feature/internal-feature components calling other feature services directly.

## Adding files

Prefer `yarn run ember-generate`; it knows the repo's paths and names for:
- Feature Service
- Feature State
- Internal Feature Service
- Internal Business Service
- Shared Business Service
- Shared State
- Feature Component
- Shared Component
- Route
- Helper
- Modifier
- Model

## Adding a new feature — step by step

When creating a new feature from scratch:

1. **Data model** (if needed): `app/data/models/[name].ts` — simple attrs/relationships only.
2. **Feature state**: `app/features/[feature]/state.ts` — `[Feature]State` with `@tracked` properties.
3. **Business services** (data/API logic):
   - `app/features/[feature]/services/internal-business/[name].ts` — feature-private data work.
   - Or `app/shared/services/[name].ts` — if cross-feature.
4. **Feature service**: `app/features/[feature]/services/feature.ts` — `[Feature]FeatureService` — public API, orchestrates business services, manages state, handles UI feedback.
5. **Components**: `app/features/[feature]/components/` — start with main entry point, add internals under `internal/`.
6. **Route**: `app/routes/[path]/route.ts` — thin adapter calling feature service.
7. **Route template**: `app/routes/[path]/template.hbs` — single `<Feature::[Name] ... />` call.
8. **Tests**: `tests/features/[feature]/` — integration for components, unit for services.
9. **Errors**: `app/features/[feature]/errors.ts` — domain-specific error classes.

Use `yarn run ember-generate` to scaffold files with correct names and paths.

## Definition of done

- File is in the narrowest correct layer.
- Public API crosses feature boundary only through `services/feature.ts`.
- Any new class name matches path-based lint expectations.
- Legacy surface area does not grow without a migration reason.
- Source evidence was checked when touching ambiguous resolver or boundary behavior.
