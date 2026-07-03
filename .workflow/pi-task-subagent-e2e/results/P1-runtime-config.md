# P1 runtime config result

## Status

Accepted.

## Evidence

- `pi/agent/settings.json` now includes `npm:@tintinweb/pi-subagents` before `npm:@tintinweb/pi-tasks`.
- `scripts/install.sh` treats `npm:@tintinweb/pi-subagents` as a managed source when syncing live Pi agent settings.
- `tests/workflow-docs-smoke.sh` asserts both the tracked setting and installer sync entry.
- `pi/extensions/__tests__/settings-consistency.test.ts` asserts the curated package surface includes the scoped provider.

## Remaining Risk

The live machine must still install or sync the package; this run installed it with `pi install`.
