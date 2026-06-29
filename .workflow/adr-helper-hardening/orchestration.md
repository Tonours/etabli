# Orchestration: ADR helper hardening

## Responsibility split
- Claude keeps: identifying the decision, grounding it in local evidence,
  applying the three-condition test, drafting concise English ADR content, and
  deciding whether supersession is grounded or uncertain.
- Helper takes: validation, next number, slug, file write, old ADR supersession
  metadata, `CLAUDE.md` index update, and post-write consistency checks.

## Branching rules
- If deterministic code becomes broad or framework-like, stop and keep the
  prompt-level rule instead.
- If a helper test exposes a missing invariant, add the smallest deterministic
  check before changing `SKILL.md`.
- If `claude -p` ignores the helper, simplify the skill procedure instead of
  adding more prose.

## Packets
- H1 Design: map model-driven vs deterministic responsibilities.
- H2 Helper: implement bundled `apply-adr.mjs`.
- H3 Tests: add smoke coverage for helper invariants.
- H4 Skill update: point `/adr` at the helper and remove hand-write details.
- H5 Verification: run local checks plus targeted forward test.
