# P1 runtime config packet

## Objective

Add the exact Pi subagent provider required by `@tintinweb/pi-tasks` and keep tracked settings, installer sync, and smoke checks aligned.

## Expected Output

- Tracked `pi/agent/settings.json` includes `npm:@tintinweb/pi-subagents`.
- `scripts/install.sh` syncs that managed source into live Pi settings.
- Smoke tests fail if `pi-tasks` is present without the scoped subagent provider.

## Acceptance

- The repo distinguishes scoped `@tintinweb/pi-subagents` from unscoped `pi-subagents`.
- No unrelated Pi package surface is expanded.
