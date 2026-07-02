# P3 Claude parity

## Owner

Main agent with subagent audit input.

## Status

Completed.

## Scope

Make Claude execute the same workflow semantics through the mechanisms available in this repo: commands, hooks, shared docs, smoke fixtures, and `/goal` guidance.

## Integration Criteria

- Route context mentions Claude runtime loop and `/goal`.
- Route context explicitly says Task* tools are Pi-only.
- Autonomous plan-loop smoke coverage proves no accidental TaskCreate/TaskList injection.
- Pi/Claude alignment tests include route metadata, not just route names.
