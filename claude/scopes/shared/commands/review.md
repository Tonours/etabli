---
description: Review uncommitted changes, a branch diff, or a specific commit using the shared rubric. Use when local changes need review; not for GitHub PR threads.
argument-hint: [uncommitted | branch <base> | commit <sha>]
allowed-tools: [Read, Glob, Grep, AskUserQuestion, Agent]
---
<!-- GENERATED:adapter-sync:start -->
skill: review
harness: claude
canonical: workflow/skills/review.md
description: Review uncommitted changes, a branch diff, or a specific commit using the shared rubric. Use when local changes need review; not for GitHub PR threads.
pointer: Adapter for the `review` skill. Read and follow the shared contract in `workflow/skills/review.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Review

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/review.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use `workflow/review-rubric.md` when available.
- Stay read-only unless the user explicitly asks for validation beyond review.
- End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.
