# Implemented: align installed runtime and require UI proof for explicit web recipes

## Metadata

- Archived: 2026-10-05
- Source plan: `PLAN.md` — Align the installed runtime and connect web recipes to UI proof
- Source plan SHA-256: `03aae4440c29cedb619442d4f172dba629633bc6ea2599e8ee5dce331eccb9ca`
- Status: IMPLEMENTED
- Owner branch / base: `feature/trust-ui` / `5d45f904e488d1073f52dec93924ebcda49ad8ce`
- Installed checkout branch / published HEAD: `fix/execution-quality` / `9aea2c4cc6dde6e88121c0e58fdc763d50258f03`
- Workflow initiative: `trust-ui-20261005`
- Review patch SHA-256: `c1010144291028ffcacd4a28b7cd4c363cf4bf8dafcefea3796111e1c64496fc`

## Outcome

The installed Pi/Claude workflow sources now use published Etabli, with the reviewed UI correction applied locally in the original checkout. The correction is uncommitted and unpublished. All 18 implementation files match the reviewed owner worktree byte for byte.

An explicit recipe `mode: ui` now requires a UI observation command, complete responsive/reduced-motion/reference scope, and reasons for excluded optional checks. The runner retains actual raw JSON and a native command receipt, derives UI evidence, and stops success on missing or false mandatory keyboard/focus/accessibility/console/network checks. Responsive scope requires two distinct observed sizes. The independent checker re-derives UI checks/viewports and binds mode, scope, assertions, argv, execution identity and raw hashes to the inventoried recipe.

The portable web recipe opts into UI mode. Its Chromium driver actually observes keyboard activation, visible focus, accessible roles/names, console/page errors, request failures/HTTP errors and two viewport geometries. Historical product recipes retain the product default.

Files: `scripts/lib/project-verification-ui.mjs`, recipe/runner/assertion helpers, `workflow/project-verification-recipe.schema.json`, `workflow/product-verification.md`, `scripts/deploy-workflow`, the web verification scaffold, focused regression tests and actual-browser controls. The full 18-path inventory is `.workflow/trust-ui-20261005/patch.json`.

## Context

- Installed sources resolve to `/Volumes/Crucial/work/etabli`; the original checkout was initially `caa55b3390f5b722568737c77f1d098710fcee4f` and safely fast-forwarded to the initially pinned published `5d45f904`.
- Eight pre-existing dirty files, including `pi/models.json` and seven plan/research notes, were preserved byte for byte. Installed `~/.pi/agent/models.json` was restored as its original regular file after the managed deployer relinked it. Both selected local preference baselines remain unchanged.
- The existing Pi package was present but its CLI launcher was missing. `/Users/tonours/.local/bin/pi` now links to the existing package, version `0.84.4`; no package was installed.
- The published visibility guard exposed one unfiltered local Radius string package source. Only its skills visibility was set to `[]`; its package/extensions remain available. The published DMI stamper repaired the existing addon flag. Live skill block: 7,050 characters against the unchanged 7,190-character ceiling.

## Decisions

### Explicit UI contract using the existing evidence protocol

- Context: a web recipe previously emitted product mode and did not reach the existing UI gate.
- Choice: explicit mode and scope; reuse raw JSON assertion/process receipts and the existing evidence-pack UI shape; derive it in one small shared module.
- Rejected options: guessing UI from argv, manually setting success metadata, broad runner refactoring or new dependencies.
- Rationale: preserve CLI compatibility and make incomplete/false UI observations block completion independently of command exit status.
- Consequences: legacy web recipes must explicitly adopt UI mode to receive these requirements. Responsive evidence is checked only when declared in scope.

### Preserve local customization while aligning managed runtime

- Choice: ancestry-checked fast-forwards, existing deployer, private preservation snapshots, patch apply-check and exact post-apply parity. Preserve custom models and default preferences.
- Consequences: the UI correction remains local and uncommitted; the installed symlinked helpers already execute it. No commit, push, PR or production deployment occurred.

## Accepted Drift

Published main advanced during final verification to `9aea2c4c` with an unrelated removal of unused `campaignUsage` from `scripts/lib/harness-token-usage.mjs`. The installed checkout fast-forwarded again. All 18 reviewed UI files stayed identical; no remaining campaignUsage callers were found. The affected usage/receipt neighbor suites passed 58/58, and both installed browser controls passed again at the newer published HEAD. The reviewed UI patch and plan contract did not change.

