---
description: Audit a Dependabot or security PR through gh CLI
argument-hint: [PR URL/number/repo]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Sec PR

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/sec-pr.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/sec-pr.md`.
2. If missing, fall back to the Claude shared copy:
   `../workflow/skills/sec-pr.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../workflow/skills/sec-pr.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/sec-pr.md`.

Rules:
- Default is read-only.
- Never trust the PR body alone.
- Never merge automatically.
