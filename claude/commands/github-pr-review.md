---
description: Compatibility alias for /pr-review
argument-hint: [PR URL/number/repo alias]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# GitHub PR Review

This command is a compatibility alias for `/pr-review`.

Use `commands/pr-review.md` as the source of truth and follow the same contract:

- use `gh` for GitHub
- stay read-only unless the user explicitly asks to post or approve
- report only actionable findings grounded in the PR diff
- end with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`
