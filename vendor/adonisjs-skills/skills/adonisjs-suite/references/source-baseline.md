# Suite maintenance source baseline

Use this reference only when auditing or refreshing version-sensitive guidance in the suite.

## Source hierarchy

1. Stable official AdonisJS documentation for behavior and supported setup.
2. Official AdonisJS or Tuyau repositories and release notes for changes not yet reflected in guides.
3. The public npm registry for package existence, stable tags, and current versions.
4. Current application code for local conventions, never as proof of upstream behavior.

When sources disagree, do not turn the disagreement into an install command. Prefer the dedicated guide plus a package that exists on npm, and record the uncertainty.

## Audited snapshot

Verified on 2026-08-12; refresh live before making current-version claims.

- AdonisJS 7 baseline: Node.js 24+, npm 11+, TypeScript 5.9 or 6.0, ESLint 10, and Vite 7 when applicable.
- Stable npm tags observed: `@adonisjs/core` 7.4.0, `@adonisjs/queue` 0.6.2, `@tuyau/core` 1.2.2, `@tuyau/react-query` 1.1.0, `@tuyau/vue-query` 1.1.0, and `@tuyau/superjson` 1.0.0.
- `@adonisjs/queue` remains experimental and should be pinned when adopted.
- Core health checks import from `@adonisjs/core/health`; Redis, Lucid, and other integrations expose their own checks from their packages.
- The dedicated TanStack Query guide uses the published `@tuyau/react-query` and `@tuyau/vue-query` adapters. A related-resources paragraph elsewhere mentions `@tuyau/tanstack-query`, which was not published on npm at audit time.

## Primary pages

- AdonisJS v6 to v7: https://docs.adonisjs.com/v6-to-v7
- Health checks: https://docs.adonisjs.com/guides/digging-deeper/health-checks
- Queues: https://docs.adonisjs.com/guides/digging-deeper/queues
- Testing: https://docs.adonisjs.com/guides/testing/introduction
- Transformers: https://docs.adonisjs.com/guides/frontend/transformers
- Tuyau API client: https://docs.adonisjs.com/guides/frontend/api-client
- Tuyau with TanStack Query: https://docs.adonisjs.com/guides/frontend/tanstack-query

## Live verification

```bash
npm view @adonisjs/core version dist-tags --json
npm view @adonisjs/queue version dist-tags --json
npm view @tuyau/core version dist-tags --json
npm view @tuyau/react-query version dist-tags --json
npm view @tuyau/vue-query version dist-tags --json
npm view @tuyau/superjson version dist-tags --json
```

Keep patch versions in this dated snapshot, not in procedural `SKILL.md` guidance.
