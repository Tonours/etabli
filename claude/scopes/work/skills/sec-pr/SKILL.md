---
name: sec-pr
description: Audit a Dependabot or security GitHub PR with gh CLI. Verifies fixed alerts against Dependabot/GHSA, lockfile resolution, ignored/deferred evidence, CI, and returns PASS/FAIL/INVESTIGATE. Use for security PR review, Dependabot validation, vulnerability PR audit, or /sec-pr.
---

# sec-pr

Follow the shared contract in `workflow/skills/sec-pr.md`.

ForestAdmin Dependabot extras (structured body, isolated worktree, PASS-only
approve): read `references/forest-dependabot.md`.

Rules:
- Do not merge.
- Use `gh`, not the GitHub MCP/app connector, unless the user overrides.
