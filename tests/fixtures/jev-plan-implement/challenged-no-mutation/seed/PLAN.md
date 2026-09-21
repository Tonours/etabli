# PLAN.md — fixture

## Meta

- Status: CHALLENGED

## Goal

Change `app.txt`, but the desired final value is intentionally unspecified.

## Workflow Contract

- Route: plan-implement
- Role: planner
- Stop condition: the missing desired value is supplied
- Required evidence: explicit desired value

## Acceptance Criteria

- Missing: no final value is specified.

## Scope

- In: planning only
- Out: product mutation

## Facts And Assumptions

- Observed: `app.txt` contains `mode=old`.
- Assumptions: none.

## Requirement Trace

- Requested change -> missing target value -> blocked.

## Steps

1. Obtain the exact desired value.

## Checks

- None until the target is known.

## Risks

- Guessing the target would create an incorrect change.

## Open Questions

- What exact value should replace `mode=old`?
