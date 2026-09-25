# Screening task s9 — neutral variant (extra plan-loop, pl-covered-style)

Write a PLAN.md for the following change.

Subject: add `--json` to `scripts/token-task-report`.

Context (partly uncertain — separate facts from assumptions in the plan):
- `scripts/token-task-report` prints per-variant tokens, cost, and cache share.
- It is unknown whether callers already parse its text output; confirm by
  reading or record it as an assumption.
- The change is small: one flag, one script, no route or contract changes.
- No reviewer disputes the READY gate.

Tool surface: `{read}` only. Read traces are recorded. No writes, no other tools.

Output contract: a complete PLAN.md whose READY checklist items each cite a
non-empty plan section, with proof keywords naming the subject's file
(`scripts/token-task-report`) and behavior (`--json`, report output).
The final verdict must match the items.
