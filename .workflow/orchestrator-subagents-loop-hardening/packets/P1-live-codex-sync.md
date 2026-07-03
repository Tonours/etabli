# Packet P1: live Codex sync

Objective: resolve the remaining `scripts/deploy-codex --dry-run` conflicts
without touching secrets or blindly overwriting live local files.

Files / sources:
- `scripts/deploy-codex`
- `codex/skills/codex-dynamic-workflows/SKILL.md`
- `codex/workflow/dynamic-workflow-triggers.md`
- `codex/workflow/ticket-template.md`
- matching live files under `~/.codex/`

Expected output:
- backups created for any live file changed;
- exact diff/decision for every conflict;
- clean dry-run or documented blocker.

Verification:
- `scripts/deploy-codex --dry-run`
