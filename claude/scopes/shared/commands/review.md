---
description: Review uncommitted changes, a branch diff, or a specific commit using the shared rubric
argument-hint: [uncommitted | branch <base> | commit <sha>]
allowed-tools: [Read, Glob, Grep, AskUserQuestion, Agent]
---

# Review

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/review.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use `workflow/review-rubric.md` when available.
- Stay read-only unless the user explicitly asks for validation beyond review.
- End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.
