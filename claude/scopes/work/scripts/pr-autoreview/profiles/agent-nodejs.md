# Review profile — agent-nodejs (employer/agent-nodejs)

## Stack and commands

- Package manager: **yarn 1.22.19** (`package.json:4`). **Lerna + yarn workspaces** monorepo (`package.json:52-55`, `workspaces: ["packages/*", "packages/workflow-executor/example"]`).
- Node: `.nvmrc` = `24.10`. `workflow-executor` requires `"engines": {"node": ">=22.12.0"}` (`packages/workflow-executor/package.json:9-11`); `yarn workspace …` refuses below that threshold, local workaround `YARN_IGNORE_ENGINES=1`.
- Test: **Jest** (`package.json:49`), config `jest.config.ts:11`: `testMatch: ['<rootDir>/packages/*/test/**/*.test.ts']` — tests **not colocated**, under `test/` mirroring `src/`. Global setup `jest-extended/all` (`jest.config.ts:12`).
  - The `agent` package runs forced ESM: `"test": "NODE_OPTIONS=--experimental-vm-modules jest"` (`packages/agent/package.json:46`).
  - Per package: `yarn workspace @employer/<pkg> test -- <path or -t "name">`.
- Lint: `"lint": "lerna exec --parallel eslint src test"` (`package.json:46`), extends `airbnb-base`, `airbnb-typescript/base`, `plugin:@typescript-eslint/recommended`, `plugin:prettier/recommended`, `plugin:jest/recommended` (`.eslintrc.js:6-12`).
- Build: `"build": "lerna run build"` (`package.json:43`), `tsc` per package.
- No root `typecheck` script — the build doubles as type checking.

## Architecture

24 packages under `packages/*`.

- `agent` — SDK entry point, `createAgent()`, orchestrates HTTP + customizer + services. Depends on `datasource-customizer`, `datasource-toolkit`, `employer-client`, `mcp-server` (`packages/agent/package.json:16-20`).
- `mcp-server` — OAuth MCP server, streamable HTTP transport, RPC tools toward the live agent. Depends on `agent-client`, never on the data directly.
- `agent-client` — RPC client toward a running agent (consumed by `mcp-server`, `workflow-executor`).
- `employer-client` — SDK toward the employer SaaS API: permissions, scopes, OIDC, schema push, activity logs. The whole HTTP layer goes through `ServerUtils`.
- `workflow-executor` — runs workflow steps on the customer's infrastructure. Node ≥22.12.
- `datasource-toolkit`, `datasource-customizer` — base datasource layer + customization.
- `datasource-sql|sequelize|mongo|mongoose|replica|zendesk|dummy|demo-fintech` — implementations.
- `ai-proxy` — LLM proxy (consumers never use `@langchain/core` directly).
- `plugin-aws-s3`, `plugin-export-advanced`, `plugin-flattener`, `employer-cloud`, `agent-toolkit`, `agent-testing`, `_example`.

The boundary that matters: `agent` never handles collections directly; it delegates to `datasource-customizer`. A data logic change in `agent/src/routes` that bypasses the customizer is suspect.

## Verified conventions

- **Tests not colocated**, under `test/` mirroring `src/` (`jest.config.ts:11`).
- **Precise assertions**: `toHaveBeenCalledWith` with exact arguments, not a bare `toHaveBeenCalled()` (`CLAUDE.md:63-73`; example `packages/mcp-server/test/tools/get-action-form.test.ts:50-54`).
- **Whole-module mocks**: `jest.mock('../../src/utils/agent-caller')` (`packages/mcp-server/test/tools/get-action-form.test.ts:11`).
- **Export**: `export default class XxxRoute extends CollectionRoute` (`packages/agent/src/routes/access/list.ts:8`), one file = one route/one tool.
- **Enforced import order**: groups `type`, then `[builtin, external]`, then `[internal, sibling, parent, index, object]`, alphabetized, a blank line between groups (`.eslintrc.js:39-50`).
- **Type-only imports forced**: `@typescript-eslint/consistent-type-imports` at `error`, `fixStyle: separate-type-imports` (`.eslintrc.js:60-63`).
- **`mcp-server` requires `.js` extensions** on MCP SDK imports (`.eslintrc.js:124-146`). An import without `.js` is a regression, not a style choice.

