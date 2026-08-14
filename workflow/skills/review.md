# Review Contract

Shared contract for reviewing local changes, branch diffs, or commits.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the read-only default, finding format, plan-compliance check, or verdict
labels.

## Purpose

Review changes for correctness, regressions, risks, validation gaps, convention
or pattern drift, and plan drift. Use `workflow/review-rubric.md` as the source
of truth when available.

## Target Resolution

1. Inspect `git status --short` and `git diff --stat` first.
2. Determine the target:
   - no args: review uncommitted changes if present, else review current branch
     against the default branch;
   - `uncommitted`: review staged, unstaged, and relevant untracked changes;
   - `branch <base>`: diff current branch against merge-base with `<base>`;
   - `commit <sha>`: review `git show <sha>`.
3. Read the shared rubric from `workflow/review-rubric.md`, or the harness
   fallback rubric only outside a workflow-scaffolded project.
4. Read `PLAN.md` when present and use it for plan-compliance review.
5. When the diff touches language, framework, or UI surface, load the matching
   domain skill via `suite-router` / `code-quality` so convention findings are
   anchored in project patterns (see rubric § Convention & pattern fit).

## Review Scope

Review only the target scope. Cover:

- self-check;
- plan compliance;
- correctness;
- regressions;
- safety;
- validation;
- maintainability;
- convention and pattern fit against sibling implementations;
- plan drift;
- human checkpoint trigger when needed.

Use bounded read-only inspection of nearby code, tests, config, or docs only
when it materially confirms or rejects a suspected finding.

Do not edit files, install dependencies, or run broad/slow validation unless the
user explicitly asked for that level of review.

## Finding Format

Report concise actionable findings grounded in the reviewed diff:

```text
severity:
file:
line: or line_range:
issue:
impact:
review_comment:
suggested_fix:
```

Use `line_range:` instead of `line:` when the inline comment spans multiple
changed lines. Keep `review_comment:` as one inline-ready GitHub-style review
thread comment without code fences or tables.

If the diff conflicts with the plan, say so explicitly. Verify every reported
line or range exists in the supplied diff.

If there are no actionable issues, put exactly `No findings.` as the only
finding and do not wrap it in severity/file fields.

End with one final line in this exact shape:

```text
Verdict: GO | GO WITH NOTES | BLOCK
```

## Rules

- No style nitpicks unless they affect correctness or maintenance.
- Convention findings need a sibling pattern `file:line` or a named skill rule.
- Prefer minimal fixes.
- If a human should arbitrate risk, replan, or broad-impact tradeoffs, say so
  explicitly.
- If the request is to prove completion rather than review a diff, route to the
  verification workflow instead of treating it as code review.
- Never use `OK`, `APPROVED`, `PASS`, or other verdict words.
