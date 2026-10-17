# Implemented: route classifier, orphan telemetry, stale live tests, retired routines and adapter-sync stamp removed

## Metadata
- Archived: 2026-10-17
- Source plan: `PLAN.md` — Remove the unread route classifier, orphan telemetry, stale live tests, retired routines and the adapter-sync stamp
- Source plan SHA-256: `d2c865428ed124fa9476acbeb1589fc2d8938ac3f71861b24db6264fd26bb59a`
- Status: IMPLEMENTED
- Commit / branch: `main`, from `b6bc64fd`
- Workflow initiative: none

## Outcome
- Route classifier removed (ADR-0036 supersedes ADR-0014): `workflow-router-core.mjs`, obvault topic resolver, Pi `workflow-router` extension and libs, Claude `workflow-router-lib.mjs`, router tests, `tests/router-evals`, agent scenarios, action-graph and autonomous plan-loop smokes, obvault query smoke and fixture. The model routes from the `workflow/spec.md` table.
- Read-only Bash policy kept byte-identical in `workflow/runtime/read-only-bash.mjs`; `read-only-agent-guard.mjs` imports it directly.
- Guard journal removed (write-only since `workflow-ship-metrics` went); no-comments guard and both adapters lost the journal call and the `harness` field.
- `live` profile of `verify-agentic-infra` removed with `workflow-real-agent-scenarios.sh` (asserted the deleted UserPromptSubmit route hook) and `workflow-cli-smoke.sh`.
- `workflow/runtime-capabilities.json` and its smoke removed; orchestration keeps the Pi/Claude notes as prose.
- `workflow-adapter-sync`, `adapter-manifest.json` and its smoke removed; 23 adapter GENERATED blocks dropped (3 keep the pointer line); `skills-lock.json` regenerated.
- Work routines and sessions-report removed (plists gone on macbook-work, last runs 2026-10-09/12).
- Dead symbols: `isNarrowPlanCleanupCommand`, `readDefaultModelSpec`, `readAgentSettings`, 8 shell functions; `tests/adr-skill-stress.sh` (manual, paid, not in CI).
- `deploy-agent-workflow` now prunes stale managed `~/.claude/scripts` links, like hooks.

## Context
- `pi/extensions/workflow-router.ts`: only called `appendEntry("etabli.workflow-router")`; no reader in etabli, dotfiles or `~/.pi/agent/extensions`.
- ADR-0032 had already removed the guards the classifier fed.
- Removed bun suites held 285 of 346 tests (mostly fixture-driven router cases).

## Decisions
### Remove the classifier instead of keeping it as executable documentation
- Context: no runtime consumer; ~3000 lines of code, fixtures and tests to maintain.
- Choice: delete; keep the ROUTES table in `workflow/spec.md` as the model-facing source.
- Rejected options: keep the library for tests only.
- Rationale: the tests only checked the library against itself.
- Consequences: route accuracy is no longer machine-checked; ADR-0027's route set stays valid.

### Drop GENERATED adapter headers
- Context: the block copied frontmatter name/description into each adapter body and required hash updates on every edit.
- Choice: remove; keep the pointer line only where the body does not cite its contract.
- Rejected options: keep a pointer-only stamp with the sync script.
- Rationale: bodies already cite their contract.
- Consequences: no tripwire on adapter body drift.

## Accepted Drift
- Original plan/spec: AC-6 superseded ADR-0014 and ADR-0027.
- Implemented reality: only ADR-0014 superseded.
- Why accepted: ADR-0027's route set and work-command split remain true.

## Validation Evidence
- `scripts/verify-agentic-infra full`:
  - result: 37/37 PASS (baseline 45/45; removed rows had their targets deleted)
- `cd pi && bun test extensions/__tests__/ && bun run typecheck`:
  - result: 62 pass, 0 fail; exit 0
- `bash tests/deploy-agent-workflow-smoke.sh` with the pre-fix deploy script:
  - result: red (stale script link kept); green after the fix
- AC grep for removed names outside `docs/adr`, `docs/plan`:
  - result: empty
- Deployed guard probe through `~/.claude/hooks`:
  - result: `rm -rf` denied, `git status` allowed
- Review: Logic GO WITH NOTES (no findings), Spec GO WITH NOTES (4 low, folded), adversary 2 low (1 fixed, 1 refuted)

## Follow-up State
- Remaining risks: macbook-work keeps dangling links until `git pull && scripts/deploy-agent-workflow --apply`.
- Parking lot: gitignored `.workflow/guard-journal/` directories remain in local projects (inert).
- Superseded docs/specs: ADR-0014.
- Next links: `docs/adr/0036-drop-the-route-classifier-and-its-orphan-telemetry.md`, `workflow/spec.md`.
