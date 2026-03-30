# Workflow Statuses

These are the canonical pre-implementation statuses for `PLAN.md`.

## `DRAFT`

Meaning:
- Initial plan exists.
- Scope, execution slices, or assumptions are not hardened yet.

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
- Measurement contract missing or too vague
- Slices/files/checks/rollback points too vague
- Key assumptions unvalidated
- Risky execution order
- Missing edge cases
- Blocking questions still open

## `READY`

Meaning:
- Scope is bounded.
- Measurement contract is explicit.
- Non-goals are explicit.
- Assumptions are explicit.
- Invariants are explicit.
- Done criteria are concrete.
- Slices are executable in order with clear file scope, checks, and rollback points.
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
- A plan without an explicit measurement contract cannot be `READY`.
- A plan without explicit slices, invariants, done criteria, and rollback points cannot be `READY`.
- A `READY` plan may be updated during implementation only to keep slice progress or to re-establish a valid plan after new facts emerge.
- `READY` is the only status that authorizes implementation.
