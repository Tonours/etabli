---
name: bug-check
description: Diagnoses a Linear bug with adversarial root-cause rigor, analysis only. Use when a bug needs a cause before any fix; not for implementing fixes, non-Linear triage, or dependency/security audits.
argument-hint: [Linear URL/key]
allowed-tools: [Read, Glob, Grep, AskUserQuestion]
---

# Bug Check

Read and follow the shared contract in `workflow/skills/bug-check.md`.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

Rules:
- Read the Linear issue through the Linear MCP tools (issue, comments,
  attachments); stop with `LINEAR_MCP_UNAVAILABLE` if they cannot run.
- This skill is read-only.
- Do not create `PLAN.md`.
- Do not edit files, post to Linear, or implement.
