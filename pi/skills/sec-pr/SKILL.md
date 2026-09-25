---
name: sec-pr
description: Audit a Dependabot or security PR for advisories, lock resolution, and CI. Use when a bot-opened dependency change or security PR needs vetting for advisories, CVEs, and lock resolution; not for feature PRs or for merging.
---
<!-- GENERATED:adapter-sync:start -->
skill: sec-pr
harness: pi
canonical: workflow/skills/sec-pr.md
name: sec-pr
description: Audit a Dependabot or security PR for advisories, lock resolution, and CI. Use when a bot-opened dependency change or security PR needs vetting for advisories, CVEs, and lock resolution; not for feature PRs or for merging.
pointer: Adapter for the `sec-pr` skill. Read and follow the shared contract in `workflow/skills/sec-pr.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Sec PR

Read and follow the shared contract in `workflow/skills/sec-pr.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Default is read-only.
- Never trust the PR body alone.
- Never merge automatically.
