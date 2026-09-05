---
name: sec-pr
description: Audit security/Dependabot PRs with gh; verify GHSA fixes, lock resolution, ignored/deferred alerts and CI. Return PASS/FAIL/INVESTIGATE.
---

# sec-pr

Follow the shared contract in `workflow/skills/sec-pr.md`.

ForestAdmin Dependabot extras (structured body, isolated worktree, PASS-only
approve): read `references/forest-dependabot.md`.

Rules:
- Do not merge.
- Use `gh`, not the GitHub MCP/app connector, unless the user overrides.
