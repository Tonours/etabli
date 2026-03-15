# Review Rubric

Run a production-minded review.

## Inputs
- `git status --short`
- `git diff --stat`
- full diff for the target scope

## Look for
- correctness bugs
- regressions / behavior changes
- security or safety issues
- missing validation or weak verification
- maintainability issues that affect correctness or operability

## Findings format
For each issue include:
- severity: `high | medium | low`
- file and line/block
- why it matters
- smallest concrete fix

## Verdict
End with exactly one verdict:
- `GO`
- `GO WITH NOTES`
- `BLOCK`

## Rules
- Be direct.
- No style nitpicks unless they impact correctness or maintenance.
- Prefer minimal fixes.
- Flag assumptions.
