# Result P1: live Codex sync

Status: accepted

## Baseline

`scripts/deploy-codex --dry-run` initially failed with three conflicts:

- `skills/codex-dynamic-workflows/SKILL.md`
- `workflow/dynamic-workflow-triggers.md`
- `workflow/ticket-template.md`

All three live files were plain files under `~/.codex`, not symlinks.

## Decision

The diffs showed stale live copies. The tracked repo versions added the current
Codex App subagent rules, dynamic workflow trigger notes, and a more generic
ticket template. No secret or user-specific content was present in these three
files.

## Action

Backed up live files to:

`/Users/tonours/.codex/backups/etabli-hardening-20260703-021552`

Then copied tracked versions from:

- `codex/skills/codex-dynamic-workflows/SKILL.md`
- `codex/workflow/dynamic-workflow-triggers.md`
- `codex/workflow/ticket-template.md`

## Verification

- `cmp` reports all three tracked/live pairs identical.
- `scripts/deploy-codex --dry-run` exits `0` and ends with
  `SUMMARY      dry-run complete`.
- Live Codex files now contain the `multi_agent_v1` and no user-owned Codex
  threads guidance.

## Claim Labels

- live Codex sync: `confirmed`
- Codex App subagent runner proof: `confirmed` for the previously recorded
  current runtime only
- future Codex surfaces: `unknown`
