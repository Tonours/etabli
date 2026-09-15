# Implemented: explicit reviewed context-budget growth remediation

## Metadata
- Archived: 2026-09-14
- Status: IMPLEMENTED
- Scope: reviewed context-budget remediation

The gate keeps strict ceilings while making intentional growth explicit.
Diagnostics now point to an on-demand move or a reviewed ceiling change.
## Outcome
- Over-ceiling diagnostics now present two clear paths: trim/move detail to a
  genuinely on-demand doc, or intentionally raise `ceiling_chars` in a reviewed
  budget diff with a Decision Log rationale.
- The `--ratchet` refusal uses the same wording and explicitly says `otherwise
  finish the trim and re-run the gate first`.
- The hard failure, no-write-on-red behavior, ratchet-only lowering, thresholds,
  and surface membership are unchanged.

## Context
- Source of truth: `workflow/skills/self-improvement-loop.md` already required
  reviewed budget growth but the executable diagnostics omitted that path.
- The existing gate reported seven surfaces with near-zero headroom; this fix
  improves remediation guidance without hiding growth.

## Decisions
### Keep the gate strict
- Context: near-zero headroom is intentional protection against silent resident
  context growth.
- Choice: retain exit 1 on unreviewed over-ceiling surfaces and add guidance for
  a reviewed ceiling change.
- Rejected options: tolerance, warning-only mode, automatic ceiling raises, or
  changing current ceilings.
- Consequences: legitimate growth is possible through an explicit reviewed diff;
  accidental growth remains a CI failure.

### Share wording across both over-ceiling paths
- Context: the normal diagnostic and `--ratchet` refusal are separate branches.
- Choice: one `REVIEWED_GROWTH_REMEDIATION` constant plus smoke assertions for
  both branches.
- Consequences: future wording drift between the paths is less likely.

## Accepted Drift
- Original plan/spec: only the normal over-ceiling message needed clarification.
- Implemented reality: the adversary found the ratchet refusal also needed the
  same guidance and an explicit alternative; the plan and smoke were strengthened
  without changing behavior.
- Why accepted: it closes a reachable, directly related diagnostic gap.

## Public/private boundary

The public record keeps the remediation rule and its acceptance criteria.
It omits raw traces, machine paths, account references, and case identifiers.
Those details remain in the approved private store for their context.

## Validation contract

- Normal over-ceiling output explains both safe remediation paths.
- Ratchet mode emits the same wording and never writes on a red run.
- Smoke fixtures assert the wording and the no-write guarantee.
- The budget file changes only through an explicit reviewed diff.
- Static measurements remain distinct from billed-token evidence.

## Review notes

The change closes a diagnostic gap without weakening the hard failure.
Automatic ceiling raises remain rejected because they hide growth.
A future proposal must include a frozen baseline and a reproducible run.

## Follow-up

Keep the gate strict until a reviewed change demonstrates a need to grow.
Record accepted growth in the decision log and event ledger.
Verify both remediation branches during the next self-improvement pass.
