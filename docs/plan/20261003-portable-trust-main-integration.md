# Implemented: Portable project verification integrated with current main

## Metadata
- Archived: 2026-10-03
- Source plan: `PLAN.md` — Integrate portable project verification with current main for publication
- Source plan SHA-256: `b1f2e2a92327eba338fa406769da0f4b4d181e7c93ac0a9c9d4a1edf828b8c0c`
- Status: IMPLEMENTED
- Commit / branch: integrated source `67b4f683`, isolated detached worktree; publication commit and remote proof are recorded in the workflow ledger
- Workflow initiative: publication-integration-20261003

## Outcome
The portable verification workflow is integrated onto Etabli main `caa55b3390f5b722568737c77f1d098710fcee4f`, retaining its six execution-quality commits and the three unpublished portable-verification commits. Current reviewed plan binding and product receipt/source freshness are enforced together. All four deployed CLI/Chromium positive and negative scenarios have the expected results and owned-process cleanup.

## Context
- `scripts/workflow-event`, `scripts/plan-cleanup`, `scripts/deploy-workflow` and `workflow/skills/implementation-loop.md` retain both plan approval and product verification contracts.
- Four cherry-pick conflicts were resolved in `scripts/workflow-event`, `tests/agentic-infra-manifest-smoke.sh`, `workflow/runtime/source-ownership.tsv` and `workflow/skills/plan-loop.md`.
- All 50 original scope paths are retained: 39 remain byte-identical to the previously reviewed source; 11 incorporate incoming main contracts. The core manifest now counts 33 checks.
- Original implementation archive `docs/plan/20261003-portable-project-trust.md` remains byte-identical, SHA-256 `c14bb2eaa872c0c846699d8552c9b50ed735b4f9972deb45ba26e454f9503af0`.
- Satellite Starter fixes are already published at `f098be14aca92bd48efada1b206897f73de23760`. Its terminal CI failure is documented below.

## Decisions
### Preserve both contracts through a bounded integration
The remote advanced after the original review and rejected the push. Integrate the unpublished work onto current main, preserve incoming guards, and review the cumulative integration under this new approved plan. The original completed archive and review counters stay closed. No forced push, published history rewrite or global workflow deployment is part of this work.

### Keep the Starter audit truthful
Starter CI run [37106667140](https://github.com/Tonours/adonisjs-starter/actions/runs/37106667140) completed with failure in Checks. The [official braces advisory](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) lists affected versions through 3.0.3 and no patched release; registry observation found latest 3.0.3. An upstream security fork or advisory suppression is outside this publication scope. Test and Integration jobs were skipped after Checks failed; no passing Starter CI is claimed.

## Accepted Drift
The initial browser regression attempt required an explicit installed Playwright package selection. Selecting the existing Starter package through `ETABLI_TEST_PLAYWRIGHT_PACKAGE` made the same scenarios pass. The initial failure and environment retry remain in the ledger. No installed package or original checkout was modified.

## Validation Evidence
- `AGENTIC_INFRA_JOBS=4 scripts/verify-agentic-infra full`: verified 90/90 checks, exit 0; `.workflow/publication-integration-20261003/infra-full.log`.
- Focused Node tests for plan-review binding and portable verification: verified 174/174 tests, zero skipped, exit 0; `.workflow/publication-integration-20261003/focused.log`.
- `ETABLI_TEST_PLAYWRIGHT_PACKAGE=/Volumes/Crucial/work/adonisjs-starter/apps/web/package.json bash tests/project-verification-e2e.sh`: verified all four expected outcomes, actual Chromium in both web cases, process cleanup and runtime removal true; `.workflow/publication-integration-20261003/demos-configured/results.json`.
- `scripts/workflow-ref-linter` and `git diff --check`: pass.
- Private preservation checker: verified 45 Etabli and 16 Starter original file hashes and both current checkout statuses.
- Simplification: `simplify: clean`; quality pass used three actual local sibling implementations, documented in `.workflow/publication-integration-20261003/quality.md`.
- T1 full review: fresh isolated Logic and Spec hunters, complete deciding-code table, GO; native cross-family `xai/grok-4.7`, run `01a100cd-d17f-71af-897d-b6f48928247e`, GO with no findings. Actual input contained the full pinned patch. Evidence: `.workflow/publication-integration-20261003/lead-T1.md` and `adversary-T1.report.md`.

## Follow-up State
- Final F review includes this immutable archive. Final review closure, root-plan removal, publication SHA parity and terminal Etabli CI are recorded in `.workflow/publication-integration-20261003/events.jsonl`; this archive does not assert a future CI outcome.
- Remaining risk: Starter dependency audit is blocked by the external unpatched braces advisory. Its published fixes pass the 16 local wrapper regressions, while remote CI remains failed.
- Preservation evidence covers the original dirty checkouts. Incoming execution-quality work was published independently; this integration leaves the original untracked documents untouched.
