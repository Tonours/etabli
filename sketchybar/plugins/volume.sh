#!/bin/bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

VOLUME=$(osascript -e 'output volume of (get volume settings)')
MUTED=$(osascript -e 'output muted of (get volume settings)')

if [ "$MUTED" = "true" ] || [ "$VOLUME" -eq 0 ]; then
    ICON="$ICON_VOLUME_MUTE"
    COLOR="$OVERLAY0"
elif [ "$VOLUME" -gt 66 ]; then
    ICON="$ICON_VOLUME_HIGH"
    COLOR="$TEXT"
elif [ "$VOLUME" -gt 33 ]; then
    ICON="$ICON_VOLUME_MID"
    COLOR="$TEXT"
else
    ICON="$ICON_VOLUME_LOW"
    COLOR="$SUBTEXT0"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR"
