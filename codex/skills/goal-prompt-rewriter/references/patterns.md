# Goal Prompt Patterns

All patterns name a verifiable end state, cap, preserved constraints, evidence
record, and blocked stop report.

- Bug: make the reproduction pass, then run adjacent regression checks.
- Performance: reduce a named metric below a threshold while correctness stays green.
- Migration/refactor: finish a bounded surface while preserving API/behavior.
- Research/audit: deliver an evidence map with confirmed, proxy, blocked, and unknown claims.
- Documentation: produce a named artifact checked against its source of truth.
- Recurring: `/loop <interval> <watch target>` with an idempotent bounded action
  and no-op when state did not change.

Example:

```md
/goal Reduce p95 checkout latency below 120 ms, verified by the checkout
benchmark while correctness tests stay green. Use only checkout code and
fixtures. Stop after 5 experiments or 90 minutes. Record each measurement; if
blocked, report attempts, evidence, uncertainty, and the input needed.
```
