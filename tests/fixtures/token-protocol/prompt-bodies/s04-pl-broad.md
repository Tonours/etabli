# Screening task s4 — plan-loop (broad/risky)

Write a PLAN.md for the following change.

Subject: migrate the ledger to SQLite.

Context (partly uncertain — separate facts from assumptions in the plan):
- The workflow ledger is currently file-based (JSONL events).
- Current ledger size, reader set, and concurrency needs are unknown; confirm
  by reading or record them as assumptions.
- This is broad/risky work: the plan MUST state non-goals and MUST name the
  files/areas it touches.

Tool surface: `{read}` only. Read traces are recorded. No writes, no other tools.

Output contract: a complete PLAN.md whose READY checklist items each cite a
non-empty plan section, with proof keywords naming the subject (ledger,
SQLite, migration), including explicit non-goals and named files/areas.
The final verdict must match the items.
