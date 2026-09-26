---
description: Generate a QA impact analysis and test plan for a GitHub PR. Use when a PR needs a test strategy or QA needs manual steps; not for executing tests.
argument-hint: [PR URL/number/repo alias]
allowed-tools: [Read, Glob, Grep, AskUserQuestion]
---
<!-- GENERATED:adapter-sync:start -->
skill: pr-qa
harness: claude
canonical: workflow/skills/pr-qa.md
description: Generate a QA impact analysis and test plan for a GitHub PR. Use when a PR needs a test strategy or QA needs manual steps; not for executing tests.
pointer: Adapter for the `pr-qa` skill. Read and follow the shared contract in `workflow/skills/pr-qa.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# PR QA

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/pr-qa.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use `gh` for GitHub.
- Generate a read-only QA plan.
- Do not comment, approve, edit, checkout, or merge the PR.
