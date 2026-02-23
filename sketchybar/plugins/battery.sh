#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -Eo '\d+%' | head -1 | tr -d '%')
CHARGING=$(echo "$BATTERY_INFO" | grep -c 'AC Power')

if [ "$CHARGING" -gt 0 ]; then
    ICON="$ICON_BATTERY_CHARGING"
    COLOR="$GREEN"
elif [ "$PERCENTAGE" -gt 75 ]; then
    ICON="$ICON_BATTERY_100"
    COLOR="$TEXT"
elif [ "$PERCENTAGE" -gt 50 ]; then
    ICON="$ICON_BATTERY_75"
    COLOR="$TEXT"
elif [ "$PERCENTAGE" -gt 25 ]; then
    ICON="$ICON_BATTERY_50"
    COLOR="$YELLOW"
elif [ "$PERCENTAGE" -gt 10 ]; then
    ICON="$ICON_BATTERY_25"
    COLOR="$PEACH"
else
    ICON="$ICON_BATTERY_0"
    COLOR="$RED"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR"
