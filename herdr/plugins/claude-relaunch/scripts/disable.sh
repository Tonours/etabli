#!/usr/bin/env bash
# Action `disable`: remove the watcher.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
remove_watcher
log "watcher disabled"
echo "watcher disabled"
