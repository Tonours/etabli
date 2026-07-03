# Packet P5: validation and review

Objective: prove completion against the original goal.

Expected output:
- validation command results;
- final claim matrix;
- GO/NO-GO verdict;
- remaining risks.

Required checks:
- `scripts/deploy-codex --dry-run`
- workflow docs/scaffold/codex/claude smokes
- `bun test pi/extensions/__tests__/`
- real Pi/Claude/Codex scenarios
- workflow verifier for this run
