---
name: verify
description: Verify or retest claims without editing.
---

# Verify

Follow `workflow/spec.md` and use `workflow/verification-report-template.md`
when available.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


## Contract

1. Inspect repo state and the user's verification target.
2. Read `PLAN.md` when present.
3. Derive expected evidence from acceptance criteria, `Workflow Contract`,
   checks, cited sources, task state, or the user's claim.
4. Run or inspect only focused evidence unless the user asked for broad
   validation.
5. Do not edit files, install dependencies, update docs, stage commits, or fix
   failures.
6. Report each evidence item as `passed`, `failed`, `skipped`, or
   `inconclusive`.
7. End with exactly one verdict:
   - `VERIFIED`: evidence proves the target.
   - `NOT VERIFIED`: evidence contradicts the target.
   - `INCONCLUSIVE`: evidence is missing, too weak, blocked, or not runnable.

## Output

Use this shape:

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

Rules:

- Do not claim completion from intent, memory, or plausible status.
- If `PLAN.md` is `DRAFT` or `CHALLENGED`, verification can only prove the plan
  status, not implementation completion.
- If a command cannot run, include the exact error and mark the item
  `inconclusive`.
- If verification discovers an implementation bug, report it; do not fix it.
