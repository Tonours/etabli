---
description: Compatibility alias for /pr-review
argument-hint: [PR URL/number/branch]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# GitHub PR Review

User request: $ARGUMENTS

Use `/pr-review`. This command exists only as a compatibility alias for earlier
workflow prompts. Follow the `/pr-review` contract: GitHub through `gh`, default
read-only, human validation before posting, verdict `GO`, `GO WITH NOTES`, or
`BLOCK`.
