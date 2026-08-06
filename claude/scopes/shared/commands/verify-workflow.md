---
description: Verify checks, claims, or workflow completion without editing
argument-hint: [target claim or checks]
allowed-tools: [Read, Glob, Grep, AskUserQuestion]
---

# Verify Workflow

User request: $ARGUMENTS

Follow `workflow/spec.md` and use `workflow/verification-report-template.md`
when available.

This command intentionally uses `/verify-workflow` instead of `/verify` because
Claude Code ships a native `/verify` skill for running and checking apps.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/verification-report-template.md`
   - `PLAN.md`
2. If one of the workflow files is missing in the current workspace, fall back
   to the Claude shared copies when this command is loaded through
   `~/.claude/commands`:
   - `../workflow/spec.md`
   - `../workflow/verification-report-template.md`
3. If those are unavailable, fall back to the Etabli repo copies when this
   command is loaded from the repo target path:
   - `../../workflow/spec.md`
   - `../../workflow/verification-report-template.md`
4. If workflow sources exist through any fallback, read them and continue. Do
   not report them missing.

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
