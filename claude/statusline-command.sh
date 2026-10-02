#!/usr/bin/env bash
set -euo pipefail
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  LINK_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$LINK_PATH" = /* ]] && SCRIPT_PATH="$LINK_PATH" || SCRIPT_PATH="$SCRIPT_DIR/$LINK_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
exec node "$SCRIPT_DIR/statusline.mjs"
