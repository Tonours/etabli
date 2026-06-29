# Orchestration: ADR system hardening

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful packets.
- Integrate packet results before final verification.

## Branching Rules
- If research supports a lightweight local mechanism, implement it locally.
- If a proposed mechanism requires an external service or persistent index,
  reject it unless local evidence shows the Markdown approach cannot work.
- If tests reveal a behavior bug, fix the implementation before expanding docs.

## Packet Prompts
- P1 Research: collect ADR and LLM/ADR evidence from GitHub and arXiv.
- P2 Design: choose minimal guardrails for supersession, metadata, and
  validation.
- P3 Implementation: edit ADR format, skill, hook, validator, and tests.
- P4 Verification: run local checks and record skipped expensive checks.

## Completion Audit
- P1 complete: see `results/P1-research.md`.
- P2 complete: see `results/P2-design.md`.
- P3 complete: validator, skill, format, hook, and tests changed.
- P4 complete: see `final-report.md`.
