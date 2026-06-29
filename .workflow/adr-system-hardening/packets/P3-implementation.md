Packet ID: P3
Objective: Implement the selected guardrails.
Context: Changes should stay scoped to ADR format/skill/hook/tests/scripts.
Files / sources: `claude/skills/adr/`, `claude/hooks/detect-adr-signal.mjs`,
`scripts/validate-adrs`, ADR tests.
Ownership: Code and docs changes.
Do: Add validator, update hook regexes, update skill instructions, add tests.
Do not: Commit, push, add external services, or broaden unrelated workflow
logic.
Expected output: Local diff.
Verification: Narrow tests and syntax checks pass.
