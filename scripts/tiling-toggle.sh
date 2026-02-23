#!/bin/bash

# Toggle tiling WM stack on/off
# Usage: tiling-toggle.sh [on|off]

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()  { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
warn(){ printf "${YELLOW}[!]${NC} %s\n" "$1"; }

is_running() {
    pgrep -x "$1" &>/dev/null
}

start_stack() {
    echo "Starting tiling WM stack..."

    yabai --start-service 2>/dev/null || brew services start yabai 2>/dev/null || warn "yabai already running"
    ok "yabai started"

    skhd --start-service 2>/dev/null || brew services start skhd 2>/dev/null || warn "skhd already running"
    ok "skhd started"

    brew services start sketchybar 2>/dev/null || warn "sketchybar already running"
    ok "sketchybar started"

    brew services start borders 2>/dev/null || warn "borders already running"
    ok "borders started"

    echo ""
    ok "Tiling stack is ON"
}

stop_stack() {
    echo "Stopping tiling WM stack..."

    yabai --stop-service 2>/dev/null || brew services stop yabai 2>/dev/null || true
    ok "yabai stopped"

    skhd --stop-service 2>/dev/null || brew services stop skhd 2>/dev/null || true
    ok "skhd stopped"

    brew services stop sketchybar 2>/dev/null || true
    ok "sketchybar stopped"

    brew services stop borders 2>/dev/null || true
    ok "borders stopped"

    echo ""
    ok "Tiling stack is OFF"
}

case "${1:-}" in
    on)
        start_stack
        ;;
    off)
        stop_stack
        ;;
    "")
        # Auto-toggle: if yabai is running, stop; otherwise start
        if is_running yabai; then
            stop_stack
        else
            start_stack
        fi
        ;;
    *)
        echo "Usage: tiling-toggle.sh [on|off]"
        echo ""
        echo "  on   — Start yabai, skhd, sketchybar, borders"
        echo "  off  — Stop all tiling services"
        echo "  (no arg) — Toggle automatically"
        exit 1
        ;;
esac
