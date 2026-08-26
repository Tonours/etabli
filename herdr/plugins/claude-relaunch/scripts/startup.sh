#!/usr/bin/env bash
# Startup hook: restore the watcher when the user enabled it but the
# LaunchAgent/cron entry is gone (e.g. after a macOS upgrade).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
mkdir -p "$STATE_DIR"

if [[ -e "$ENABLED_FILE" ]]; then
  running="$(watcher_status)"
  if [[ "$running" == "off" || "$running" == *"unknown"* ]]; then
    install_watcher && log "startup re-armed watcher"
  fi
fi
exit 0
