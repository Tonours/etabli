# Packet 2: Add Verify Workflow

## Objective
Add a workflow verifier for Claude without colliding with Claude Code's native
`/verify`.

## Result
Accepted.

## Files
- `claude/commands/verify-workflow.md`
- `workflow/verification-report-template.md`

## Evidence
- `bash tests/workflow-docs-smoke.sh`
- `claude --version`
