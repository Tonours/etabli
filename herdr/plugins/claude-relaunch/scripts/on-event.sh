#!/usr/bin/env bash
# Event hook: pane.agent_status_changed. Exits early unless the changed pane
# hosts a live claude agent, then runs a full scan_all to refresh state.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

payload="${HERDR_PLUGIN_EVENT_JSON:-}"
[[ -n "$payload" ]] || exit 0
pane="$(printf '%s' "$payload" | grep -o '"pane_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
[[ -n "$pane" ]] || exit 0
agent_alive_claude "$pane" || exit 0

with_lock scan_all >/dev/null
exit 0
