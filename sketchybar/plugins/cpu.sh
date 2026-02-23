#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

CPU=$(top -l 1 -n 0 | awk '/CPU usage/ {print int($3)}')

if [ "$CPU" -gt 80 ]; then
    COLOR="$RED"
elif [ "$CPU" -gt 50 ]; then
    COLOR="$YELLOW"
else
    COLOR="$TEXT"
fi

sketchybar --set "$NAME" icon="$ICON_CPU" icon.color="$COLOR"
