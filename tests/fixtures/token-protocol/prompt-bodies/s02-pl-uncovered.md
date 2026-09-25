# Screening task s2 — plan-loop (uncovered route, small)

Write a PLAN.md for the following change.

Subject: add a `teleport` route to the router.

Context (partly uncertain — separate facts from assumptions in the plan):
- The router dispatches named routes to handlers; `teleport` does not exist yet.
- The route is absent from the quick-card, so the full contract must be
  consulted for route/role requirements.
- The exact handler interface and registration file are unknown; confirm by
  reading or record them as assumptions.

Tool surface: `{read}` only. Read traces are recorded. No writes, no other tools.

Output contract: a complete PLAN.md whose READY checklist items each cite a
non-empty plan section, with proof keywords naming the subject (`teleport`,
router, route registration). The final verdict must match the items.
