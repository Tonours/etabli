---
description: Verify checks, claims, or workflow completion without editing. Use when evidence must confirm a claim; not for fixing.
argument-hint: [target claim or checks]
allowed-tools: [Read, Glob, Grep, AskUserQuestion]
---
<!-- GENERATED:adapter-sync:start -->
skill: verify
harness: claude
canonical: workflow/skills/verify.md
description: Verify checks, claims, or workflow completion without editing. Use when evidence must confirm a claim; not for fixing.
pointer: Adapter for the `verify` skill. Read and follow the shared contract in `workflow/skills/verify.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Verify Workflow

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/verify.md`.

This command intentionally uses `/verify-workflow` instead of `/verify` because
Claude Code ships a native `/verify` skill for running and checking apps.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
