---
name: github-pr-review
description: Compatibility alias for pr-review. Use when an older prompt asks for github-pr-review; follow the pr-review workflow through gh CLI.
---

# GitHub PR Review

Use `pr-review`. This skill exists only as a compatibility alias for earlier
workflow prompts.

Follow `../pr-review/SKILL.md` when available. If unavailable, use the same
contract:

- use `gh` for GitHub
- stay read-only unless the user explicitly asks to post or approve
- report only actionable findings grounded in the PR diff
- end with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`
