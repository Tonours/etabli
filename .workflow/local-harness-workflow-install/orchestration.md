# Orchestration: Local harness workflow install

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful packets.
- Integrate packet results before final verification.

## Branching Rules
- If Codex dry-run reports conflicts, inspect each file and back up before
  applying `--force`.
- If `scripts/install.sh` would replace local Pi/Claude files, rely on its
  backup helpers for managed paths and inspect any failure before retrying.
- If real agent scenarios fail because a CLI is absent or logged out, keep the
  local install result but mark runtime validation as blocked with exact output.

## Packet Prompts
- P1 inventory: list current symlink/copy state for `~/.codex`, `~/.claude`,
  and `~/.pi` without changing files.
- P2 Codex: run deploy dry-run, resolve conflicts if needed, then apply and
  rerun dry-run.
- P3 Claude/Pi: run installer and verify expected links/resources.
- P4 validation: run repo smoke tests and real harness scenario test.

## Completion Audit
- All three harnesses have the hardened workflow source available locally.
- Local settings that are intentionally not tracked remain local.
- Verification commands and outcomes are recorded in `final-report.md`.
