# P3 Claude parity audit

## Verdict

Claude parity is `proxy_supported`.

Claude can execute the same workflow semantics through slash commands, hooks, and `/goal` guidance, but it does not expose the same Pi Task* state primitive in this repo.

## Accepted implementation guidance

- Add Claude hook route context for plan chains, completion evidence, capability labels, and `/goal` continuation.
- Keep Task* wording explicitly Pi-only on Claude surfaces.
- Add smoke coverage proving autonomous plan-loop routing, `/goal` slash command bypass, and no accidental TaskCreate/TaskList injection.
- Extend Pi/Claude alignment tests beyond route/write permission to include stop condition, evidence, and plan-chain metadata.

## Risk labels

- `confirmed`: repo hook scripts and fixtures pass smoke tests.
- `proxy_supported`: Claude can follow equivalent orchestration through `/goal`, commands, and hooks.
- `blocked`: no Claude Task* structured state guarantee was found.

## Rejected

- Do not emulate Pi Task* state in Claude docs or hooks.
- Do not make hooks a hidden execution loop; Claude long-running loops should stay in `/goal` or explicit commands.
