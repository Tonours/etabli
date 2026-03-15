#!/bin/bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

CACHE_FILE="${TMPDIR:-/tmp}/etabli-wifi-interface"

if [ ! -s "$CACHE_FILE" ]; then
    networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2; exit}' >"$CACHE_FILE"
fi

WIFI_IF=$(cat "$CACHE_FILE" 2>/dev/null)
WIFI_SSID=$(networksetup -getairportnetwork "${WIFI_IF:-en0}" 2>/dev/null | sed 's/^Current Wi-Fi Network: //')

if [ -n "$WIFI_SSID" ] && [ "$WIFI_SSID" != "You are not associated with an AirPort network." ]; then
    ICON="$ICON_WIFI"
    COLOR="$ACCENT_COLOR"
else
    ICON="$ICON_WIFI_OFF"
    COLOR="$OVERLAY0"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR"
