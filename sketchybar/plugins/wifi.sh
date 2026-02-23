#!/bin/bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

WIFI_SSID=$(ipconfig getsummary en0 2>/dev/null | awk -F ' SSID : ' '/ SSID : / {print $2}')

if [ -n "$WIFI_SSID" ]; then
    ICON="$ICON_WIFI"
    COLOR="$TEXT"
else
    ICON="$ICON_WIFI_OFF"
    COLOR="$OVERLAY0"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR"