## Tricky cases

1. **Authorization gap in `list` + relation projection** — `packages/agent/src/routes/access/list.ts:14,16` checks `assertCanBrowse`/`getScope` only on `this.collection`, never on a projected related collection; `list-related.ts:20,23` does it correctly on `foreignCollection`. **Reconfirmed on HEAD.** Scrutinize any diff on `list.ts` that adds a relation projection. (kb `agent-list-relation-authz-gap`)
2. **snake_case vs PascalCase operator casing** — `packages/agent/src/routes/capabilities.ts:60-67,87-92` converts to snake_case, `packages/mcp-server/src/schemas/filter.ts:3-48` expects a PascalCase enum (44 operators). A change on one side without the other silently breaks MCP filtering. (kb `employer-capabilities-operators`)
3. **No operator-vs-field validation in the MCP `list.ts`** — `filterSchema` is global, not per field. An accepted gap (documented YAGNI), not an omission to fix.
4. **Action slug collision gated by a flag** — `packages/agent/src/utils/employer-schema/generator-collection.ts:47-72`: `assertNoActionSlugCollision` runs only when `useUnsafeActionEndpoint` is on. (kb `action-slug-collision`)
5. **24h cache of the standalone MCP schema** — `packages/mcp-server/src/utils/schema-fetcher.ts:31-48`, `ONE_DAY_MS` without invalidation. Inserting an action in the middle of the schema can run the wrong action for up to 24h.
6. **workflow-executor, idempotency**: write-ahead log `idempotencyPhase: executing → done`. An error inheriting from `WorkflowExecutorError` instead of a boundary error is silently swallowed by `base-step-executor.ts`. Check the inheritance of any new error type.
7. **workflow-executor, config**: never `process.env` outside `cli-core`/`tracing.ts`. This regression already happened (`employer_EXECUTOR_ENCRYPTION_KEY` read in `crypto/`).
8. **Two parallel customizer stacks** (user-facing + no-code): a change in `buildRouterAndSendSchema()` must be checked on both.
9. **Adding an MCP tool = 3 coordinated edits** in `server.ts` (`ToolName` union, `allTools`, `allToolNames`). A PR touching only one or two of them is incomplete.

## What we do NOT comment on

- **Import cycles**: `'import/no-cycle': 'off'` (`.eslintrc.js:100`), accepted for types.
- **`console.debug/info/warn/error`**: allowed (`.eslintrc.js:91`). Only `console.log` is forbidden.
- **`class-methods-use-this` disabled** (`.eslintrc.js:78`) — a method that does not use `this` is a deliberate choice.
- **`consistent-return` disabled** (`.eslintrc.js:97`) in favor of TS typing.
- **`mountOn*` takes `any`** on purpose: the HTTP frameworks are peer/dev deps, so the agent stays agnostic.
- **No operator-vs-field validation** (`mcp-server/list.ts`): documented YAGNI.
- **`UnsupportedActionFormError` never thrown** in `workflow-executor/src`: accepted and documented dead code.

## Priority review signals

1. **Authorization regression in `access/`** — any diff on `packages/agent/src/routes/access/*.ts` or `relation-route.ts`: check `assertCanBrowse`/`getScope` on **every** collection actually read, not only the route's own.
2. **Route and middleware order** — routes are sorted by `RouteType` so logger/error/auth load before private routes. The order carries meaning; an alphabetical sort breaks production without a failing test.
3. **Idempotency of mutating steps** (workflow-executor) — a new mutating path that skips `checkIdempotency()` doubles side effects in production (payment, action fired twice).
4. **mcp-server 24h cache** — reordering actions in the agent schema generator breaks the MCP for up to 24h after deploy, and no agent test sees it.
5. **Operator casing capabilities ↔ MCP filterSchema** — a change on one side without the other: no compile error, no failing test, broken in production.
6. **Stale `agent-client` → `workflow-executor` build cache** — a stale dist served by the lerna/nx cache produces misleading "no exported member" errors. Green CI ≠ fresh build.
