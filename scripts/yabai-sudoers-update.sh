#!/bin/bash

# Regenerate yabai sudoers entry after brew upgrade
# The hash changes on each yabai binary update

set -e

YABAI_BIN=$(which yabai)

if [ -z "$YABAI_BIN" ]; then
    echo "Error: yabai not found in PATH"
    exit 1
fi

HASH=$(shasum -a 256 "$YABAI_BIN" | cut -d' ' -f1)
ENTRY="$(whoami) ALL=(root) NOPASSWD: sha256:${HASH} ${YABAI_BIN} --load-sa"

echo "Updating yabai sudoers entry..."
echo "$ENTRY" | sudo tee /private/etc/sudoers.d/yabai >/dev/null

echo "Done. Entry written to /private/etc/sudoers.d/yabai"
echo "Hash: $HASH"
