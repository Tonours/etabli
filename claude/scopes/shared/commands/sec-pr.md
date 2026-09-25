---
description: Audit a Dependabot or security PR through gh CLI. Use when a bot-opened dependency change or security PR needs vetting; not for feature PRs.
argument-hint: [PR URL/number/repo]
allowed-tools: [Read, Glob, Grep, AskUserQuestion]
---
<!-- GENERATED:adapter-sync:start -->
skill: sec-pr
harness: claude
canonical: workflow/skills/sec-pr.md
description: Audit a Dependabot or security PR through gh CLI. Use when a bot-opened dependency change or security PR needs vetting; not for feature PRs.
pointer: Adapter for the `sec-pr` skill. Read and follow the shared contract in `workflow/skills/sec-pr.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Sec PR

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/sec-pr.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Default is read-only.
- Never trust the PR body alone.
- Never merge automatically.
