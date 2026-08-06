---
description: Review a GitHub PR through gh CLI with human-in-the-loop posting
argument-hint: [PR URL/number/repo alias]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# PR Review

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/pr-review.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/pr-review.md`.
2. If missing, fall back to the Claude shared copy:
   `../workflow/skills/pr-review.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../workflow/skills/pr-review.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/pr-review.md`.

Rules:
- Use `gh` for GitHub unless the user explicitly overrides this.
- Default is read-only.
- Do not post comments or approve without explicit user approval.
