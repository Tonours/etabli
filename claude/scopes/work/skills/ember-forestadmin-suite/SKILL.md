---
name: ember-forestadmin-suite
description: Route Ember/ForestAdmin frontend work to the correct specialized skill before coding.
version: 0.2.0
author: ForestAdmin Team
license: Proprietary
---

# Ember ForestAdmin Suite

Use this skill first for any task in `ForestAdmin/forestadmin` or a similarly large Ember app.

## Choose the primary skill

- New feature architecture, file placement, dependency boundaries → `ember-forestadmin-architecture`.
- Components, templates, actions, CSS, DOM modifiers → `ember-forestadmin-components`.
- Services, state, orchestration, business logic → `ember-forestadmin-services-state`.
- Routes, controllers, route templates, query params → `ember-forestadmin-routes`.
- Models, adapters, serializers, store, GraphQL/API integration → `ember-forestadmin-data`.
- Tests, fixtures, test selectors, ember-exam → `ember-forestadmin-testing`.
- Diagnosing bugs, resolver failures, store issues, test failures → `ember-forestadmin-debug`.
- Lint/typecheck/style failures or naming conventions → `ember-forestadmin-lint-style`.
- Moving legacy pods code into modern structure → `ember-forestadmin-migration`.
- React micro-frontends hosted by Ember → `ember-forestadmin-react-mfe`.
- `app/features/workflow-visualizer` → `ember-forestadmin-workflow-visualizer`.
- `app/features/workflow/services/standalone-package` → `ember-standalone-workflow-package`.

## Ambiguous task routing

When the task doesn't clearly fit one skill:

| Task description | Primary skill | Also consult |
|---|---|---|
| "Add a button that calls an API" | components (UI) + services-state (logic) | data (if new API) |
| "Create a new page" | routes + architecture | services-state, components |
| "Fix a failing test" | testing | depends on what's tested |
| "Move code from legacy" | migration | architecture (for target) |
| "Add a new Ember Data model" | data | services-state (business svc) |
| "Create a new feature" | architecture | all skills |
| "Style/layout issue" | lint-style + components | — |

For multi-layer tasks, start with the **outermost layer** and work inward:
route → component → service → business service → data.

## Default workflow

1. Inspect nearby files before editing. In this repo, local conventions beat generic Ember habits.
2. Check `app/resolver.ts`, `CLAUDE.md`, and nearby tests when a lookup path or layer boundary is unclear.
3. Respect the layer boundary. Most bad changes are dependency-direction mistakes.
4. Prefer custom generator output: `yarn run ember-generate` when creating new Ember app artifacts.
5. Add or update tests near the changed behavior.
6. Run the narrowest useful command first, then broaden only if needed.

## Repository commands

```bash
yarn
yarn start
yarn ember exam --filter="tests/path/to/test-file"
yarn lint:js
yarn lint:hbs
yarn lint:css
yarn typecheck
yarn test:coverage
yarn build
```

## Non-negotiables

- Do not put business logic in components, routes, controllers, templates, or states.
- Do not inject the Ember Data store into feature services; delegate data work to business services.
- Do not import `internal-business` or `internal-feature` services from outside their allowed boundary.
- Do not add new legacy pods code unless the task is explicitly in legacy maintenance.
- Do not bypass feature service APIs from components.

## Anti-patterns — common agent mistakes

| Mistake | Correct approach |
|---|---|
| Using `this.owner.lookup()` in tests | Use `getService()` from `client/tests/helpers/lookup` |
| Stubbing services in integration tests by default | Prefer real services + `setupMirage` for API-backed behavior; stub explicit UI callbacks or unavoidable boundaries only when that is the behavior under test |
| Putting store calls in feature service | Move to internal-business service |
| Importing another feature's internal service | Use the feature's public service API |
| Using `{{action}}` in templates | Use `{{on "click" this.method}}` |
| Using `@service` without explicit name for features | `@service('feature/inbox')` not `@service()` |
| Context booleans like `isInWorkspace` in components | Use explicit `@arg` to change behavior |
| Creating new files in legacy structure | Use modern feature/shared/routes/data paths unless maintaining an existing legacy surface |
| Business service calling toastr/router | Move UI side effects to feature service |
| Component directly mutating state | Pass action through feature service

## Definition of done

- The correct specialized skill was selected before coding.
- The non-negotiables were verified after changes.
