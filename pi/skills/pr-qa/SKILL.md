---
name: pr-qa
description: Generate a QA impact analysis and executable test plan for a GitHub PR through the gh CLI. Use when the user asks how to test a PR, asks for PR QA, impact analysis, happy path, edge cases, or a manual QA plan.
---

# PR QA

Read and follow the shared contract in `workflow/skills/pr-qa.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/pr-qa.md`.
2. If missing, fall back to the Pi agent shared copy:
   `../../workflow/skills/pr-qa.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../../workflow/skills/pr-qa.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/pr-qa.md`.

Rules:
- Use `gh` for GitHub.
- Generate a read-only QA plan.
- Do not comment, approve, edit, checkout, or merge the PR.
