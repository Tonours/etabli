Packet ID: P4
Objective: Verify implementation and record residual risk.
Context: The manual ADR e2e test has API/cost dependencies and should not be
run as a default smoke check.
Files / sources: Tests, validator output, workflow report.
Ownership: Verification notes.
Do: Run deterministic local checks and document skipped expensive checks.
Do not: Treat skipped e2e as green.
Expected output: `final-report.md`.
Verification: `verify_workflow.py` passes.
