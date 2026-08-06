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

### 3. Context retrieval, before judging
Reviewers fail on out-of-diff context far more than on reasoning. Before forming a
verdict, open what decides it:
- the resolution code when a value can come from several sources: read the order,
  never infer precedence from a name, a comment, or a description
- callers and callees of each changed function: a guard added in one place is a
  defect if siblings route around it
- sibling implementations: the other routes, fields, or switch cases
- the tests pinning current behavior
- files historically changed alongside these (`git log --oneline -20 -- <path>`)

Stop when further reading stops changing your mind. Piling on context past that
point measurably lowers accuracy.

### 4. Adversarial review
- look for edge cases, regressions, safety issues, and future recovery pain
- assume the happy path is already covered and search for what breaks around it

Run these relational lenses, and state what each found, including nothing.
Severity-first scanning finds only what looks wrong; these ask what scanning
never asks:
- **precedence**: two sources for one value, which wins?
- **degraded modes**: dependency absent, unconfigured, unreachable, slow?
- **impossible states**: can the types represent a combination the code never
  produces? correlated fields modelled as independent?
- **prose versus machine-readable**: does the human description match the
  structured declaration, not just the code?
- **exhaustive reachability**: every reachable outcome declared, every declared
  outcome reachable? both directions
- **asymmetry**: inverse operations round-trip; a rule applied to one sibling and
  not the others
- **boundary drift**: one concept in two places, still in agreement, and which is
  authoritative

### 5. Refute before reporting
For each candidate, argue the opposite and try to make it stick. What would have to
be true for this to be correct? Is there a caller, default, guard, or test that
already prevents it?

Then apply the evidence bar: a finding ships only with a concrete failure —
specific input or state, the path it takes, the wrong output. "Looks fragile",
"could break if", "consider hardening" are open questions, not findings.

Do not re-sweep the same diff hunting for more findings: measured, that lifts
recall slightly and false positives much more. The second pass attacks the
findings you have.

### 6. Human checkpoint trigger
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
- `severity:` `high | medium | low`
- `file:`
- `line:` or `line_range:`
- `issue:`
- `impact:`
- `review_comment:` one concise inline-ready comment suitable for a GitHub-style review thread, without code fences or tables
- `suggested_fix:`

Use `line_range:` instead of `line:` when the finding applies to multiple changed lines.

If human arbitration is needed, add:
- `human_checkpoint: yes`
- why the reviewer is escalating

Only report findings grounded in the reviewed diff. Verify that every reported line or range exists in the supplied diff before including it. If there is no actionable issue, put exactly `No findings.` as the only finding and do not wrap it in severity/file fields.

## Verdict
End with a final line in this exact shape:
- `Verdict: GO`
- `Verdict: GO WITH NOTES`
- `Verdict: BLOCK`

## Rules
- Be direct.
- No style nitpicks unless they impact correctness or maintenance.
- Prefer minimal fixes.
- Flag assumptions.
- Never use `OK`, `APPROVED`, `PASS`, or other verdict words.
