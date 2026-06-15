# Packet 1: Align Claude Commands

## Objective
Make Claude commands follow the shared workflow contract instead of drifting
from the Pi loop.

## Result
Accepted.

## Files
- `claude/commands/plan-create.md`
- `claude/commands/plan-loop.md`
- `claude/commands/plan-implement.md`
- `claude/commands/implement.md`
- `claude/commands/review.md`

## Evidence
- `bash tests/workflow-docs-smoke.sh`
- `RUN_AGENT_CLI_SMOKE=1 RUN_CLAUDE_PRINT_SMOKE=1 bash tests/workflow-cli-smoke.sh`