## Validation Evidence

Status: verified within the stated local fixture scope.

- Before/after: `red-e2e.log` rejected the old web pack (`product` instead of `ui`); `green-e2e/results.json` records the corrected actual-Chromium positive runner/checker/archive/completion exits of 0.
- command: `node --test tests/project-verification-{assertions,recipe,run,check}.test.mjs tests/plan-review-binding.test.mjs tests/review-evidence-pack.test.mjs tests/review-run-receipt.test.mjs`
  - result: 281/281 passed, zero failed/skipped/cancelled; `focused-final.log`.
- command: `ETABLI_TEST_PLAYWRIGHT_PACKAGE=/Volumes/Crucial/work/adonisjs-starter/apps/web/package.json bash tests/project-verification-e2e.sh .workflow/trust-ui-20261005/green-e2e`
  - result: 6/6 controls passed; CLI positive/negative, web positive/wrong product result/invisible focus/missing keyboard; cleanup 6/6. All negative controls refused checker/archive/completion despite observation command exit 0. `green-e2e.log` and `green-e2e/results.json`.
- command: `AGENTIC_INFRA_JOBS=1 scripts/verify-agentic-infra core`
  - result: 33/33 checks passed on the reviewed owner candidate; `core-final.log`. Earlier local CLI/skill-visibility failures were retained, classified and resolved without weakening gates.
- command: `bash tests/workflow-scaffold-smoke.sh`; `scripts/workflow-ref-linter`; `scripts/workflow-context-budget`; `git diff --check`
  - result: passed; shared module included in copied runtime and exclusions; all eight context surfaces within unchanged ceilings. `scaffold.log`, `refs.log`, `context.log`.
- command: `node --test tests/harness-token-usage.test.mjs tests/review-run-receipt.test.mjs` in the latest original checkout
  - result: 58/58 passed, zero failed/skipped, 313.08875 ms; `published-final.json`.
- command: actual installed `/Users/tonours/.pi/scripts/project-verification` and `project-verification-check`, driven by `installed-probe.mjs`
  - result: 2/2 real Chromium controls and cleanup passed at `9aea2c4c` plus the reviewed patch. Positive: runner/checker/archive/completed = 0. Invisible-focus negative: 1/1/2/1 while UI command exit = 0 and raw focus = false. `installed-e2e.json` and `installed-final.json`.
- command: published managed deployment, exact patch `git apply --check`, source parity, preservation checks and `scripts/claude-hooks-check`
  - result: installed source parity 5/5, shared UI module closure 4/4, implementation source parity 18/18, user files 8/8, local preference baselines 2/2, installed models byte-identical, all fragment hooks wired. `installed-baseline.json`, `integration.json`, `installed-final.json`.
- Native plan review: READY; actual xai/grok-4.7, terminal succeeded, measured/admissible true; `plan-review-capture-2/receipt.json`. The prior timed-out attempt was retained and not counted as approval.
- Independent code review: T1 clean → F1 clean. Fresh isolated Logic/Spec contexts; complete deciding-code coverage. Native cross-family code adversaries returned GO with no findings, actual xai/grok-4.7, measured/admissible true and exact patch hash; `T1-adversary/receipt.json`, `F1-adversary/receipt.json`. Final F1 lead GO WITH NOTES for pending installation/archive steps, subsequently checked by parent. Exact final hunter tables retained in `F1-lead.md`.
- simplify: clean. Quality: pass, existing sibling assertion/process/receipt/UI patterns; `quality.md`.

Evidence paths above are relative to `.workflow/trust-ui-20261005/` in the owner worktree unless explicitly stated.

## Follow-up State

- Remaining risks: browser accessibility evidence covers the fixture's roles/names, keyboard and visible focus; comprehensive WCAG compliance is not verified. Motion/reference checks are explicitly excluded with reasons. Evidence is cooperative local proof, not authenticated attestation; business benefit has not been measured.
- Archive lifecycle: this is the single immutable owner record. Root PLAN cleanup and autonomous-completed ledger validation execute after this write; their authoritative terminal results are retained in `events.jsonl` and `closure.json`.
- Publication state: local correction only; commit, push, PR and CI publication remain outside this request.
- Next links: `workflow/product-verification.md`, `workflow-scaffold/templates/verification/README.md`, `.workflow/trust-ui-20261005/F1-lead.md`.
