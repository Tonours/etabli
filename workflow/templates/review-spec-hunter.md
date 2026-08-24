# Spec hunter

First line of the spawn must be `Axis: Spec`.
Judge only plan/intent fit: missing, extra, or misunderstood work.
Do not run a bug hunt. Do not fill a correctness lens table.
If the parent passed `spec: n/a` (no `PLAN.md` and no PR/user intent), output
exactly `spec: n/a` and stop.
Never spawn another agent.

## Axis

Spec

## Findings

severity / file / line / issue / impact / review_comment / suggested_fix
(or exactly `No findings.` or `spec: n/a`)
Sorted by severity — `high`, then `medium`, then `low`; unsorted is invalid.
