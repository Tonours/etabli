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

## Maintenance and dependency upgrades

Build the goal from a fresh local baseline and versioned primary release notes,
changelogs, migration guides, security advisories, and package-manager output.
Separate direct dependencies from transitive dependencies and routine upgrades
from security fixes. Name required migrations, compatibility constraints,
rollback boundaries, focused checks, the full relevant suite, and a final
review/simplification pass. Cap batches or attempts and stop on an unresolved
breaking migration, missing primary documentation, secret/production boundary,
or repeated no-progress.

Never promise that everything will be perfectly current or safe. Completion is
the verified target set plus explicitly classified deferred, blocked, unknown,
or transitive items.

Pattern:

```md
/goal Bring <bounded dependency or maintenance surface> to the verified target
versions from <local baseline and versioned primary sources>. Separate direct,
transitive, security, migration, and deferred items; preserve <compatibility and
production constraints>. Apply at most <batch/attempt cap>, run <focused checks>
after each batch and <full relevant suite> plus review/simplification at the end.
Do not <forbidden writes or risky actions>. Stop with evidence, rollback state,
blocker, uncertainty, and the next required input if a safe migration cannot be
proved.
```

Example:

```md
/goal Reduce p95 checkout latency below 120 ms, verified by the checkout
benchmark while correctness tests stay green. Use only checkout code and
fixtures. Stop after 5 experiments or 90 minutes. Record each measurement; if
blocked, report attempts, evidence, uncertainty, and the input needed.
```
