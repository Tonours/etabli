# Review profile — employer-server (employer/employer-server)

## Stack and commands

- **yarn 1.22.19**, Lerna monorepo + workspaces (`package.json:79-82,116,166`). Node **22.12.0** (`package.json:165-167`, `packages/private-api/package.json:86-88`).
- **Tests: Jest**, suites split by domain — `test:misc`, `test:ai`, `test:routes`, `test:services`, `test:stores`, `test:unit`, `test:externals` (`packages/private-api/package.json:54-72`). Root: `lerna run test` (`package.json:64`).
- **Lint**: ESLint 8 + `airbnb-base`/`airbnb-typescript`, `sonarjs`, `import`, `filenames`, `unused-imports` (`.eslintrc.ci.js:9-19,46`). Per package: `eslint --config=.eslintrc.ci.js --quiet --cache --cache-strategy content .` (`packages/private-api/package.json:76`). Prettier: `prettier --config ../../.prettierrc.json --check .` (`:78`).
- **Build**: `tsc` per package (`packages/private-api/package.json:24-27`), orchestrated by `lerna run build` (`package.json:56-59`).
- **Server**: Express 4 (`packages/private-api/package.json:129`), Sequelize 6 + PostgreSQL (`:156,162`), migrations through `sequelize-cli` (`:163`, scripts `db:migrate*` `package.json:72-75`).

## Architecture

- Packages: `private-api` (business core), `public-api`, `server`, `cloud-gateway`, `cloud-agent-manager`, `common`, `ai`, `ai-mcp`, `private-agent-api`.
- In `private-api/src`: `routes`, `middlewares`, **no `controllers`** — routes call `services`/`domain` directly, with `fetchers` as an intermediate layer (`.claude/examples/code-patterns.md:38-92`).
- **Dependency injection by naming convention**: factories receive `{ assertPresent, ...deps }` and register in a `context` (`context/build-business-services.js`, `context/build-fetchers.js`). Every service/middleware/fetcher calls `assertPresent({...})` on entry (`code-patterns.md:12,42,106`).
- **Business errors**: a `BusinessError` hierarchy in `src/utils/errors/*-errors.ts`, one file per domain (41 files).
- **HTTP chain**: `errorTranslator` (`src/utils/error-translator-http.ts:47-88`) maps an error class → HTTP constructor, wired in `src/make-configure-rest-errors.js:18-32` — OAuth validation (`:21`), `catchErrorsValidation` (`:23`), `errorsBusiness.catch` (`:26`), `scimErrorsHandler` (`:27`), `catchExpectedError` (`:28`), `catchUnexpectedErrors` as the last net (`:31`).
- **Migrations**: `packages/private-api/migrations/*.js`, named `YYYYMMDDHHMMSS-slug.js`, exposing `up`/`down` (`migrations/20250716081955-add-inbox-type-to-layout-changes.js:6-70`).

## Verified conventions

- **File naming enforced by ESLint** `filenames/match-regex` per folder: routes `^[-a-z]+-route$`, stores `^[-a-z]+-store$`, serializers `^[-a-z]+-serializer$`, deserializers `^[-a-z]+-deserializer$`, migrations `^20[0-9]{12}-[-a-zA-Z0-9]+$`, errors `^[-a-z]+-errors$` (`packages/private-api/.eslintrc.ci.js:130-182`).
- **`bluebird` explicitly forbidden** — "Use native promises" (root `.eslintrc.ci.js` `:163-173`, package `:47-84`). Any `bluebird` in a diff is a signal.
- **Internal imports through the package root**, never `dist`/`src` (`no-restricted-imports` on `@employer/*`).
- **Isolated migrations**: `import/no-restricted-paths` forbids importing `models`, `services`, `utils` (except `migrations-tools.js`) from `migrations/` — they must not depend on code that changes (`packages/private-api/.eslintrc.ci.js:96-118`).
- **`no-explicit-any`**: `warn` in private-api (package `.eslintrc.ci.js` `:27`) but `error` at the root (`:71-76`). Verified divergence.
- **Business error** = a class extending `BusinessError` (`src/utils/errors/common-errors.ts:4-15`), one subclass per case.
- **Tests**: `makeContext()` builds every Jest mock (`liana-permission-v4-cache-service.unit.test.ts:10-34`), manual instantiation with a cast (`:40-41`), assertion that `assertPresent` receives the deps (`:44`), AAA per `it` (`:50-72`). `*.unit.test.ts` for isolated unit tests, `*.test.ts` for route/service tests.
- **Transactional migrations**: `transactionWithLock(queryInterface, async () => {...})` (`migrations/20250716081955-add-inbox-type-to-layout-changes.js:8,40`). Documented counter-example (a Sequelize transaction without passing `{transaction}` to the query) in `.claude/examples/code-patterns.md:187-205`.

