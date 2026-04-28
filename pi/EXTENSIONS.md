# Pi Extensions - Etabli Workflow

This directory contains the tiny Pi extension surface kept in `etabli`.

## Default profile

The default Pi profile is intentionally small.

- `rtk.ts` - rewrite safe bash commands through RTK to reduce shell noise and token usage
- `filter-output.ts` - post-execution secret redaction for tool output
- `block-google-providers.ts` - provider guardrail for local policy
- damage-control is intentionally not enabled by default.

## Optional extensions

No broader workflow extension surface is kept in the repo anymore.

## Installation

Extensions are registered from `pi/agent/settings.json`.
After pulling updates, reload Pi:

```bash
pi /reload
```

## Testing

```bash
cd pi

# Extension suite
bun test ./extensions/__tests__/*.test.ts

# Focused workflow suite
bun run test:workflow

# Focused workflow suite with coverage output
bun run test:workflow-coverage
```

## Notes

- `test:workflow-coverage` now targets the small maintained core only.
