# Review profile — employer-for-zendesk (employer/employer-for-zendesk)

## Stack and commands

- **Package manager**: yarn (implicit, `package.json:20`). No `packageManager` field, no `.nvmrc`.
- **Test**: **vitest** — `"test": "vitest"`, `"test:run": "vitest run"`, `"test:coverage": "vitest run --coverage"` (`package.json:16-18`), `vitest@^4.1.0` (`package.json:71`). The only employer repo on vitest, confirmed in the code.
- **Lint**: `eslint src --ext ts,tsx --report-unused-disable-directives` (`package.json:9`), legacy `.eslintrc.cjs` config (not flat config), `eslint@^8.45.0`.
- **Typecheck**: `tsc --noEmit` (`package.json:15`), `strict: true`, `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch` (`tsconfig.json:14-17`).
- **Build**: `tsc && vite build` (`package.json:8`), Vite `^6.4.3`, **React `^18.3.0`** (`package.json:37`) — not React 19.
- **Pre-submission gate**: `node scripts/pre-submission-checks.js && yarn typecheck && yarn lint && yarn test:run && yarn build` (`package.json:20`).
- **Zendesk tooling**: `zcli apps:server dist` (`package.json:7,14`), `zcli apps:validate dist` (`package.json:19`), `yarn package` = build + zip (`package.json:22`). Manifest: ZAF app `support:ticket_sidebar`, `frameworkVersion: 2.0`, a single `employerAgentUrl` parameter (`manifest.json:1-34`).
- `dist/` is built and zipped for the Zendesk marketplace, not deployed continuously.

## Architecture

Strict onion architecture.

- **ZAF entry**: `src/main.tsx:14-28` — `ThemeProvider` (Garden) > `QueryProvider` > `ZAFProvider` > `AuthProvider` > `AppErrorBoundary` > `App`. `initMonitoring()` before the render (`main.tsx:12`).
- **UI** (`components/`): pure rendering, no direct service call. Folders `actions/`, `common/`, `layout/`, `records/`, `screens/`, `search/`.
- **Hooks** (`hooks/`): React Query + services orchestration.
- **Services** (`services/`, `utils/`): pure functions, zero React dependency. `employer-client.ts:200-229` = low-level MCP JSON-RPC client, POST `{baseUrl}/mcp`.
- **Two distinct API bases**: `employerApiService` → `VITE_employer_API_URL` (SaaS, OAuth/metadata/AI proxy); `employerService`/`employerClient` → the agent URL from settings, `/mcp` (data ops, actions).
- **Auth**: PKCE S256, DCR on the SaaS (`/oauth/register`), authorize/token on the agent (`oauth-service.ts:120-289`). Tokens in localStorage namespaced by agent URL (`scoped-storage.ts`), PKCE verifier/state in sessionStorage.

Boundaries to watch: a direct service call from a component is a violation; so is fetch/parsing logic in a hook. The strict `ZendeskTicket` typing (`src/types/index.ts:1-21`, `requester` not optional) against an unvalidated cast from the ZAF SDK (`ZAFContext.tsx:99`) is a fragile boundary.

## Verified conventions

- **Strict TypeScript** (`tsconfig.json:14`), but **`no-explicit-any` is at `warn`, not `error`** (`.eslintrc.cjs:36`). The repo's `CLAUDE.md` claims "no `any`" — a real gap between the declared convention and the enforced rule. Lint does not block it.
- **`no-console`: `error`** (`.eslintrc.cjs:38`) — `console.log`/`console.warn` fails lint unless explicitly `eslint-disable`d.
- **Unused vars/args**: error, `^_` escape (`.eslintrc.cjs:32-35`).
- **Garden components required**: `@zendeskgarden/react-*` (`package.json:26-35`).
- **HTML sanitization**: `stripHtmlTags` isolated in `src/utils/sanitize.ts:1-5`, `DOMPurify.sanitize(html, { ALLOWED_TAGS: [] })` — full strip, single entry point.
- **No client-side secret**: `employer-client.ts:213-229` only carries the user's OAuth bearer.
- **Tests**: vitest + jsdom + testing-library + MSW (`package.json:44-47,64-67`). ⚠️ The colocation and factory convention was **not** verified on real test code — only claimed by the repo's `CLAUDE.md`. Do not rely on it to judge a test PR without checking.

## Tricky cases

