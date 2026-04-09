# Pi Extensions - Etabli Workflow

This directory contains custom Pi extensions for the etabli workflow.

## Default profile

The default Pi profile is intentionally minimal and centered on planning, review, and safe shell execution.

- `fast-handoff.ts` - instant local handoff generation
- `review-plan-bridge.ts` - turn review findings into tasks or plan slices
- `scope-guard.ts` - warn when work drifts outside the current plan
- `health-check.ts` - check core workflow wiring and RTK status
- `rtk.ts` - rewrite safe bash commands through RTK to reduce shell noise and token usage
- `subagent.ts` - automate scout/reviewer/worker flows behind `/plan-loop` and `/plan-implement`
- `tilldone.ts` - persistent task list and task gating for implementation work
- `tilldone-ops-sync.ts` - sync TillDone state into the shared OPS snapshot
- `plan-state.ts` - lightweight PLAN.md tracking helper used by worker subagents
- `damage-control.ts` - pre-execution safety gate used by subagents
- `filter-output.ts` - post-execution redaction used by subagents
- `block-google-providers.ts` - provider guardrail used by subagents

## Optional extensions

No optional Pi extension surface is kept in the repo anymore. The workflow surface is intentionally small.

## Installation

Extensions are registered from `pi/agent/settings.json`.
After pulling updates, reload Pi:

```bash
pi /reload
```

## Testing

```bash
cd pi

# Full extension suite
bun test ./extensions/__tests__/*.test.ts

# Focused workflow suite
bun run test:workflow

# Focused workflow suite with coverage output
bun run test:workflow-coverage
```

## Notes

- `test:workflow-coverage` is the focused coverage pass for the net-new workflow extension surface.
- Full repo coverage is still broader than this slice because legacy extensions are loaded in the same workspace.

## Configuration

Set optional environment variables in your shell:

```bash
export PI_AUTO_HANDOFF=1
```
