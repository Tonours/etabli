# P1 task state

## Owner

Main agent.

## Status

Completed.

## Scope

Harden Pi `tasks-till-done` so it can prefer structured task details when available and fall back to `TaskList` text with an explicit lower-confidence label.

## Integration Criteria

- Structured state is labeled `confirmed`.
- Text fallback is labeled `proxy_supported`.
- Implementation completion requires validation, adversary, review, archive, and cleanup evidence where the autonomous workflow asks for it.
- Focused Bun tests pass.