1. **Refresh/logout gating** (kb `zendesk-refresh-logout-gating`, verified) — an overly broad `catch` destroyed the refresh token on a network blip. Logout fires only when `isSessionRejected`, which requires an **explicit OAuth error code**, not just a 401. A proxy 401 without an OAuth body must never trigger `logout()`/`clearAll()`. Sources: `AuthContext.tsx:287-311,338-340`, `oauth-service.ts:64-85,267-275`, `oauth-session.ts:130-137`.
2. **Per-ticket error scoping** (kb `zendesk-error-ticket-scoping`) — the sidebar is reused across tickets. `ticketEpochRef` is incremented in `useLayoutEffect` (not `useEffect`); an error is published only if the epoch has not moved (`employerContext.tsx:103-109,166-206`). Purge the AI analysis cache **by prefix**, never `exact: true`: the real key has a 4th element `aiScopeKey` missing from the helper (`useAIQuery.ts:14-40`, `DataTab.tsx:119-154`).
3. **App version header** (kb `zendesk-app-version-header`) — a custom header passes on the MCP side (`origin: '*'`) but silently breaks on the BFF side until `ALLOWED_HEADERS` is updated in `agent-nodejs`: the CORS preflight is blocked before the request is sent.
4. **Operator lesson cache** (kb `zendesk-operator-lesson-cache`, ADR accepted) — the three modes `strict|exact|fuzzy` must stay disjoint in the key (`collection:field:mode`). Going back to 2 buckets would leak a `Contains` lesson learned in fuzzy mode into an `exact: true` call. `employer-service.ts:55-67,116,205-220`.
5. **`externalId` heuristic** (kb `zendesk-external-user-id-heuristic`, `zendesk-external-id-role`) — detection by **tokens**, not `endsWith`: three cumulative constraints + a `super|power|admin|multi` denylist. Any change to `isExternalUserIdFieldName` (`schema-profiles.ts:27-45`) must re-test the `superuser` false positive.
6. **Abandoned contextField mapping** (kb `zendesk-context-field-mapping`, ADR superseded) — `contextField` existed in v1.0.2 and was removed in v1.1.0; `manifest.json` now carries only the URL parameter (`manifest.json:25-33`). Matching stays heuristic. Treat any PR that reintroduces a declarative mapping as reopening a decision, not as a detail.
7. ⚠️ **Missing KB note**: `zendesk-qa-environment` is indexed (`kb/_index.md:87`) but **not found** on disk. Do not rely on its assumed content.
8. ⚠️ **Stale KB note**: `zendesk-requester-id-matching` is `status: stale` — it describes the state *before* the PRD-834 fix. Do not cite it as describing current behavior.

## What we do NOT comment on

- **`fail-open` on 403 in `probeAccessibleActions`** (`action-permissions.ts:20-36`): a deliberate optimistic choice, unless the PR touches that file.
- **Hard production fallback on `VITE_employer_API_URL`/`VITE_employer_APP_URL`** (`oauth-service.ts:105,280`): a documented dev config trap, not a code defect.
- **`X-Request-Id` declared but never read on the BFF side**: an `agent-nodejs` problem, out of scope here.
- **ZAF platform constraints**: generated `dist/` (do not review), `manifest.json` in strict JSON imposed by `zcli` (limited parameter types), `client.request()` for every outgoing call (mandatory CSP workaround, not an anti-pattern).
- **`transport === null` in `monitoring.ts`**: documented near-dead code.
- **`popupRef.current.close()` in an empty `try/catch`** (`AuthContext.tsx:308-313`): a deliberate silent cross-browser throw, commented `/* browser-dependent */`.

## Priority review signals

The real ZAF environment (iframe, CSP, Zendesk proxy, reused sidebar) differs sharply from the jsdom/MSW tests.

1. **OAuth refresh / rejected-session detection** — concrete risk: destroying the refresh token on a false positive, forcing a full popup on the customer side. The tests do not simulate the iframe remounting on every ticket navigation. Check that `isSessionRejected` stays the only discriminant and requires a non-empty `oauthError`.
2. **Shared state without per-ticket scoping** — the sidebar is a single reused instance; unscoped state leaks from one ticket to the next in production, invisible in a test that mounts a single ticket. Does every new piece of state need an epoch or a key scoped by `ticket.id`?
3. **Deterministic matching** (`schema-profiles.ts`, `deterministic-matcher.ts`, `record-search.ts`) — a documented false positive/negative trade-off with an explicit preference for false negatives: a false positive exposes another customer's record to a support agent. The real risk is a collision (generic id, `external_id` without a namespace) for a customer with a divergent schema.
4. **A new header or outgoing network call** — iframe CSP + CORS closed on the BFF side (static `ALLOWED_HEADERS`). A header added on the client without a backend change breaks in production; MSW does not simulate a real preflight.
5. **`any` passes lint** (`warn` only) while the repo's `CLAUDE.md` forbids it — manual vigilance; the tooling does not block it.
