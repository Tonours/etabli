#!/usr/bin/env bash

set -euo pipefail

SPACE_LIMIT="${SPACE_LIMIT:-5}"

log() {
    printf "yabai-space-local: %s\n" "$*" >&2
}

die() {
    log "$*"
    exit 1
}

require_bin() {
    command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

query_display() {
    if [ $# -eq 0 ]; then
        yabai -m query --displays --display
    else
        yabai -m query --displays --display "$1"
    fi
}

focused_display() {
    query_display | jq -r '.index'
}

focused_space() {
    yabai -m query --spaces --space | jq -r '.index'
}

display_spaces() {
    local display="$1"
    query_display "$display" | jq -r '.spaces[]'
}

space_for_slot() {
    local display="$1"
    local slot="$2"

    query_display "$display" | jq -r --argjson slot "$slot" '.spaces[$slot - 1] // empty'
}

space_count() {
    local display="$1"

    query_display "$display" | jq '.spaces | length'
}

ensure_display_spaces() {
    local display="$1"
    local count attempts

    count="$(space_count "$display")"
    attempts=0

    while [ "$count" -lt "$SPACE_LIMIT" ]; do
        yabai -m space --create "$display" >/dev/null
        sleep 0.2
        count="$(space_count "$display")"
        attempts=$((attempts + 1))

        if [ "$attempts" -gt $((SPACE_LIMIT * 3)) ]; then
            die "could not create enough spaces on display $display"
        fi
    done
}

focus_slot() {
    local slot="$1"
    local display="${2:-$(focused_display)}"
    local space

    [ "$slot" -ge 1 ] && [ "$slot" -le "$SPACE_LIMIT" ] || die "slot must be between 1 and $SPACE_LIMIT"

    ensure_display_spaces "$display"
    space="$(space_for_slot "$display" "$slot")"
    [ -n "$space" ] || die "no space for slot $slot on display $display"

    yabai -m space --focus "$space"
}

move_to_slot() {
    local slot="$1"
    local display="${2:-$(focused_display)}"
    local space

    [ "$slot" -ge 1 ] && [ "$slot" -le "$SPACE_LIMIT" ] || die "slot must be between 1 and $SPACE_LIMIT"

    ensure_display_spaces "$display"
    space="$(space_for_slot "$display" "$slot")"
    [ -n "$space" ] || die "no space for slot $slot on display $display"

    yabai -m window --space "$space"
    yabai -m space --focus "$space"
}

cycle_slots() {
    local direction="$1"
    local display current_space current_index next_index
    local -a spaces

    display="$(focused_display)"
    ensure_display_spaces "$display"

    while IFS= read -r space; do
        spaces+=("$space")
    done < <(query_display "$display" | jq -r --argjson limit "$SPACE_LIMIT" '.spaces[:$limit][]')

    [ "${#spaces[@]}" -gt 0 ] || die "no spaces found on display $display"

    current_space="$(focused_space)"
    current_index=0

    for i in "${!spaces[@]}"; do
        if [ "${spaces[$i]}" = "$current_space" ]; then
            current_index="$i"
            break
        fi
    done

    case "$direction" in
        next)
            next_index=$(((current_index + 1) % ${#spaces[@]}))
            ;;
        prev)
            next_index=$(((current_index - 1 + ${#spaces[@]}) % ${#spaces[@]}))
            ;;
        *)
            die "cycle direction must be next or prev"
            ;;
    esac

    yabai -m space --focus "${spaces[$next_index]}"
}

ensure_limit() {
    local display space windows
    local -a displays extras

    while IFS= read -r display; do
        displays+=("$display")
    done < <(yabai -m query --displays | jq -r '.[].index')

    [ "${#displays[@]}" -gt 0 ] || die "no displays detected"

    for display in "${displays[@]}"; do
        ensure_display_spaces "$display"
        extras=()

        while IFS= read -r space; do
            extras+=("$space")
        done < <(query_display "$display" | jq -r --argjson limit "$SPACE_LIMIT" '.spaces[$limit:][]?')

        if [ "${#extras[@]}" -eq 0 ]; then
            continue
        fi

        for ((i=${#extras[@]} - 1; i>=0; i--)); do
            space="${extras[$i]}"
            windows="$(yabai -m query --spaces --space "$space" | jq '.windows | length')"

            if [ "$windows" -eq 0 ]; then
                yabai -m space --destroy "$space" >/dev/null || log "could not destroy empty extra space $space on display $display"
                sleep 0.1
            else
                log "keeping non-empty extra space $space on display $display"
            fi
        done
    done
}

status() {
    yabai -m query --displays | jq --argjson limit "$SPACE_LIMIT" '
        map({
            display: .index,
            local_spaces: .spaces[:$limit],
            extra_spaces: .spaces[$limit:]
        })
    '
}

require_bin yabai
require_bin jq

case "${1:-status}" in
    focus)
        [ $# -ge 2 ] || die "usage: yabai-space-local.sh focus <slot> [display]"
        focus_slot "$2" "${3:-}"
        ;;
    move)
        [ $# -ge 2 ] || die "usage: yabai-space-local.sh move <slot> [display]"
        move_to_slot "$2" "${3:-}"
        ;;
    cycle)
        [ $# -ge 2 ] || die "usage: yabai-space-local.sh cycle <next|prev>"
        cycle_slots "$2"
        ;;
    ensure)
        ensure_limit
        ;;
    status)
        status
        ;;
    *)
        die "usage: yabai-space-local.sh [focus|move|cycle|ensure|status]"
        ;;
esac
