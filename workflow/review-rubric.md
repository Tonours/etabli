# Review Rubric

Run a production-minded review.

## Two passes

When both correctness and plan fit matter (implementation-loop, ship):

1. **Break-first** — do **not** open `PLAN.md`. Hunt what breaks, lies, or fails
   to round-trip. Fill the lens table and deciding-code table.
2. **Plan-fit** — only after pass 1. Compare diff + pass-1 findings to `PLAN.md`
   (scope, checks, drift). Do not re-hunt bugs freely.

A solo `/review` request may combine both when the user did not ask for
plan-fit; still fill deciding-code for runtime behaviors.

## Review stack

### 1. Self-check
- sanity-check the diff
- verify focused validation actually ran
- flag obviously incomplete or partial states

### 2. Plan compliance review (Plan-fit pass only)
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

**Retrieval heuristic (runtime behaviors):**
- multi-source value → open the **resolver**
- status / error path → open **mapper + middleware / guard**
- documented field → cross **prose + schema + runtime producer**

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

### 5. Convention & pattern fit
Load `code-quality` when exposed, otherwise the narrowest exposed domain or
project skill. If none is exposed, perform the same comparison directly against
**1–3 sibling implementations in this repo**, not against abstract industry
taste. If neither a skill nor a relevant sibling exists, record this lens as
`not run`; unavailable optional skills never count as a clean pass.

Evidence bar for a convention finding:
- changed `file:line` in the target diff
- sibling pattern `file:line` (or named skill rule when no sibling exists)
- impact on correctness, operability, or maintenance — not preference

### 6. Refute before reporting
For each candidate, argue the opposite and try to make it stick. What would have to
be true for this to be correct? Is there a caller, default, guard, or test that
already prevents it?

Then apply the evidence bar: a finding ships only with a concrete failure —
specific input or state, the path it takes, the wrong output. "Looks fragile",
"could break if", "consider hardening" are open questions, not findings.

Do not re-sweep the same diff hunting for more findings: measured, that lifts
recall slightly and false positives much more. The second pass attacks the
findings you have.

### 7. Human checkpoint trigger
- explicitly say when a human should arbitrate
- use this for accepted risk, ambiguous tradeoffs, rollback/replan decisions, or broad-impact changes

## Mandatory output tables

### Lens table
Every row mandatory. A lens without a concrete opened `file:line` is `not run`,
never a pass.

| Lens | Checked (file:line) | Found |
| --- | --- | --- |
| Precedence | | |
| Degraded modes | | |
| Impossible states | | |
| Prose vs machine-readable | | |
| Exhaustive reachability | | |
| Asymmetry | | |
| Boundary drift | | |
| Convention & pattern fit | | |

### Deciding-code table
One row per **runtime behavior** touched by the diff (API, auth, mapping,
config, precedence, error path). Docs-only or pure rename rows may be omitted
with an explicit `n/a — no runtime behavior`.

| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |
| --- | --- | --- | --- |

A non-trivial runtime row with empty deciding code or `not run` **blocks
`Verdict: GO`**. `GO WITH NOTES` is not a workaround for unopened deciding code.

## Inputs
- `git status --short`
- `git diff --stat`
- full diff for the target scope
- `PLAN.md` when present (Plan-fit pass only for compliance)

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
- convention or pattern drift against sibling implementations (with local anchor)
- plan drift or review-time discovery that the work no longer matches the approved contract
- unrequested abstraction, new dependency, reinvented stdlib/native feature, or
  comments/`any`/try-catch added only to paper over the change (implementation-loop 12b)

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

**GO** requires: every runtime deciding-code row filled with a real `file:line`
(or explicit `n/a — no runtime behavior` for the whole diff).

## Rules
- Be direct.
- No style nitpicks unless they impact correctness or maintenance.
- Prefer minimal fixes.
- Flag assumptions.
- Never use `OK`, `APPROVED`, `PASS`, or other verdict words.
