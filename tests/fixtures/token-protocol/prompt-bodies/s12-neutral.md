# Screening task s12 — neutral variant (extra plan-loop, pl-covered-style)

Write a PLAN.md for the following change.

Subject: add `--check` to `scripts/pointer-follow-verify`.

Context (partly uncertain — separate facts from assumptions in the plan):
- `scripts/pointer-follow-verify` validates pointer-follow events against
  the ledger and the run trace.
- It is unknown whether a read-only check mode already exists; confirm by
  reading or record it as an assumption.
- The change is small: one flag, one script, no route or contract changes.
- No reviewer disputes the READY gate.

Tool surface: `{read}` only. Read traces are recorded. No writes, no other tools.

Output contract: a complete PLAN.md whose READY checklist items each cite a
non-empty plan section, with proof keywords naming the subject's file
(`scripts/pointer-follow-verify`) and behavior (`--check`, verification).
The final verdict must match the items.
