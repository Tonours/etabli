# Review Rubric

Run a production-minded review. Parent hunts via isolated hunters, then filters.

## Intent

The parent writes one Intent paragraph (user message, PR body, or commits)
after pinning the patch once; hunters receive it. Logic does not treat
Intent or `PLAN.md` as correctness authority.

## Hunt and filter

1. **Pin once** — parent captures the patch bytes (resolved SHA / merge-base, or
   a captured uncommitted diff). Hunters do not re-run `git diff` or `gh pr diff`.
2. **Logic hunter** — fresh context; hunt correctness; lens + deciding-code
   tables; extra-lens bugs allowed. Run Spec in parallel when the runtime can
   (Claude/Cursor). Daily Pi: isolated Logic child only.
3. **Spec hunter** — fresh context; plan/intent fit only; no bug hunt. `spec: n/a`
   when there is no intent artifact. Daily Pi: Spec runs in the parent after
   Logic (`spec: parent`).
4. **Standards hunter** — `code-quality` (or sibling fallback) when the diff has
   language/UI surface, else `quality: none`.
5. **Lead** — Act on / Consider / Dismissed. Lead does not re-hunt.
   Empty dismissals are `Dismissed: none`.

## Review stack

### 1. Self-check
- sanity-check the pinned diff
- verify focused validation actually ran
- flag incomplete or partial states

### 2. Plan compliance (Spec hunter)
- compare the pinned diff against `PLAN.md` or PR/user intent when present
- check scope, non-goals, invariants, done criteria, changed-file alignment, complexity drift

### 3. Context retrieval, before judging (Logic hunter)
Reviewers fail on out-of-diff context most. Before a verdict, open what decides it:
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
- documented field → cross **prose + declaration + runtime producer**
- value captured then reused across an `await` or async boundary (snapshot,
  cache, closure) → open **what can write or mutate it between capture and
  reuse** (event handlers, store setters, sibling writers)

Stop when further reading stops changing your mind — piling on past that
point measurably lowers accuracy.

### 4. Adversarial review (Logic hunter)
- assume the happy path is covered; search around it: edge cases, regressions, safety issues, recovery pain

Run these relational lenses, state what each found, including nothing.
Severity-first scanning finds only what looks wrong; these ask what scanning
never asks:
- **precedence**: two sources for one value, which wins?
- **degraded modes**: dependency absent, unconfigured, unreachable, slow?
- **impossible states**: can the types represent a combination the code never
  produces? correlated fields modelled as independent?
- **prose versus machine-readable**: does the human description match the
  structured declaration, not just the code? A runtime producer is not a
  declaration
- **exhaustive reachability**: every reachable outcome declared, every declared
  outcome reachable? both directions
- **asymmetry**: inverse operations round-trip; a rule applied to one sibling and
  not the others
- **boundary drift**: one concept in two places, still in agreement, and which is
  authoritative

### 5. Convention & pattern fit
When the parent set `Standards: yes`, the Logic hunter records Convention as
`deferred: Standards hunter`, issuing no second convention verdict.
The Standards hunter loads `code-quality` when exposed, else the narrowest
domain or project skill. If none is exposed, compare against **1–3 sibling
implementations in this repo**. If neither a skill nor a relevant sibling exists,
record this lens as `not run` (never a clean pass). When `Standards: none`, Logic
keeps that sibling/`not run` rule.

Evidence bar for a convention finding:
- changed `file:line` in the target diff
- sibling pattern `file:line` (or named skill rule when no sibling exists)
- impact on correctness or operability — the concrete failure (input or state → wrong output) — not preference or maintenance taste

### 6. Refute before reporting
For each candidate, argue the opposite and try to make it stick. What would have to
be true for this to be correct? Is there a caller, default, guard, or test that
already prevents it?

Then apply the evidence bar: a finding ships only with a concrete failure —
specific input or state, the path it takes, the wrong output. "Looks fragile" or
"consider hardening" are open questions, not findings.

Lead filters after the hunt; it does not re-hunt the diff.

