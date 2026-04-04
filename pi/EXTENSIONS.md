# Pi Extensions - Etabli Workflow

This directory contains custom Pi extensions for the etabli workflow.

## Extensions

### Core workflow
- `fast-handoff.ts` - instant local handoff generation
- `tilldone-ops-sync.ts` - sync TillDone state into shared OPS files
- `review-plan-bridge.ts` - turn review findings into tasks or plan slices
- `auto-resume.ts` - detect fresh handoff files and suggest a resume path

### Quality and safety
- `auto-validate.ts` - run workflow checks for plan, git, conflicts, build, and large files
- `scope-guard.ts` - warn when work drifts outside the current plan
- `pre-flight.ts` - create snapshots before risky writes or shell commands
- `error-recovery.ts` - classify common failures and suggest the next safe move
- `health-check.ts` - check extension wiring, OPS files, Neovim, and Claude commands

### Productivity
- `workflow-metrics.ts` - track time spent by phase and tool usage
- `project-switcher.ts` - keep a recent/favorite project list and switch hints
- `task-templates.ts` - ready-made task lists for common workflows
- `smart-context.ts` - learn local patterns and suggest likely next tools
- `context-help.ts` - contextual help for planning, implementation, review, and handoff

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
export PI_AUTO_VALIDATE=1
```
