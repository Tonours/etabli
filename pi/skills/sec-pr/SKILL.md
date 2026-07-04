---
name: sec-pr
description: Audit a Dependabot or security GitHub PR with gh CLI. Verifies fixed alerts against Dependabot/GHSA, lockfile resolution, ignored/deferred evidence, CI, and returns PASS/FAIL/INVESTIGATE. Use for security PR review, Dependabot validation, vulnerability PR audit, or /sec-pr.
---

# Sec PR

Read and follow the shared contract in `workflow/skills/sec-pr.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/sec-pr.md`.
2. If missing, fall back to the Pi agent shared copy:
   `../../workflow/skills/sec-pr.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../../workflow/skills/sec-pr.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/sec-pr.md`.

Rules:
- Default is read-only.
- Never trust the PR body alone.
- Never merge automatically.