## Tricky cases

1. **Joi runtime ≠ types** (kb `private-api-joi-15`) — `private-api` runs Joi 15.1.1 bundled by `celebrate@10.1.0`, but the installed types are `@types/hapi__joi@17`. `.greater()` must start from `Joi.date()`, not `Joi.string()`, or the module crashes on load. Diagnostic signature: everything that boots the context crashes, isolated suites pass. `src/domain/bff/bff-api-keys-validator.ts:65`.
2. **`loadFixtures` does a DROP** (kb `test-loadfixtures-drop`) — `sync({force:true})` on two connections: a second `FixtureBuilder`/`loadFixtures` in the same test DROPs what the first one seeded, including the caller's JWT session → a misleading 401 instead of the expected 403/422. `test/helpers/load-fixtures.js:105-112,148-153`.
3. **Non-idempotent enum migration replay** (kb `migration-enum-replay`) — `ALTER TYPE ... ADD VALUE` without `IF NOT EXISTS`: replaying `up` without going through `down` breaks. After a squash, `SequelizeMeta` can keep a ghost record that blocks `db:migrate:undo`. `migrations/helpers/premium-feature.js:106,111,119,176,202,222`.
4. **Permissions v4: never an individual boolean flag** (kb `employer-permissions-v4`) — the server never emits `true` for an isolated CRUD right, only `{roles:[...]}` (except the whole `/environment` response when `areRolesDisabled`). A literal `true` on an individual right breaks the client contract. `src/services/liana-permission-v4-service.ts:23-34`.
5. **Fork fidelity to the upstream bug** (kb `bff-fork-fidelity-over-robustness`) — the permission evaluator fork in `agent-bff` deliberately reproduces an upstream crash; "fixing" it locally breaks the drift gate. It concerns `agent-nodejs`, but any PR aligning both behaviors must check this precedent before hardening a similar case here.

## What we do NOT comment on

- **`no-explicit-any` at `warn`** in private-api (package `.eslintrc.ci.js` `:27`) — an accepted divergence from the root, not an oversight to flag PR by PR.
- **`sonarjs/no-duplicate-string`, `no-identical-functions`, `no-nested-template-literals` disabled** in private-api (`.eslintrc.ci.js:86-88`) — do not flag duplicated strings/functions.
- **Legacy `.js` files**: the root override disables `no-unsafe-*`, `no-var-requires`, `restrict-*`, `return-await` (`.eslintrc.ci.js:304-327`). Pre-TypeScript code; do not ask for its migration in an unrelated PR.
- **`no-console` allows `debug/info/warn/error`** (`.eslintrc.ci.js:147-152`) — deliberate use, not a forgotten `console.log`.
- **`migrations/*.js` disables `no-console`** (`packages/private-api/.eslintrc.ci.js:171`) — migration logs are expected.

## Priority review signals

1. **An enum or column migration without an idempotent `down`, or without a transaction/lock wrapper** — breaks a production deploy without showing in a single local CI run. Check `transactionWithLock` (or an explicit transaction) and a symmetric `down`.
2. **A `bluebird` import or a direct import from `dist`/`src` of an `@employer/*`** — forbidden by ESLint, but a stale lint cache can let it through.
3. **A new business error class not mapped in `error-translator-http.ts`** — a `BusinessError` without a branch in the switch (`src/utils/error-translator-http.ts:50-85`) falls into `catchUnexpectedErrors` and surfaces as a generic 500. Passes unit tests, breaks the HTTP contract in integration.
4. **Two `FixtureBuilder`/`loadFixtures` in the same test** — flaky in CI; typical symptom: an unexpected 401 on a cross-project test.
5. **A change to `/liana/v4/permissions/*` introducing a literal `true` on an individual CRUD right** — breaks the frontend contract, and no server test catches it.
