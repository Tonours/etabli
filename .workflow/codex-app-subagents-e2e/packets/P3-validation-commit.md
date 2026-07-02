# P3 Validation Commit Packet

## Objective

Validate the Codex App setup and commit the completed change locally.

## Checks

- `bash tests/workflow-docs-smoke.sh`
- `bash tests/codex-organization-smoke.sh`
- `python3 /Users/tonours/.codex/skills/codex-dynamic-workflows/scripts/verify_workflow.py .workflow/codex-app-subagents-e2e`
- `git diff --check`
- `git status --short --branch`

## Acceptance

- Checks pass.
- Staged diff matches the Codex App setup scope.
- One local commit is created.
