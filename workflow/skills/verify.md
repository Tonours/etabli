# Verify Contract

Shared contract for proving or rejecting a claim without editing.

Runtime adapters may add tool syntax or the Claude `/verify-workflow` name.
They must not change the read-only boundary, evidence labels, or verdict set.

Use `workflow/verification-report-template.md` when available. The routing map
`workflow/spec.md` wins on conflict; open it only when the route is in doubt.

## Purpose

Prove or reject a verification target from focused evidence.

## Required Sequence

1. Inspect repo state and the user's verification target.
2. Read `PLAN.md` when present.
3. Derive expected evidence from acceptance criteria, `Workflow Contract`,
   checks, cited sources, task state, or the user's claim.
4. Recheck declared observations and focused evidence; broaden only on request.
5. Do not edit files, install dependencies, update docs, stage commits, or
   fix failures.
6. Report each evidence item as `passed`, `failed`, `skipped`, or
   `inconclusive`.
7. End with exactly one verdict:
   - `VERIFIED`: evidence proves the target.
   - `NOT VERIFIED`: evidence contradicts the target.
   - `INCONCLUSIVE`: evidence is missing, too weak, blocked, or not
     runnable.

## Output

Without the template:

```md
# Verification Report

## Verdict
VERIFIED | NOT VERIFIED | INCONCLUSIVE

## Evidence Checked
- command/source:
  - expected:
  - observed:
  - status: passed | failed | skipped | inconclusive

## Gaps
- None / ...

## Next Action
-
```

## Rules

- Do not claim completion from intent, memory, or plausible status.
- If `PLAN.md` is `DRAFT` or `CHALLENGED`, verification can only prove the
  plan status, not implementation completion.
- If a command cannot run, include the exact error and mark the item
  `inconclusive`.
- If verification discovers an implementation bug, report it; do not fix
  it.

## Completion Evidence

A verify pass requires one verdict and a status per evidence item.
Required product plans: read workflow/product-verification.md.
