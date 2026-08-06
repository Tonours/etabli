---
name: playwright-failure-dossier
description: Analyze Playwright failures using traces, reports and dossier JSON before proposing a minimal fix or second opinion.
---

# Playwright Failure Dossier

Use this skill when a Playwright run is red or when a second opinion is needed before merging a test change.

## Evidence To Read

- `test-results/failure-dossiers/latest.json`
- `config/failure-dossier.schema.json`
- `playwright-report/`
- trace zip files under `test-results/`
- screenshots and videos under `test-results/`
- the failing spec and recent diff

## Classification

Classify the failure as one of:

- product bug;
- test bug;
- fixture/data bug;
- environment bug;
- flaky signal with evidence;
- unknown.

## Review Checks

- Is the locator user-facing and stable?
- Is the assertion strong enough to prove behavior?
- Did a visual snapshot change for a documented reason?
- Is a retry hiding a real defect?
- Is cleanup explicit?
- Is mocking too broad?
- Is the proposed patch the smallest defensible change?

## Output

Lead with findings. Include file/line references where available, failure class, observed evidence, assumptions, patch recommendation and validation command.

## JSON Contract

Treat `test-results/failure-dossiers/latest.json` as the canonical run dossier. Each failure must have `test`, `reproduction`, `artifacts`, `errors`, `classification` and `recommendedNextAction`. If an artifact has `availability: "missing"`, report the missing reason instead of guessing a path.
