---
name: ember-employer-lint-style
description: Fix and avoid employer lint, typecheck, class naming, template, and SCSS convention failures.
version: 0.2.0
author: employer Team
license: Proprietary
---

# Ember employer Lint and Style

Use this skill before/after edits that may trigger lint/typecheck/style rules.

## Commands

```bash
yarn lint
yarn lint:js
yarn lint:js:fix
yarn lint:hbs
yarn lint:hbs:fix
yarn lint:css
yarn lint:css:fix
yarn typecheck
```

## TypeScript/class naming

A custom ESLint rule (`employer-custom/class-naming-based-on-path`) auto-fixes a subset of class names to match file path and suffix. It errors on mismatch for the configured paths in `eslint.config.mjs`; use nearby files and `yarn run ember-generate` for paths not yet enforced.

**Naming lookup table:**

| File path | Expected class name |
|---|---|
| `app/features/[feature]/services/feature.ts` | `[Feature]FeatureService` |
| `app/features/[feature]/services/internal-business/[name].ts` | `[Feature][Name]InternalBusinessService` |
| `app/features/[feature]/components/[path]/component.ts` | `[Feature][Path]Component` |
| Legacy `app/services/business/[name].ts` | `[Name]BusinessService` |
| Legacy `app/pods/[path]/route.ts` | `[Path]Route` |
| Legacy `app/pods/[path]/controller.ts` | `[Path]Controller` |

Examples:
- `app/features/inbox/services/feature.ts` → `InboxFeatureService`
- `app/features/inbox/services/internal-business/inbox-manager.ts` → `InboxInboxManagerInternalBusinessService`
- `app/features/workflow-editor/components/renderer/flat/component.ts` → `WorkflowEditorRendererFlatComponent`

Run `yarn lint:js:fix` to auto-fix naming mismatches.

Current architectural docs still expect shared services to be named `[Name]BusinessService`, route classes `[Path]Route`, and controllers `[Path]Controller`, but those modern paths are not covered by this specific ESLint rule today.

## Dependency lint rules

Custom dependency rules reject:
- UI/toastr service imports from `internal-business`.
- importing another feature's `internal-business` service from outside that feature services folder.
- importing `internal-feature` service from outside the feature path.

Fix by moving logic to the right layer, not by disabling the rule.

## Template lint rules to remember

The repo extends recommended, a11y, and Prettier template lint rules. Notable rules:
- no implicit `this` except explicit legacy allowlist.
- no `{{action}}` / action modifiers.
- no route actions warning.
- template max length around 250 lines.
- named block naming kebab-case.
- accessibility checks: labels, iframe title, alt text, ARIA validity.

## SCSS/stylelint

Feature component SCSS root selector should match component path:

```text
app/features/foo/components/bar/baz/style.scss
.c-feature-foo-bar-baz { ... }
```

The custom stylelint rule can autofix some root selector mismatches.

## React package config

React packages/MFEs use shared `@employer-admin/config` with strict ESLint 9 flat config:
- no `any` by default.
- unused vars as errors.
- exhaustive React hook deps.
- accessibility checks.
- import ordering and Prettier integration.
- MFE workspaces are ignored by the root app ESLint config and validated through their own `nx`/workspace commands.

## Fix strategy

1. Run the narrow command for changed surface.
2. Prefer auto-fix for formatting/naming.
3. For boundary errors, refactor layers; do not suppress.
4. Run `yarn typecheck` after TypeScript signature or service boundary changes.

## Definition of done

- Relevant lint command passes.
- Typecheck passes for TS API changes.
- No new eslint-disable unless clearly legacy-bound and locally justified.
