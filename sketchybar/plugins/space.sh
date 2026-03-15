#!/bin/bash

source "$CONFIG_DIR/colors.sh"

if [ "$SELECTED" = "true" ]; then
    sketchybar --set "$NAME" \
        label.color="$ACCENT_COLOR" \
        background.color="$SURFACE0" \
        background.border_width=1 \
        background.border_color="$ACCENT_COLOR"
else
    sketchybar --set "$NAME" \
        label.color="$OVERLAY0" \
        background.color="$CRUST" \
        background.border_width=0
fi
