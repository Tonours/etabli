#!/usr/bin/env bash
# Action `crons`: open the manager popup (manifest placement = popup).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! "$HERDR_BIN" plugin pane open --plugin etabli.claude-relaunch --entrypoint manager >/dev/null 2>&1; then
  echo "claude-relaunch: could not open the manager pane (is a herdr client attached?)" >&2
  exit 1
fi
