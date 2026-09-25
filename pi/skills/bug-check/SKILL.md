---
name: bug-check
description: Diagnose a Linear bug with adversarial root-cause rigor, analysis only. Use when a bug needs a cause before any fix; not for implementing fixes, non-Linear triage, or dependency/security audits.
---
<!-- GENERATED:adapter-sync:start -->
skill: bug-check
harness: pi
canonical: workflow/skills/bug-check.md
name: bug-check
description: Diagnose a Linear bug with adversarial root-cause rigor, analysis only. Use when a bug needs a cause before any fix; not for implementing fixes, non-Linear triage, or dependency/security audits.
pointer: Adapter for the `bug-check` skill. Read and follow the shared contract in `workflow/skills/bug-check.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Bug Check

Read and follow the shared contract in `workflow/skills/bug-check.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- This skill is read-only.
- Do not create `PLAN.md`.
- Do not edit files, post to Linear, or implement.
