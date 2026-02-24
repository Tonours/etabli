#!/bin/bash

# macOS performance optimization — aggressive mode
# Usage: macos-optimize.sh [apply|daemon|reset]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { printf "${BLUE}[*]${NC} %s\n" "$1"; }
ok()  { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
warn(){ printf "${YELLOW}[!]${NC} %s\n" "$1"; }
err() { printf "${RED}[x]${NC} %s\n" "$1"; }

# ============================================================================
# ANIMATIONS OFF (defaults write)
# ============================================================================
disable_animations() {
    log "Disabling all macOS animations..."

    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    defaults write com.apple.dock autohide-time-modifier -float 0
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock launchanim -bool false
    defaults write com.apple.dock expose-animation-duration -float 0.001
    defaults write com.apple.dock springboard-show-duration -float 0
    defaults write com.apple.dock springboard-hide-duration -float 0
    defaults write com.apple.finder DisableAllAnimations -bool true
    sudo defaults write com.apple.universalaccess reduceMotion -bool true 2>/dev/null || true
    sudo defaults write com.apple.universalaccess reduceTransparency -bool true 2>/dev/null || true
    defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false

    ok "Animations disabled"
}

restore_animations() {
    log "Restoring macOS animations..."

    defaults delete NSGlobalDomain NSAutomaticWindowAnimationsEnabled 2>/dev/null || true
    defaults delete NSGlobalDomain NSWindowResizeTime 2>/dev/null || true
    defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
    defaults delete com.apple.dock autohide-delay 2>/dev/null || true
    defaults delete com.apple.dock launchanim 2>/dev/null || true
    defaults delete com.apple.dock expose-animation-duration 2>/dev/null || true
    defaults delete com.apple.dock springboard-show-duration 2>/dev/null || true
    defaults delete com.apple.dock springboard-hide-duration 2>/dev/null || true
    defaults delete com.apple.finder DisableAllAnimations 2>/dev/null || true
    sudo defaults delete com.apple.universalaccess reduceMotion 2>/dev/null || true
    sudo defaults delete com.apple.universalaccess reduceTransparency 2>/dev/null || true
    defaults delete NSGlobalDomain NSScrollAnimationEnabled 2>/dev/null || true

    ok "Animations restored to defaults"
}

# ============================================================================
# KEYBOARD REPEAT RATE (fast for vim users)
# ============================================================================
optimize_keyboard() {
    log "Optimizing keyboard repeat rate..."

    defaults write NSGlobalDomain KeyRepeat -int 1
    defaults write NSGlobalDomain InitialKeyRepeat -int 10
    defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

    ok "Keyboard repeat: fast (1/10), press-and-hold disabled"
}

restore_keyboard() {
    log "Restoring keyboard defaults..."

    defaults delete NSGlobalDomain KeyRepeat 2>/dev/null || true
    defaults delete NSGlobalDomain InitialKeyRepeat 2>/dev/null || true
    defaults delete NSGlobalDomain ApplePressAndHoldEnabled 2>/dev/null || true

    ok "Keyboard restored to defaults"
}

# ============================================================================
# DOCK CLEANUP (use Sol launcher instead)
# ============================================================================
clean_dock() {
    log "Cleaning Dock (pinned apps removed)..."

    defaults write com.apple.dock persistent-apps -array

    ok "Dock cleaned — use Sol for app launching"
}

# ============================================================================
# SYSTEM SERVICES
# ============================================================================
disable_services() {
    log "Disabling background services..."

    local services=(
        com.apple.photoanalysisd
        com.apple.suggestd
        com.apple.knowledge-agent
        com.apple.ReportCrash
        com.apple.accessibility.MotionTrackingAgent
    )

    for svc in "${services[@]}"; do
        if launchctl list "$svc" &>/dev/null; then
            launchctl disable "gui/$(id -u)/$svc" 2>/dev/null && ok "Disabled $svc" || warn "Could not disable $svc"
        fi
    done
}

restore_services() {
    log "Re-enabling background services..."

    local services=(
        com.apple.photoanalysisd
        com.apple.suggestd
        com.apple.knowledge-agent
        com.apple.ReportCrash
        com.apple.accessibility.MotionTrackingAgent
    )

    for svc in "${services[@]}"; do
        launchctl enable "gui/$(id -u)/$svc" 2>/dev/null && ok "Enabled $svc" || true
    done
}

# ============================================================================
# SPOTLIGHT / INDEXING
# ============================================================================
disable_indexing() {
    log "Disabling Spotlight indexing..."
    sudo mdutil -a -i off &>/dev/null && ok "Spotlight indexing off" || warn "Could not disable Spotlight"

    log "Disabling Time Machine local snapshots..."
    sudo tmutil disablelocal 2>/dev/null || true
    ok "Time Machine local snapshots off"
}

restore_indexing() {
    log "Re-enabling Spotlight indexing..."
    sudo mdutil -a -i on &>/dev/null && ok "Spotlight indexing on" || true
}

# ============================================================================
# RAM CLEANUP
# ============================================================================
cleanup_ram() {
    log "Cleaning up RAM..."

    # Purge inactive memory
    sudo purge 2>/dev/null && ok "Memory purged" || warn "purge requires sudo"

    # Quit known RAM hogs if not in foreground
    local apps=("Music" "Photos" "Maps" "News" "Stocks" "TV" "Podcasts" "Home")
    local frontmost
    frontmost=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || echo "")

    for app in "${apps[@]}"; do
        if pgrep -x "$app" &>/dev/null && [ "$app" != "$frontmost" ]; then
            osascript -e "tell application \"$app\" to quit" 2>/dev/null && ok "Quit $app" || true
        fi
    done
}

# ============================================================================
# DAEMON MODE (loop every 5 min)
# ============================================================================
run_daemon() {
    log "Starting optimization daemon (Ctrl+C to stop)..."
    while true; do
        cleanup_ram
        sleep 300
    done
}

# ============================================================================
# MAIN
# ============================================================================
case "${1:-apply}" in
    apply)
        echo ""
        echo "  macOS Performance Optimization (one-shot)"
        echo "  =========================================="
        echo ""
        disable_animations
        optimize_keyboard
        clean_dock
        disable_services
        disable_indexing
        cleanup_ram
        # Restart Dock and Finder to apply animation changes
        killall Dock 2>/dev/null || true
        killall Finder 2>/dev/null || true
        echo ""
        ok "All optimizations applied. Dock and Finder restarted."
        echo ""
        ;;
    daemon)
        run_daemon
        ;;
    reset)
        echo ""
        echo "  macOS Performance Reset"
        echo "  ========================"
        echo ""
        restore_animations
        restore_keyboard
        restore_services
        restore_indexing
        killall Dock 2>/dev/null || true
        killall Finder 2>/dev/null || true
        echo ""
        ok "All settings restored to defaults. Dock and Finder restarted."
        echo ""
        ;;
    *)
        echo "Usage: macos-optimize.sh [apply|daemon|reset]"
        echo ""
        echo "  apply   — One-shot: disable animations, services, clean RAM"
        echo "  daemon  — Loop: clean RAM every 5 minutes"
        echo "  reset   — Restore all settings to macOS defaults"
        exit 1
        ;;
esac
