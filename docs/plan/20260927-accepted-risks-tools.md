# Implemented: accepted review risks and Etabli-only tools named in the contract

## Metadata
- Archived: 2026-09-27
- Source plan: `PLAN.md` — Suites audit 5 et 6 — nommer les risques acceptés de la review et les outils ship-metrics / ledger-census dans le contrat
- Source plan SHA-256: `2e5bf8a8cd4a7157b5fc06f908940834e3f9778d8bfaa5d4e91505297a9359b7`
- Status: IMPLEMENTED
- Commit / branch: `docs/accepted-risks-tools`, stacked on `refactor/skills-hygiene` (base `ed8163a`); not pushed
- Workflow initiative: `risks-and-tools` (completed at F2)

## Outcome
- Suite 5 names the two accepted review risks:
  - `workflow/skills/review.md`, Daily Pi: the parent Spec pass shares the implementer's context (self-preference); Logic and the adversary stay independent.
  - `workflow/skills/implementation-loop.md`, small tier: self-review has no external feedback, which is acceptable because small excludes behavior change.
- Suite 6 names the two tools, both marked `etabli-only` and both kept:
  - `workflow/skills/ship.md` step 12: in Etabli, `scripts/workflow-ship-metrics` (`upsert`) writes the registry row under its own per-slug lock file, with the same backend choice as `scripts/workflow-event` (`lockf`, `flock` or `shlock`). Without it, the row schema and the `flock` rule stay the reference.
  - `workflow/contract-details.md` Runtime surfaces: in Etabli, `scripts/workflow-ledger-census` (`baseline`, then `diff`) freezes each ledger's verdict and sha256. `diff` fails on a verdict flip, a non-append rewrite, a current FAIL, a missing baseline slug, or a grandfathered byte-string under a new slug.
- `tests/ship-order-smoke.sh` pins every substantive clause.
- No rule changed.

## Context
- `scripts/workflow-ref-linter` sees a ref only when the path is alone in backticks, and exempts a line only with a raw `<!-- etabli-only -->` marker on that line.
- `tests/workflow-docs-smoke.sh` caps `workflow/events-validator.md` at 64 lines, so the census note moved to `workflow/contract-details.md` (cap 284).
- `scripts/deploy-workflow` copies these docs into projects but not the two tools, hence "In Etabli".

## Decisions
### Name the tools instead of retiring them
- Context: audit §2 kept both tools; `ship.md` required the registry without naming its writer.
- Choice: name both, keep both (fixtures in `tests/ship-order-smoke.sh`).
- Rejected options: retire them, or deploy them to projects.

### Describe the lock as it is
- Context: plan passes R1 and R2 showed that "same lock" was false, since the tool locks its own per-slug file.
- Choice: say "same backend choice"; the `flock` rule stays for projects without the tool (an exclusive-lock rule, not a rule change).

## Accepted Drift
- Original plan/spec: AC4 in `workflow/events-validator.md`.
- Implemented reality: `workflow/contract-details.md`, Runtime surfaces.
- Why accepted: the 64-line cap of `events-validator.md` is kept instead of raised.

## Validation Evidence
- command: `bash tests/ship-order-smoke.sh`, `bash tests/workflow-docs-smoke.sh`, `scripts/workflow-ref-linter --target all`, `scripts/workflow-context-budget`, `scripts/token-bench --check`
  - result: all ok. The pins, the linter marker check and the census-clause pin each bite when their text is mutated.
- command: `scripts/verify-agentic-infra core` and `full`
  - result: 27/27 and 81/81 (F1 validation first failed at 80/81 on the docs cap, then was folded)
- Reviews:
  - Plan: 5 cross-family passes via `scripts/pi-review-hunter` (`openai-codex/gpt-6-astra`), the last one READY.
  - Code: T1 and T2 findings, D1 clean, F1 findings (the docs-cap failure), FD findings (implementation drift caught by plan pass R4), F2 clean (Logic GO, Spec GO, pi GO, capture `67931bd7`).
