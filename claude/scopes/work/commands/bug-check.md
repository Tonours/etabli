---
description: Analyze a Linear bug with adversarial root-cause rigor, diagnosis only. Use when a bug needs a cause before any fix; not for implementing fixes or dependency/security audits.
argument-hint: [Linear URL/key]
allowed-tools: [Read, Glob, Grep, AskUserQuestion]
---
<!-- GENERATED:adapter-sync:start -->
skill: bug-check
harness: claude
canonical: workflow/skills/bug-check.md
description: Analyze a Linear bug with adversarial root-cause rigor, diagnosis only. Use when a bug needs a cause before any fix; not for implementing fixes or dependency/security audits.
pointer: Adapter for the `bug-check` skill. Read and follow the shared contract in `workflow/skills/bug-check.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Bug Check

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/bug-check.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Read-only only.
- Do not create `PLAN.md`, edit files, post to Linear, or implement.
