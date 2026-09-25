---
name: pr-qa
description: Create a QA impact analysis and executable PR test plan, including manual click-throughs. Use when a PR needs a test strategy or QA needs manual steps; not for executing tests or for non-PR changes.
---
<!-- GENERATED:adapter-sync:start -->
skill: pr-qa
harness: pi
canonical: workflow/skills/pr-qa.md
name: pr-qa
description: Create a QA impact analysis and executable PR test plan, including manual click-throughs. Use when a PR needs a test strategy or QA needs manual steps; not for executing tests or for non-PR changes.
pointer: Adapter for the `pr-qa` skill. Read and follow the shared contract in `workflow/skills/pr-qa.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# PR QA

Read and follow the shared contract in `workflow/skills/pr-qa.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use `gh` for GitHub.
- Generate a read-only QA plan.
- Do not comment, approve, edit, checkout, or merge the PR.
