---
name: ember-forestadmin-migration
description: Modernize ForestAdmin legacy pods code into feature/shared/routes architecture safely.
version: 0.2.0
author: ForestAdmin Team
license: Proprietary
---

# Ember ForestAdmin Migration

Use this skill when moving or adapting code from `app/legacy` to modern `app/features`, `app/shared`, `app/routes`, or `app/data`.

## Migration posture

This repo is in active migration. Do not rewrite everything. Move the smallest coherent slice that the task requires.

## Before moving code

1. Identify how the current file is resolved: route/component/service/helper/model/etc.
2. Check call sites and template invocations.
3. Decide whether the target is feature-specific or shared.
4. Preserve route names and public component API unless the task explicitly changes them.

## Target mapping

- Legacy route/controller/template → `app/routes/[route]/...`, with template calling a feature component.
- Legacy component used by one feature → `app/features/[feature]/components/...`.
- Legacy component reused broadly and pure UI → `app/shared/components/...`.
- Legacy service with business/API behavior → `app/shared/services` or feature `internal-business`.
- Legacy service with UI orchestration → feature service/internal-feature service.
- Legacy model/adapter/serializer/transform → `app/data/...`.

## Resolver warning

Because legacy fallback remains active, duplicate names can cause confusing resolution. After migration:
- remove or clearly stop using the legacy artifact only when safe.
- check resolver priority and import paths.
- update invocations to `feature/...` or `shared/...` naming as needed.
- verify route/controller/template resolution against `app/resolver.ts`; source beats older architectural summaries.

## Behavior preservation

- Keep tests green before broad cleanup. **Preserve behavior** during migration.
- Add characterization tests around risky legacy behavior if coverage is weak.
- Do not combine migration with feature redesign unless explicitly asked.

## Migration steps for a legacy route

Legacy routes like `app/legacy/pods/project/route.ts` often inject 10-15 services and contain business logic. Migrate progressively:

1. **Create feature service** — move orchestration logic from route hooks (`model`, `beforeModel`, `afterModel`) into `app/features/[feature]/services/feature.ts`.
2. **Extract business services** — pure API/store logic goes to `internal-business/`. Keep the route delegating to feature service.
3. **Create feature state** — if the route manages transient data, add `state.ts`.
4. **Move controller logic** — strip the legacy controller to `queryParams` only. UI state moves to feature service/state.
5. **Replace template** — legacy template with many components → single `<Feature::[Name] @model={{this.model}} />`.
6. **Create modern route** — `app/routes/[path]/route.ts` with hooks delegating to feature service.
7. **Remove legacy file** — only after the modern replacement resolves correctly.

Do not try to move everything at once. Each step should keep tests green.

## Definition of done

- Modern location matches architecture rules.
- Imports/invocations use modern resolver paths.
- Legacy fallback no longer accidentally shadows the new file.
- Focused tests cover migrated behavior.
- Migration and behavior changes are not mixed in one PR unless explicitly requested.
