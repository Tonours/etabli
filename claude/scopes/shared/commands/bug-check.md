---
description: Analyze a Linear bug with adversarial root-cause rigor
argument-hint: [Linear URL/key]
allowed-tools: [Read, Glob, Grep, AskUserQuestion]
---

# Bug Check

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/bug-check.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/bug-check.md`.
2. If missing, fall back to the Claude shared copy:
   `../workflow/skills/bug-check.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../workflow/skills/bug-check.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/bug-check.md`.

Rules:
- Read-only only.
- Do not create `PLAN.md`, edit files, post to Linear, or implement.
