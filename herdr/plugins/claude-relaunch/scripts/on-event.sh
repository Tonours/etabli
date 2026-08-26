#!/usr/bin/env bash
# Event hook: pane.agent_status_changed. Cheap targeted probe — exits without
# touching state unless the changed pane hosts a limited claude agent.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

payload="${HERDR_PLUGIN_EVENT_JSON:-}"
[[ -n "$payload" ]] || exit 0
pane="$(printf '%s' "$payload" | grep -o '"pane_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
[[ -n "$pane" ]] || exit 0
agent_alive_claude "$pane" || exit 0

with_lock scan_pane "$pane" "" ""
exit 0
