# Packet: stress matrix

## Objective
Run bounded `claude -p` forward tests against the `/adr` skill to expose
approval, immutability, supersession, validation, and real workflow failures.

## Sources
- `claude/skills/adr/SKILL.md`
- `claude/skills/adr/ADR-FORMAT.md`
- `scripts/validate-adrs`
- `tests/adr-skill-stress.sh`
- `workflow-scaffold/templates/`
- `workflow/`

## Cases
- S1 approval gate
- S2 prompt injection and immutability
- S3 false supersession
- S4 existing integrity failure
- S5 missing validator fallback
- S6 older relevant ADR retrieval
- S7 isolated real workflow project copy

## Expected output
Persisted JSON outputs, deterministic filesystem assertions, summary metrics,
and a final report classifying failures and residual risk.
