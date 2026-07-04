# Loop-engineering hardening of autonomous workflows (2026-07-04)

## What

Folded six loop-engineering practices (from Anthropic long-running-agent
harness posts and 2026 loop-engineering guides) into the shared workflow
contract so autonomous runs terminate deterministically and survive
interruptions.

## Changes

- `workflow/spec.md` Rules: no-progress stop (2× same failed hypothesis or 3×
  same red check without new diff -> `blocked` + `no_progress` event);
  check-freeze after `READY` (weakening requires demotion to `CHALLENGED` with
  Decision Log rationale); event ledger mandatory for autonomous routes
  (`plan-implement` autonome, `/goal`, `ci-fix`), still optional for ordinary
  work; explicit cap (iterations or wall-clock) in autonomous stop conditions
  (ci-fix keeps its existing caps); fresh-context reviewer for autonomous
  plan-implement with blocked-fallback; handoffs as `handoff` events.
- `workflow/spec.md` Claude-native loop: `/goal` pairs the measurable condition
  with an explicit cap and records the ledger.
- `workflow/events.md` + `scripts/workflow-event`: new event types
  `no_progress` and `handoff` with detail conventions.
- `workflow/skills/orchestration.md`: `/goal` cap + ledger line.
- `workflow/skills/implementation-loop.md`: fresh-context review step and
  ledger in completion evidence.
- `tests/workflow-docs-smoke.sh`: 13 assertions pinning the new phrases.

## Decisions

- Enforcement stays prose + smoke pinning; no new hooks (guards already cover
  irreversibility boundaries).
- Commit-checkpoint policy for autonomous loops deliberately excluded (needs
  user arbitration vs "no commit unless asked").
- Planned scaffold-templates sync turned out to be a no-op: scaffold generation
  reads live `workflow/` files, so parity is automatic.

## Validation

workflow-docs-smoke, workflow-scaffold-smoke, workflow-event-smoke,
workflow-contract-coverage-smoke, claude-hooks-smoke: all pass. Adversary
(Codex): initial BLOCK folded (evidence alignment, fresh-context fallback,
check-freeze escape hatch, enriched no_progress fields). Fresh-context
reviewer verdict: GO WITH NOTES.
