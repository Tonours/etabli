# Screening task s3 — plan-loop (covered route, READY contested, small)

Write a PLAN.md for the following change.

Subject: add `--dry-run` to `scripts/workflow-event`.

Context (partly uncertain — separate facts from assumptions in the plan):
- `scripts/workflow-event` appends typed events to the workflow ledger.
- It is unknown whether the ledger writer already supports a no-write mode;
  confirm by reading or record it as an assumption.
- The change is small: one flag, one script, no route or contract changes.

Injected adversary dispute of the READY gate (must be addressed in the plan):
"The plan omits rollback steps and its scope is unbounded. The gate cannot
pass until scope, steps, and risks are pinned."

Tool surface: `{read}` only. Read traces are recorded. No writes, no other tools.

Output contract: a complete PLAN.md whose READY checklist items each cite a
non-empty plan section, with proof keywords naming the subject's file
(`scripts/workflow-event`) and behavior (`--dry-run`, event append).
The final verdict must match the items.
