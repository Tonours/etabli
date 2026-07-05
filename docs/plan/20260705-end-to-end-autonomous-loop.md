# End-to-end autonomous loop (2026-07-05)

## What

Closed the remaining gaps between the etabli autonomous chain and the
research-backed full loop (Boris Cherny threads and interviews, Claude Code
official best practices): understand, plan, code with tests, verify,
simplify, dual review, CI.

## Changes

- `workflow/skills/adversary.md`: Code diff mode — cross-model read-only
  adversarial review of the implementation diff, same gate as the plan mode;
  autonomous run without a cross-model runner stops `blocked`.
- `workflow/skills/implementation-loop.md`: step 0 Understand (scoped recon
  via subagent scouts, sourced findings, lean main context); tests ship with
  code behavior changes (failing test first for bug fixes); simplification
  pass after green checks; code-diff adversary after the fresh-context
  review; completion evidence extended.
- `workflow/spec.md`: tests-with-change rule; reviewer scope (correctness or
  stated requirements only — style and speculative robustness never block);
  finish-or-hand-off migrations; golden principles extended (third occurrence
  of the same review finding becomes a mechanical check).
- `workflow/skills/ship.md` + `claude/commands/plan-implement.md`: phase
  lists synced (understand → plan → plan adversary → implement with tests →
  checks → simplify → fresh review → code adversary → archive).
- `tests/workflow-docs-smoke.sh`: pins; multi-line pin replaced by
  single-line pins (grep -F treats a multi-line pattern as an OR list — the
  code-diff adversary caught this, the fresh-context reviewer had validated
  it wrongly).

## Dogfood result

The run itself exercised both new passes: fresh-context review returned GO;
the cross-model code-diff adversary returned BLOCK with one real finding
(the grep -F pin weakness) and two findings refuted with evidence
(`blocked: no validation surface` already exists at the human-checkpoints
table; ledger is local and gitignored by contract). Cross-model catch of a
same-family blind spot — exactly the case the mode exists for.

## Sources

- code.claude.com/docs/en/best-practices (explore-plan-code, failing test
  first, reviewer scoped to correctness, second-opinion verification)
- howborisusesclaudecode.com + bcherny threads (verify as rule #1,
  code-simplifier, plan quality one-shots implementation)
- pragmaticengineer.com Cherny interview (finish migrations, repeated review
  findings become lint rules)

## Validation

workflow-docs-smoke, workflow-scaffold-smoke, claude-hooks-smoke: pass.
Ledger: .workflow/e2e-loop/events.jsonl.
