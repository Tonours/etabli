---
description: Review uncommitted changes, a branch diff, or a specific commit using the shared rubric
argument-hint: [uncommitted | branch <base> | commit <sha>]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Review

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/review.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/review.md`.
2. If missing, fall back to the Claude shared copy:
   `../workflow/skills/review.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../workflow/skills/review.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/review.md`.

Rules:
- Use `workflow/review-rubric.md` when available.
- Stay read-only unless the user explicitly asks for validation beyond review.
- End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.
