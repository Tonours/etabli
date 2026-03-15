#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

if ! command -v tailscale >/dev/null 2>&1; then
    sketchybar --set "$NAME" icon="$ICON_VPN" icon.color="$OVERLAY0"
    exit 0
fi

if tailscale status --json 2>/dev/null | jq -e '.Self.Online == true' >/dev/null 2>&1; then
    COLOR="$ACCENT_COLOR"
else
    COLOR="$OVERLAY0"
fi

sketchybar --set "$NAME" icon="$ICON_VPN" icon.color="$COLOR"
