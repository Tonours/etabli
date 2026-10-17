---
name: review
description: Reviews diffs for bugs, regressions, plan drift, and conventions. Use when uncommitted or branch changes need review; not for GitHub PR threads or for writing the fix.
argument-hint: [uncommitted | branch <base> | commit <sha>]
allowed-tools: [Read, Glob, Grep, AskUserQuestion, Agent]
---

# Review

Read and follow the shared contract in `workflow/skills/review.md` and the
rubric in `workflow/review-rubric.md`. The contract's hunt-and-filter section
names the hunter runner for each runtime.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Rules:
- Stay read-only unless the user explicitly asks for validation beyond review.
- Do not hunt Logic in the parent.
- End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.
