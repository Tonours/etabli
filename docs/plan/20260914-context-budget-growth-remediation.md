# Implemented: explicit reviewed context-budget growth remediation

## Metadata
- Archived: 2026-09-14
- Source plan: `PLAN.md` — Make context-budget growth remediation explicit
- Source plan SHA-256: `169d9245f04f0eba4740a92f73c54dbd5c7e000a32e7bfded74feaa16835886e`
- Status: IMPLEMENTED
- Commit / branch: local `main` (commit after archive; no push)

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

## Validation Evidence
- `node --check scripts/workflow-context-budget` — passed.
- `bash tests/workflow-context-budget-smoke.sh` — passed, including normal and
  `--ratchet` over-ceiling wording and no-write assertions.
- `scripts/workflow-context-budget` — passed, 7/7 surfaces within ceiling.
- `scripts/verify-agentic-infra core` — passed, 19/19 checks.
- `git diff --check` — passed.
- Expected-red reproductions were captured before each accepted wording fix.
- Fresh Logic + Spec review (`reviewer_model=gpt-6-astra`) — `GO`, complete
  deciding-code tables.
- Fresh cross-model code adversary (`adversary_model=gpt-5.5`) — final `GO`, no
  findings.
- Simplification: `simplify: clean`; quality: sibling comparison clean.
- Autonomous ledger: `.workflow/context-budget-growth/events.jsonl`, validated
  with `scripts/workflow-event validate context-budget-growth --profile
  autonomous-completed` after the terminal event.

## Follow-up State
- Remaining risks: the gate still requires a reviewed budget-file diff for
  intentional growth; this is deliberate. The unrelated untracked
  `pi/extensions/pi-mobile-bridge.ts` remains untouched.
- Parking lot: none for this fix.
- Superseded docs/specs: none.
- Next links: `docs/workflow-context-budget.md` and
  `workflow/skills/self-improvement-loop.md` § Token lens.
