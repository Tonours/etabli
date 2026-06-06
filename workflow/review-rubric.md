# Review Rubric

Run a production-minded review.

## Review stack

### 1. Self-check
- sanity-check the diff
- verify focused validation actually ran
- flag obviously incomplete or partial states

### 2. Plan compliance review
- compare the target diff against `PLAN.md` when present
- check scope, non-goals, invariants, done criteria, and changed-file alignment
- flag complexity drift or unplanned surface area

### 3. Adversarial review
- look for edge cases, regressions, safety issues, and future recovery pain
- assume the happy path is already covered and search for what breaks around it

### 4. Human checkpoint trigger
- explicitly say when a human should arbitrate
- use this for accepted risk, ambiguous tradeoffs, rollback/replan decisions, or broad-impact changes

## Inputs
- `git status --short`
- `git diff --stat`
- full diff for the target scope
- `PLAN.md` when present

## Evidence rules
- Use bounded read-only inspection of nearby code, tests, config, or docs only when it materially confirms or rejects a suspected finding.
- Do not edit files, install dependencies, or run broad/slow validation unless the user explicitly asked for that level of review.
- Treat missing validation as a finding only when the risk or blast radius justifies it.

## Look for
- correctness bugs
- regressions / behavior changes
- security or safety issues
- missing validation or weak verification
- maintainability issues that affect correctness or operability
- plan drift or review-time discovery that the work no longer matches the approved contract

## Findings format
For each issue include:
- severity: `high | medium | low`
- file and line/block
- why it matters
- smallest concrete fix
- `review_comment:` one concise inline-ready comment suitable for a GitHub-style review thread

If human arbitration is needed, add:
- `human_checkpoint: yes`
- why the reviewer is escalating

Only report findings grounded in the reviewed diff. Verify that every reported line or range exists in the supplied diff before including it. If there is no actionable issue, put exactly `No findings.` as the only finding, then still include the final verdict.

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
