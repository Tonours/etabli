# Durable S3 qualification

ADR-0046 requires that durable runs keep every plan in an SQLite `EtabliPlanDoc` instead of `PLAN.md`, that a plan reaching `READY` switches the active role from planner to implementer, that independent eligible reviews precede publication, and that the daemon never merges a pull request: it stops after push, PR creation and notification. This paragraph describes that accepted contract only; it makes no claim that this checkout ships the S3 runtime, which is external to this checkout.
