# Review Contract

Shared contract for reviewing local changes, branch diffs, or commits.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the read-only default, finding format, plan-compliance check, verdict
labels, deciding-code gate, or two-pass order.

## Purpose

Review changes for correctness, regressions, risks, validation gaps, convention
or pattern drift, and plan drift. Use `workflow/review-rubric.md` as the source
of truth when available.

## Two passes

1. **Break-first** — do not open `PLAN.md`. Fill lens table + deciding-code
   table. Hunt what breaks.
2. **Plan-fit** — open `PLAN.md` only after pass 1. Scope, checks, drift against
   pass-1 findings. No free second bug-hunt.

Solo review without an active plan may run a single combined pass; deciding-code
still applies to runtime behaviors.

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
4. When the diff touches language, framework, or UI surface, load
   `code-quality` when exposed, otherwise the narrowest exposed domain or
   project skill. If none is exposed, compare the diff directly with 1–3 local
   sibling implementations. If neither a skill nor a relevant sibling exists,
   report the convention lens as `not run`; never present it as clean (see
   rubric § Convention & pattern fit).

## Review Scope

Review only the target scope. Cover:

- self-check;
- break-first correctness (lenses + deciding-code);
- plan compliance (plan-fit pass);
- regressions, safety, validation;
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

Then the **lens table** and **deciding-code table** from the rubric (mandatory).

If there are no actionable issues, put exactly `No findings.` as the only
finding and do not wrap it in severity/file fields.

End with one final line in this exact shape:

```text
Verdict: GO | GO WITH NOTES | BLOCK
```

`GO` is forbidden when any non-trivial runtime deciding-code row is empty or
`not run`. `GO WITH NOTES` is not a workaround for that gate.

## Rules

- No style nitpicks unless they affect correctness or maintenance.
- Convention findings need a sibling pattern `file:line` or a named skill rule.
- Prefer minimal fixes.
- If a human should arbitrate risk, replan, or broad-impact tradeoffs, say so
  explicitly.
- If the request is to prove completion rather than review a diff, route to the
  verification workflow instead of treating it as code review.
- Never use `OK`, `APPROVED`, `PASS`, or other verdict words.
