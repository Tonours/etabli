# ADR helper hardening final report

See `results/final-summary.md` for the detailed outcome, verification commands,
Claude `-p` cost/duration, and residual risks.

Summary:
- Added bundled deterministic helper:
  `claude/skills/adr/scripts/apply-adr.mjs`.
- Updated `/adr` skill instructions to call the helper for write/index mechanics.
- Added `tests/adr-helper-smoke.sh` and wired it into CI.
- Verified base E2E and stress matrices with `claude -p` after the helper update.
