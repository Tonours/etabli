# Implemented: attention-first durable PWA on React, Tailwind and shadcn/ui, grouped TUI

## Metadata
- Archived: 2026-11-17
- Source plan: `PLAN.md` — attention-first rework of the durable PWA (`durable/web`, rebuilt on React, Tailwind and shadcn/ui) and TUI (`durable/tui`)
- Source plan SHA-256: `21f281a0fccd5e71affde39b1c2f80e087b2a7a58013140c291eb375b80bcd03`
- Status: IMPLEMENTED
- Commit / branch: feat/durable-attention-ui, e8339782..adff0412 on 8fcccee4
- Workflow initiative: durable-attention-ui

## Outcome
- Both clients group runs as "Needs you" (blocked, 72 h window), "In progress",
  "Finished", with a count summary, a plain status label, a next-step hint and
  the pull-request link (`https://` only). Shared logic: `durable/shared/runs-view.ts`.
- PWA rebuilt in `durable/web-src` (React 19, Vite, Tailwind 4, shadcn/ui);
  run view with Overview, Activity, Plan and Instructions panels; Activity
  follows the newest entry with a Jump control; steer acknowledgment in view;
  ended runs show no Live or controls; focus kept across the 5 s refresh;
  phone layout replaces the list; dark scheme; selection in the URL hash.
- The build runs at deploy (`bun run build`) into git-ignored
  `durable/web/app.js` and `style.css`; shell, worker, manifest and CSP unchanged.
- TUI: grouped, column-aligned list with glyphs, ages from start, tool
  argument summary, queued instructions, state-aware hints, ended-run wording.
- Daemon (`durable/src`, scripts, systemd units) untouched (AC-10).

## Context
- `durable/src` CSP is `style-src 'self'`: no inline styles, so Tailwind
  output is a file and tone rules sit outside `@layer` to beat variant utilities.
- Radix Tabs activate on mousedown; happy-dom textarea events do not reach
  React, so component tests drive the store and the browser flow covers typing.
- Mutation runner is darwin-only; bounded one-line breaks replace it.

## Decisions
### Real shadcn/ui with a deploy-time build
- Context: the owner kept mockup v4 and asked for real shadcn/ui.
- Choice: React + Tailwind + shadcn components, built at deploy.
- Rejected options: hand-written CSS imitation; committed bundle.
- Rationale: owner decision 2026-11-16 and 2026-11-17.
- Consequences: `git pull` and `bun run build` are two steps; between them
  `/app.js` answers 400 (documented in `durable/web/README.md`).
### Reply guards
- Context: late replies could show stale content after a selection or session change.
- Choice: session generation, selection visit counter, socket identity, and
  request sequence numbers for run lists, plans and schedules; `StaleReply` dropped silently.
- Consequences: transition rows (a)-(h) pinned in `__tests__/web-store.test.ts`.

## Accepted Drift
- Original plan/spec: one commit per step.
- Implemented reality: steps 1-5 landed in one commit (e8339782).
- Why accepted: the step-1 suite state was never committed separately; the evidence per step stays in the checks.
- Original plan/spec: v6 mockups (`MOCKUPS/final/v6/`) and their delta.
- Implemented reality: not folded; built on v4/v5.
- Why accepted: v6 awaits the owner's acceptance and its own adversary pass.

## Validation Evidence
- command: `cd durable && bun run typecheck && bun run test`
  - result: adff0412 → exit 0; 354 pass, 0 fail (baseline 284)
- command: `cd durable && bun run build && git status --short --ignored web`
  - result: only `!! web/app.js`, `!! web/style.css`
- command: product flow on `durable/__tests__/fixtures/browser-daemon.ts` (headless Chromium, disposable profile, synthetic token)
  - result: AC-1, AC-3 to AC-9, AC-13, AC-14 green (0 CSP, 0 console errors,
    0 off-origin; contrast min 4.82 light / 5.86 dark; no overflow at 390,
    320, 200 %); parity flow (AC-15) green; TUI captures of grouped list,
    blocked and published runs
- command: rollback rehearsal at 8fcccee4 (update, build, revert)
  - result: passed; `git diff --quiet 8fcccee4 -- durable/web` after revert
- command: bounded mutation breaks
  - result: 53 breaks, 50 red; three equivalent mutants recorded; review fixes added red-then-green tests
- command: reviews
  - result: Logic and Threat GO WITH NOTES, Spec findings closed by flow
    proofs; cross-family adversary 4 medium fixed (2d3672d7); re-check 2 low fixed (adff0412)
- command: `scripts/verify-agentic-infra durable`, `core`
  - result: green on the final head (see PR)

## Follow-up State
- Remaining risks: `bun audit` shell-quote 1.8.3 (existing runtime dependency);
  non-atomic app.js/style.css pair during a build (documented); no darwin
  mutation runner; password-manager autocomplete on the token field; any
  `https://` URL accepted as PR link (daemon-set value); session stays
  "checking" after a failed login that raced the startup check (Login stays usable).
- Parking lot: v6 mockups delta; dismiss action; PR and CI state in the list;
  resubmit from a client; compressed assets. AC-12 (judgment) left to the owner on the captures.
- Superseded docs/specs: hand-written `durable/web/app.js` and `style.css`.
- Next links: `durable/web/README.md` § Build, update and rollback.
