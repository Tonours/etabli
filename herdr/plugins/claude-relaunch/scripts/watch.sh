#!/usr/bin/env bash
# LaunchAgent/cron tick: fire due relaunches, then scan for newly limited
# claude sessions. Runs outside the herdr plugin runtime (launchd context):
# resolve everything from this script's own location.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
with_lock fire_due
with_lock scan_all >/dev/null
