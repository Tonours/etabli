#!/usr/bin/env bash
# Bounded obvault context pack in the active pane cwd.
set -euo pipefail
exec node "$(dirname "$0")/obvault.mjs" session
