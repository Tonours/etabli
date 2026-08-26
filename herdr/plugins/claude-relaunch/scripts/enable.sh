#!/usr/bin/env bash
# Action `enable`: install the watcher (launchd on macOS, cron elsewhere).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
install_watcher
log "watcher enabled"
echo "watcher enabled: $(watcher_status)"
notify "claude relaunch watcher enabled" "scans every 60s"
