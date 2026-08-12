---
name: recurring-run
description: Execute one bounded, evidence-backed iteration of a recurring audit, report, maintenance task, monitor, checkpoint, or collection job. Use when a scheduled or repeated run must read prior run memory, compute a current delta, remain idempotent, report a verified no-op when nothing changed, update memory safely, and preserve normal permission boundaries.
---

# Recurring Run

Read `workflow/skills/recurring-run.md` completely and use it as the canonical
contract. Runtime-specific scheduling syntax must not weaken it.

## Run

1. Resolve the objective, source of truth, cadence, stable run key, scope,
   verifier, cap, permissions, and prior-run memory.
2. Read prior memory first, then verify current state independently.
3. Compute the delta. If nothing relevant changed, validate and return a real
   `no_op` without repeating writes.
4. Execute changed-state actions once per run key and only within explicit
   authority.
5. Validate the final state, update memory after validation, and report the
   compact result schema from the shared contract.

Never treat missing history as healthy state, rerun an already-applied side
effect, or grant a recurring job broader permissions than an interactive run.
