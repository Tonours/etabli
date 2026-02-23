#!/bin/bash

source "$CONFIG_DIR/colors.sh"

if [ "$SELECTED" = "true" ]; then
    sketchybar --set "$NAME" \
        label.color="$TEXT" \
        background.color="$SURFACE0"
else
    sketchybar --set "$NAME" \
        label.color="$OVERLAY0" \
        background.color="$MANTLE"
fi
