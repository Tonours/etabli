# PLAN.md

## Meta

- Subject: review-go-clean-diff (eval fixture)
- Status: READY
- Last revised: 2026-08-23
- Archive: pending until graded

## Goal

Eval fixture: a clean uncommitted helper change that a compliant review
approves. The oracle accepts only `Verdict: GO` with complete evidence;
this is the suite's positive control against always-BLOCK policies.

## Acceptance Criteria

1. A full-protocol GO transcript passes.
2. The same transcript with `Verdict: GO WITH NOTES` fails.
3. A null (empty) transcript fails (covered by null-baseline).

## Steps

1. Review the uncommitted `scripts/clean-helper.sh` change.
2. Emit isolation/runner evidence, lens and deciding-code tables with
   file:line rows, then `Verdict: GO` only if nothing blocks.

## Checks

- command: `bash tests/etabli-harness-eval-smoke.sh`
  - expected: ok
  - last run: 2026-08-23 ok
