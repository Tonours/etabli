# Orchestration: ADR golden fixtures and dry-run

## Local critical path
- Add fixture-driven validator coverage first, then change implementation only
  when a desired behavior needs code support.
- Keep dry-run deterministic and read-only; test that no files appear or change.
- Improve messages at the boundary where users act: wrapper failures, preflight
  integrity failures, invalid draft input, and missing supersession targets.

## Delegation decision
No subagent is used. The work is tightly coupled across one helper, one shared
validator, and their shell tests, so delegation would add synchronization
overhead without reducing risk.

## Stop rules
- Stop if a change requires a broader ADR framework or a dependency.
- Stop if exact golden output would become unstable because of timestamps,
  temp paths, or environment-specific text.
- Stop before `claude -p` unless the agent procedure or skill instructions are
  modified.
