---
name: ci-fix
description: Autonomously diagnose and fix failing GitHub PR CI through gh CLI, local repro, commits, and pushes under strict safeguards. Use only when the user explicitly asks to fix CI until green, make checks pass, or run /ci-fix.
---

# CI Fix

Read and follow the shared contract in `workflow/skills/ci-fix.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/ci-fix.md`.
2. If missing, fall back to the Pi agent shared copy:
   `../../workflow/skills/ci-fix.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../../workflow/skills/ci-fix.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/ci-fix.md`.

Rules:
- Use only when explicitly invoked or clearly requested.
- This skill may stash, checkout, rebase, commit, and push only within the
  shared contract's safeguards.
- Never plain `--force`.
