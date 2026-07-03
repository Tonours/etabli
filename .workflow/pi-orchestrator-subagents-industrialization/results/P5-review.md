# P5 final review

## Verdict

Initial recommendation: `FAIL`.

Integrated recommendation after fix: `PASS`.

## Finding

Generic cleanup wording could satisfy `hasPlanCleanupTask`, so a completed task like `Cleanup imports` could falsely count as root `PLAN.md` cleanup evidence.

## Fix

- Tightened the cleanup evidence matcher to require cleanup/removal wording plus explicit `PLAN.md` wording.
- Added a negative test proving `Cleanup imports` does not satisfy implementation completion evidence.

## Validation

- `bun test pi/extensions/__tests__/tasks-till-done-runtime.test.ts pi/extensions/__tests__/tasks-till-done-extension.test.ts` -> 21 pass, 0 fail.
- `git diff --check` -> clean.
