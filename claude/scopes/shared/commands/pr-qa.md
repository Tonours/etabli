---
description: Generate a QA impact analysis and test plan for a GitHub PR
argument-hint: [PR URL/number/repo alias]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# PR QA

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/pr-qa.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/pr-qa.md`.
2. If missing, fall back to the Claude shared copy:
   `../workflow/skills/pr-qa.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../workflow/skills/pr-qa.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/pr-qa.md`.

Rules:
- Use `gh` for GitHub.
- Generate a read-only QA plan.
- Do not comment, approve, edit, checkout, or merge the PR.
