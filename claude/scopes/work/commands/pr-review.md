---
description: Review a GitHub PR through gh CLI and post when asked. Use when a PR needs review feedback; not for local diffs or Dependabot/security audits.
argument-hint: [PR URL/number/repo alias]
allowed-tools: [Read, Glob, Grep, AskUserQuestion, Agent]
---
<!-- GENERATED:adapter-sync:start -->
skill: pr-review
harness: claude
canonical: workflow/skills/pr-review.md
description: Review a GitHub PR through gh CLI and post when asked. Use when a PR needs review feedback; not for local diffs or Dependabot/security audits.
pointer: Adapter for the `pr-review` skill. Read and follow the shared contract in `workflow/skills/pr-review.md`. If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# PR Review

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/pr-review.md`.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use `gh` for GitHub unless the user explicitly overrides this.
- Default is read-only.
