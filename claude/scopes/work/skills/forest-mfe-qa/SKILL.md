---
name: forest-mfe-qa
description: Manual browser QA of the forestadmin-poc React MFEs (user-settings, notes-listing) via Claude in Chrome — no Playwright. Use when the user wants to QA / smoke-test the MFEs in the real app, verify a change works in the browser, check MFE flows visually, or confirm no console errors after touching apps/user-settings-mfe or apps/notes-listing-mfe.
---

Smoke-test the two Forest MFEs by driving a real Chrome against the dev app: start the app, walk the changed flows, screenshot each state, assert zero console errors. This is exploratory browser QA — you drive and observe, you do not write test files. For scripted tests use `ember-forestadmin-testing` (QUnit) or `playwright-test-generation`.

The MFEs live in `apps/user-settings-mfe` and `apps/notes-listing-mfe`; they mount into the Ember host via Module Federation. The dev app at `https://app.development.forestadmin.com` proxies to the local server running the current branch.

## Step 1 — Start the app

The repo pins Node 22 (engine check rejects 24). Prefix every yarn/nx call:
`export PATH="$HOME/.nvm/versions/node/v22.12.0/bin:$PATH"`

From `~/work/forestadmin-poc`, run `yarn start:all` in the background (Ember :4200 + MFEs :4001/:4002 + workspace packages, orchestrated by nx). It is slow: workspace deps build first, then Ember compiles.

**Completion criterion:** the background log shows `Build successful` AND both `4001` and `4002` are serving. Poll with a Monitor until then — do not open the browser before both are up, or you QA a half-built app. If a build error appears instead, stop and surface it.

## Step 2 — Open Chrome on the dev app

Load the Claude in Chrome tools in one ToolSearch call (`tabs_context_mcp,navigate,computer,read_page,tabs_create_mcp,read_console_messages,gif_creator,browser_batch`).

`tabs_context_mcp` (new tab) → `navigate` to `https://app.development.forestadmin.com` → screenshot.

**Completion criterion:** the projects list renders with the user's name top-right. The session is already authenticated — no login step. If a login screen appears instead, stop and tell the user (do not enter credentials; that is a prohibited action).

## Step 3 — Record the session

`gif_creator start_recording` before the first interaction. Take a screenshot right after starting so the first frame captures the initial state.

## Step 4 — Walk the flows

Read `references/flows.md` and walk every flow for each MFE the change touches (both if unsure). At each state: screenshot, then `read_console_messages` with `onlyErrors:true` and a pattern covering `error|Objects are not valid|Cannot|failed`. Batch predictable click→screenshot sequences with `browser_batch`.

**Never trigger a real side effect** — do not click "Enable 2FA", delete a token, submit a form that mutates the account. QA the render and navigation up to the mutation, not the mutation itself.

**Completion criterion:** every flow in `flows.md` for the in-scope MFE(s) reached its expected rendered state, and every state returned zero console errors. A flow that renders but logs an error is a failure — record it. Silence is not success: if you skipped a flow, say which and why.

## Step 5 — Deliver

`gif_creator stop_recording` (screenshot first for the last frame) → `export` with `download:true` and a named file (e.g. `mfe-qa-session.gif`). Send it with `SendUserFile`. Report per flow: rendered ✓/✗, console clean ✓/✗, and any state you could not reach. Stop the `start:all` background task unless the user wants the app left running.
