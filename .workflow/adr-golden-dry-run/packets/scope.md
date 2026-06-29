# Packet: scope and evidence

## Target
Tighten the deterministic ADR tooling added by the previous hardening pass:
`adr-validation.mjs`, `apply-adr.mjs`, `scripts/validate-adrs`, and ADR tests.

## Expected evidence
- Golden fixture script proves stable validator behavior.
- Helper smoke script proves `--dry-run` is non-mutating.
- Existing ADR suites prove no regression in validator/helper/hook/skill checks.
- Workflow verifier accepts this artifact.
