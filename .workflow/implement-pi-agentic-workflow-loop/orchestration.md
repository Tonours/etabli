# Orchestration: Implement Pi agentic workflow loop

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful packets.
- Integrate packet results before final verification.

## Branching Rules

- If a phase has tests, run focused tests before broad tests.
- If an optional phase lacks its gate, document the deferral instead of
  implementing it.
- If live Pi cannot be exercised non-interactively, record the exact blocker and
  provide a manual check.

## Packet Prompts

### Phase 1: Visible Contracts

Update workflow docs and templates with role, route, stop condition, and
required evidence.

### Phase 2: Verify Skill

Add `pi/skills/verify`, wire settings/install/symlink checks, and preserve
read-only verifier semantics.

### Phase 3: Skill Hardening

Update plan and implementation skills to enforce evidence and stop on material
plan drift.

### Phase 4: Router Runtime

Add pure route classification helpers, Pi lifecycle extension, and tests.

### Phase 5: Task Loop Evidence

Extend task loop behavior with route logging, validation evidence, and visible
stop messages.

### Phase 6: Fixtures

Add golden prompt fixtures that assert route, write permission, and stop
condition.

## Completion Audit
- Verify every acceptance criterion in `docs/pi-agentic-workflow-loop-plan.md`.
- Record commands and evidence in `final-report.md`.
- Do not mark complete until all required validations pass or a real blocker is
  documented.
