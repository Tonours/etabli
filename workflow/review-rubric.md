# Review Rubric

Run a production-minded review. Parent hunts via isolated hunters, then filters.

## Intent

The parent writes one paragraph of Intent (user message, PR body, or commits)
after pinning the patch once. Hunters receive that pinned text and Intent.
Logic does not treat Intent or `PLAN.md` as correctness authority.

## Hunt and filter

1. **Pin once** — parent captures the patch bytes (resolved SHA / merge-base, or
   a captured uncommitted diff). Hunters do not re-run `git diff` or `gh pr diff`.
2. **Logic hunter** — fresh context; hunt correctness; lens + deciding-code
   tables; extra-lens bugs allowed. Run Spec in parallel when the runtime can
   (Claude/Cursor). Daily Pi: isolated Logic child only.
3. **Spec hunter** — fresh context; plan/intent fit only; no bug hunt. `spec: n/a`
   when there is no intent artifact. Daily Pi: Spec runs in the parent after
   Logic (`spec: parent`), not as a second child.
4. **Standards hunter** — `code-quality` (or sibling fallback) when the diff has
   language/UI surface, else `quality: none`.
5. **Lead** — Act on / Consider / Dismissed. Lead does not re-hunt.
   Empty dismissals are `Dismissed: none`.

## Review stack

### 1. Self-check
- sanity-check the pinned diff
- verify focused validation actually ran
- flag obviously incomplete or partial states

### 2. Plan compliance (Spec hunter)
- compare the pinned diff against `PLAN.md` or PR/user intent when present
- check scope, non-goals, invariants, done criteria, and changed-file alignment
- flag complexity drift or unplanned surface area

### 3. Context retrieval, before judging (Logic hunter)
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
- value captured then reused across an `await` or async boundary (snapshot,
  cache, closure) → open **what can write or mutate it between capture and
  reuse** (event handlers, store setters, sibling writers)

Stop when further reading stops changing your mind. Piling on context past that
point measurably lowers accuracy.

### 4. Adversarial review (Logic hunter)
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
  structured declaration, not just the code? each behavior named in prose must
  cite the machine-readable declaration that carries it — parameter, schema
  entry, config key — `file:line`; a named behavior with no declaration is a
  finding
- **exhaustive reachability**: every reachable outcome declared, every declared
  outcome reachable? both directions
- **asymmetry**: inverse operations round-trip; a rule applied to one sibling and
  not the others
- **boundary drift**: one concept in two places, still in agreement, and which is
  authoritative

### 5. Convention & pattern fit
When the parent set `Standards: yes`, the Logic hunter records Convention as
`deferred: Standards hunter` and does not issue a second convention verdict.
The Standards hunter loads `code-quality` when exposed, otherwise the narrowest
exposed domain or project skill. If none is exposed, compare against **1–3 sibling
implementations in this repo**. If neither a skill nor a relevant sibling exists,
record this lens as `not run`; unavailable optional skills never count as a
clean pass. When `Standards: none`, Logic keeps that sibling/`not run` rule.

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

Lead filters after the hunt; it does not re-hunt the diff.

### 7. Human checkpoint trigger
- explicitly say when a human should arbitrate
- use this for accepted risk, ambiguous tradeoffs, rollback/replan decisions, or broad-impact changes

## Mandatory output tables

### Lens table
Every row mandatory on the Logic hunter. A lens without a concrete opened
`file:line` is `not run`, never a pass (Convention may be `deferred: Standards hunter`).
The Prose vs machine-readable row cites one declaration `file:line` for **each
behavior named in prose**, or `absent` when none exists.

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
A row whose behavior captures a value for reuse across a boundary names the
writers that can change it in the window.

| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |
| --- | --- | --- | --- |

A non-trivial runtime row with empty deciding code or `not run` **blocks
`Verdict: GO`**. `GO WITH NOTES` is not a workaround for unopened deciding code.

## Inputs
- parent-pinned patch text (not a second `git diff` / `gh pr diff`)
- `git status --short` / `git diff --stat` for target resolution only
- Intent paragraph from the parent
- `PLAN.md` or PR/user intent for the Spec hunter only

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
