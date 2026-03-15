#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 8)
CPU=$(sysctl -n vm.loadavg 2>/dev/null | awk -v cores="$CORES" '{gsub(/[{}]/, ""); print int(($1 / cores) * 100)}')

if [ "$CPU" -gt 80 ]; then
    COLOR="$RED"
elif [ "$CPU" -gt 50 ]; then
    COLOR="$YELLOW"
else
    COLOR="$ACCENT_COLOR"
fi

sketchybar --set "$NAME" icon="$ICON_CPU" icon.color="$COLOR"
