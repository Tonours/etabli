# Review profile — employer (employer/employer, frontend)

## Stack and commands

- **yarn 1.22.19** (`package.json:39`), Node **22.12.0** (`.nvmrc:1`, `package.json:91`).
- **Ember** `ember-source: ~4.12.0`, **octane** edition (`package.json:238,94`).
- **React 18 on the host** (`package.json:292-293`), **React 19 in the MFE** `user-settings-mfe` (`apps/user-settings-mfe/package.json:29-30`). Deliberate coexistence through `nohoist` (`package.json:19-20`).
- **Host tests**: `EMBER_ENV=test ember exam` (`package.json:72`), filter with `yarn ember exam --filter="..."`, coverage with `yarn test:coverage` (`package.json:74`). QUnit + mirage + sinon.
- **MFE tests**: `vitest run` (`apps/user-settings-mfe/package.json:16`) + Testing Library + msw (`:44-56`). No Jest/QUnit in this workspace.
- **Host lint**: `yarn lint` aggregates `lint:css` (stylelint on `app/legacy/pods`, `app/features`, `app/shared`), `lint:hbs` (ember-template-lint), `lint:js` (`package.json:51-63`).
- **MFE lint**: `eslint src --max-warnings 0` (`apps/user-settings-mfe/package.json:12`) — zero warnings tolerated, stricter than the host.
- **Typecheck**: `tsc --noEmit` with an extended heap (`package.json:87`), multi-workspace `yarn typecheck:all` (`package.json:88`).
- MFEs and packages are driven by **Nx**: `nx start|build|typecheck|test|lint <project>` (`package.json:60-79`).

## Architecture

- **Custom 5-level resolver**, order verified in `app/resolver.ts:9-16`: `data → shared → features → routes → legacy`.
- 39 folders under `app/features/` (`inbox`, `workflow-editor`, `workflow-visualizer`, `mcp-server`, `role`, `authentication`…).
- **Legacy lives under `app/legacy/pods/`** — not `app/pods/` (that path does not exist). `app/legacy` also holds `services/`, `mixins/`, `abstract-*`.
- React MFEs under `apps/`, shared packages under `packages/*` (`package.json:12-14`).
- ⚠️ The boundary details (shared cannot inject a service, the feature service is the only state mutator…) come from the skills and were **not re-verified** on a real feature beyond the resolver and the lint. Treat them as inferred.

## Verified conventions

- **`employer-custom/dependency-rules`** at error (`eslint.config.mjs:97`), implemented in `eslint-custom-rules/dependency-rules.js:26-56`: forbids importing a UI service (`business/notification`, `services/toastr`, `services/ui/*`) from an `internal-business`; forbids importing an `internal-business`/`internal-feature` outside the `services` folder of its feature.
- **`employer-custom/class-naming-based-on-path`** at error (`eslint.config.mjs:315-345`): `components/[path]/component.ts` → `Component` suffix, `services/internal-business/[name].ts` → `InternalBusinessService`, `services/feature.ts` → `FeatureService`, `app/services/business/[name]` → `BusinessService`.
  - ⚠️ **Real gap**: the legacy regexes target `app/pods/...`, while legacy lives under `app/legacy/pods/...`. **The rule never matches a legacy file** — naming is not enforced there despite the apparent config.
- **Absolute `client/...` imports required**, `allowSameFolder: false` (`eslint.config.mjs:100-107`).
- **`no-console`** allows `debug|info|warn|error` and blocks a bare `console.log` (`eslint.config.mjs:23-28`).
- **Bare `prop-types` forbidden**, go through `client/utils/prop-types-utils` (`eslint.config.mjs:79-83`). **`inject` from `@ember/service` forbidden** in favor of `service` (`:88-93`).
- **Template-lint** (`.template-lintrc.js`): `no-action` and `no-action-modifiers` set to `true` (`:32-33`), `no-implicit-this` with a named allowlist (`:46-60`), `template-length` max 250 lines (`:79-82`). `no-route-action` at **`warn`** with a `// To clean up` comment (`:87`) — not blocking.
- **`data-test-*` test selectors** — inferred from the skills, not from a real test read.
- ⚠️ Oversized test files observed: `tests/features/inbox/services/feature-test.ts` **125 KB**, `tests/features/inbox/components/creation-modal/component-test.ts` 39.8 KB.

## Tricky cases

1. **5-level resolver** (`app/resolver.ts:9-16`) — one name can resolve in `data`, `shared`, `features`, `routes` or `legacy`. Before asserting "which file is used", check the pattern for that type (`app/resolver.ts:30-140`), not a classic Ember layout.
2. **`class-naming-based-on-path` does not match the real legacy** — do not block a legacy PR on a class name that is not lint-enforced.
3. **Dual React 18/19 instance in Module Federation** — isolated through `nohoist` (`package.json:19-20`). An accidental dedupe or hoist breaks everything. (kb `mfe-dual-react-nohoist`, cited from `_index.md:50`, not reread in detail)
4. **MFE KB notes to read before judging a change** (index `~/work/brain/kb/_index.md:47-54`): MFE routing with `createBrowserRouter`+`basename` → blank page (fix: `memoryRouter`); Ember→React prop serialization without a cache; build-time CSS isolation without shadow DOM; `theme.css` v4 is authoritative for Tailwind tokens; reusing a router v6 instance leaks state between routes.
5. **`dependency-rules` breaks silently** when the import path does not exactly match `/internal-business/` or `/internal-feature/` (`eslint-custom-rules/dependency-rules.js:38-56`) — renaming a folder can disable the rule without an error. Check by hand on any service move.

## What we do NOT comment on

- **Non-conforming class names under `app/legacy/pods/...`** — the rule does not match that path, so it is neither a detectable violation nor a real signal.
- **`no-route-action` and `require-presentational-children`** at `warn` with `// To clean up` (`.template-lintrc.js:87-88`) — accepted legacy; do not require fixing them in a PR that does not touch them.
- **Host stack (QUnit/mirage/sinon) vs MFE stack (Vitest/Testing Library/msw)** — deliberate, not a defect to unify.
- ⚠️ Not enough verified evidence to list generated areas or Ember patterns that are "dated but correct". Do not fill this category with unsourced generalities.

## Priority review signals

1. **Layer boundary violation hidden by a rename/move** that escapes the `dependency-rules` regexes (`eslint-custom-rules/dependency-rules.js:26-56`) — it passes lint, so it passes CI, but silently breaks the architecture.
2. **Module Federation / MFE loading changes** (`apps/*`, host `app/components/micro-frontend/*`) that ignore the React 18/19 isolation — dual React instance, invalid hook call: invisible in unit tests, breaks in production.
3. **A change to `app/resolver.ts` or a name collision between `legacy` and one of the 4 modern levels** — silent at compile time, visible only at runtime through the wrong resolved file.
4. **An addition under `services/internal-business|internal-feature` missing from the `class-naming-based-on-path` mapping** (`eslint.config.mjs:315-345` — `internal-feature` is not in it): lint does not catch it, check the naming by hand.
5. **An addition to an already oversized test file** (125 KB observed) — passes CI but dilutes real coverage. Check the added test is targeted, not appended to a catch-all.
6. **MFE PR**: `--max-warnings 0` (`apps/user-settings-mfe/package.json:12`) — one unresolved local warning blocks this workspace's CI lint, unlike the host.
