---
name: plan-review
description: Critique an implementation plan before execution and challenge assumptions
---

# Plan Review

Use this before implementation to stress-test a plan.

1. Read `PLAN.md` (or provided plan content).
2. Validate first: is the goal clear, measurable, and within scope?
3. Challenge assumptions:
   - What is assumed about inputs, environment, data shape, concurrency, and failure modes?
   - Which assumptions are risky/unproven?
4. Identify missing risks and edge cases:
   - rollback points
   - irreversible actions
   - permissions/security boundaries
   - backward compatibility and migration concerns
5. Verify execution order:
   - does each step depend on required state?
   - can risky steps be moved later/split?
6. Suggest a stricter plan:
   - simplify scope if needed
   - split into smaller verify-able slices
   - add explicit checks before each risky step
7. Return output:
   - `BLOCK` if critical issues
   - `GO WITH CHANGES` with required fixes
   - `GO` if clean

Keep it short and decisive. Prefer 5–10 concrete improvements, ordered by impact.