### 7. Human checkpoint trigger
- explicitly say when a human should arbitrate
- use this for accepted risk, ambiguous tradeoffs, replan decisions, broad impact

## Mandatory output tables

### Lens table
Every row mandatory on the Logic hunter. A lens without a concrete opened
`file:line` is `not run`, never a pass (Convention may be `deferred: Standards hunter`). On `Verdict: GO` or `Verdict: GO WITH NOTES`, every lens row carries `file:line`, `absent` (Prose row only, no behavior named in prose), or `deferred: Standards hunter` (Convention row only, `Standards: yes`). A `not run` row blocks `Verdict: GO` and `Verdict: GO WITH NOTES` alike: a notes verdict is not a workaround for a skipped lens. Any other cell is a `not run` skip, and a skip is not a result (Convention §5 excepted: its no-skill, no-sibling `not run` is a recorded gap, never a pass).
The Prose row lists **each behavior named in prose**: its declaration —
parameter, schema entry, config key — `file:line`, or `no declaration →
finding`; `absent` only when prose names none.

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
The whole-diff `n/a` is an artifact-backed claim: the row lists every changed path, and each must be a document or pure rename; any other changed path makes the rows mandatory and the bare `n/a` an invalid skip.
A row whose behavior captures a value for reuse across a boundary names the
writers that can change it in the window.

| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |
| --- | --- | --- | --- |

A non-trivial runtime row with empty deciding code or `not run` **blocks
`Verdict: GO`**. `GO WITH NOTES` is not a workaround for unopened deciding code.

## Inputs
- parent-pinned patch text
- `git status --short` / `git diff --stat` for target resolution only
- Intent paragraph from the parent
- `PLAN.md` or PR/user intent for the Spec hunter only

## Evidence rules
- Use bounded read-only inspection of nearby code, tests, config, or docs only when it materially confirms or rejects a suspected finding.
- Do not edit files, install dependencies, or run broad/slow validation unless explicitly asked.
- Treat missing validation as a finding only when you can name the unvalidated
  input, the reachable entry point that passes it, and the wrong output it
  produces downstream; otherwise it is an open question, not a finding.

## Look for
- correctness bugs
- regressions / behavior changes
- security or safety issues
- missing validation or weak verification
- maintainability issues that affect correctness or operability
- convention or pattern drift against sibling implementations (with local anchor)
- plan drift or review-time discovery that the work no longer matches the approved contract
- unrequested abstraction, new dependency, reinvented stdlib, or
  comments/`any`/try-catch papering over the change

## Findings format
For each issue include:
- `severity:` `high | medium | low`
- `file:`
- `line:` or `line_range:`
- `issue:`
- `impact:`
- `review_comment:` one concise inline-ready comment suitable for a GitHub-style thread, without code fences or tables
- `suggested_fix:`

Use `line_range:` for multi-line findings.

Emit findings sorted by severity — `high`, then `medium`, then `low`; any other order is invalid.

If human arbitration is needed, add:
- `human_checkpoint: yes`
- why the reviewer is escalating

Only report findings grounded in the reviewed diff. Verify that every reported line or range exists in the supplied diff before including it. If no issue names its concrete failure (input or state → wrong output), put exactly `No findings.` as the only finding — style, whitespace, and behavior-preserving renames never qualify, at any severity — and do not wrap it in severity/file fields.

## Verdict
End with a final line in this exact shape:
- `Verdict: GO`
- `Verdict: GO WITH NOTES`
- `Verdict: BLOCK`

**GO** and **GO WITH NOTES** require: every runtime deciding-code row filled with a real `file:line` (or a whole-diff `n/a` whose listed paths are all documents or pure renames), and no lens row left `not run` or unsanctioned.
Notes on `GO WITH NOTES` state remaining risk or test gaps only — never a style, naming, or formatting change request.

## Rules
- Be direct.
- No style nitpicks: naming, formatting, or whitespace without the concrete failure is not a finding at any severity.
- Prefer minimal fixes.
- Flag assumptions.
- Never use `OK`, `APPROVED`, `PASS`, or other verdict words.
