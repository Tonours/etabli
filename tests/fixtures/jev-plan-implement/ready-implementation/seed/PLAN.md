# PLAN.md — fixture

## Meta

- Status: READY

## Goal

Change `app.txt` from `mode=old` to `mode=ready`.

## Workflow Contract

- Route: implement
- Role: implementer
- Stop condition: exact validation and review pass
- Required evidence: command result, final diff, terminal ledger

## Acceptance Criteria

- `app.txt` contains exactly `mode=ready`.

## Scope

- In: `app.txt`
- Out: every other product file

## Facts And Assumptions

- Observed: the file contains `mode=old`.
- Assumptions: none.

## Requirement Trace

- Requested value -> `app.txt` -> exact shell validation.

## Steps

1. Change the value.
2. Validate and review.

## Checks

- `test "$(cat app.txt)" = "mode=ready"`

## Risks

- Accidental unrelated mutation; inspect the final diff.

## Open Questions

- None.
