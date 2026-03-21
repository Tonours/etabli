# Workflow Statuses

These are the canonical pre-implementation statuses for `PLAN.md`.

## `DRAFT`

Meaning:
- Initial plan exists.
- Scope or assumptions are not hardened yet.

Allowed actions:
- Refine the plan.
- Review the plan.

Not allowed:
- Implementation.

Typical entry:
- `/skill:plan`
- `/plan`

## `CHALLENGED`

Meaning:
- Review found important issues.
- The plan is not executable without more thought or missing decisions.

Allowed actions:
- Resolve blockers.
- Update the plan.
- Re-run review.

Not allowed:
- Implementation.

Typical cause:
- Scope too wide
- Key assumptions unvalidated
- Risky execution order
- Missing edge cases
- Blocking questions still open

## `READY`

Meaning:
- Scope is bounded.
- Assumptions are explicit.
- Steps are executable in order.
- Main risks are documented.
- Blocking questions are resolved or consciously accepted.

Allowed actions:
- Implementation
- Review after implementation
- Implementation handoff

Typical entry:
- `/skill:plan-review`
- `/plan-review`
- `plan-loop` once critique lands cleanly

## State transitions

- `DRAFT -> CHALLENGED`
  - Review found important issues.
- `DRAFT -> READY`
  - Review found no major rethinking needed.
- `CHALLENGED -> READY`
  - Blockers were resolved and review now passes.
- `READY -> DRAFT` or `READY -> CHALLENGED`
  - Only if new facts invalidate the plan during implementation.

## Invariants

- `PLAN_TEMPLATE.md` defines shape, not readiness.
- Readiness is earned by review, not by plan creation.
- `READY` is the only status that authorizes implementation.
