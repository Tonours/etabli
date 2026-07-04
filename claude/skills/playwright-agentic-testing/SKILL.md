---
name: playwright-agentic-testing
description: Build, run and repair framework-agnostic Playwright tests as an agentic feedback loop for frontend applications.
---

# Playwright Agentic Testing

Use this skill when asked to create, extend, debug or review Playwright tests in this kit.

## Workflow

1. Inspect `APP_BASE_URL`, `PW_WEB_SERVER_COMMAND` and `PW_WEB_SERVER_URL`.
2. Read the relevant spec in `specs/` or create one from `specs/template.md`.
3. Generate or update tests under `tests/`.
4. Use helpers from `fixtures/` and `support/`.
5. Run the narrowest matching command.
6. If red, read trace/report/dossier before editing.
7. Rerun the changed test and then the relevant tag suite.
8. When target inputs are missing, run `npm run qa:targets` to create local Generic/static, Vite, React, Vue, SvelteKit, Next.js and Ember targets under `/tmp/playwright-agentic-kit-targets`.

## Rules

- Prefer `getByRole`, `getByLabel`, `getByText` and `getByTestId`.
- Use `test.step` for trace readability.
- Keep the suite framework-agnostic; put framework notes in `docs/adapters/`.
- Do not add arbitrary sleeps.
- Do not weaken assertions to pass.
- Do not skip without a documented product or environment reason.
- Preserve artifacts for the next agent.
- Use `/tmp/playwright-agentic-kit-targets/logs/qa-target-matrix.json` as the source of truth for target matrix evidence.
- Validate generated failure dossiers with `npm run validate:dossier -- test-results/failure-dossiers/latest.json` when debugging a failing QA scenario.

## Commands

```bash
npm run test:smoke
npm run test:a11y
npm run test:visual
npm run test:perf
npm run test:network
npm run test:hybrid
npm run qa:targets:setup
npm run qa:targets:matrix
npm run qa:targets
npm run validate:dossier -- test-results/failure-dossiers/latest.json
npm run validate
```

## Stop And Report

Stop when the target app is unreachable, credentials are missing, seed data cannot be created, or the evidence contradicts the requested behavior. Report observed facts, assumptions, command output, artifacts and next input needed.
