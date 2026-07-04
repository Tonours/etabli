---
name: pr-review
description: Review a GitHub pull request through gh CLI with a human-in-the-loop posting workflow. Use for PR review, GitHub code review, review comments, requested changes, approval guidance, or /pr-review.
---

# PR Review

Read and follow the shared contract in `workflow/skills/pr-review.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/pr-review.md`.
2. If missing, fall back to the Pi agent shared copy:
   `../../workflow/skills/pr-review.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../../workflow/skills/pr-review.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/pr-review.md`.

Rules:
- Use `gh` for GitHub unless the user explicitly overrides this.
- Default is read-only.
- Do not post comments or approve without explicit user approval.
