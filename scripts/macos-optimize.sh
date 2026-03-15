#!/bin/bash

# macOS responsiveness tuning for a tiling-focused setup.
# Usage: macos-optimize.sh [apply|reset|trim|indexing-off|indexing-on|daemon]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { printf "${BLUE}[*]${NC} %s\n" "$1"; }
ok()  { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
warn(){ printf "${YELLOW}[!]${NC} %s\n" "$1"; }
err() { printf "${RED}[x]${NC} %s\n" "$1"; }

restart_ui_services() {
    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true
}

# ============================================================================
# UI ANIMATIONS
# ============================================================================
disable_animations() {
    log "Disabling costly macOS animations..."

    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    defaults write NSGlobalDomain NSViewAnimationDuration -float 0
    defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false
    defaults write NSGlobalDomain NSToolbarFullScreenAnimationDuration -float 0
    defaults write NSGlobalDomain QLPanelAnimationDuration -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock launchanim -bool false
    defaults write com.apple.dock expose-animation-duration -float 0
    defaults write com.apple.dock springboard-show-duration -float 0
    defaults write com.apple.dock springboard-hide-duration -float 0
    defaults write com.apple.dock springboard-page-duration -float 0
    defaults write com.apple.dock workspaces-swoosh-animation-off -bool true
    defaults write com.apple.dock mineffect -string scale
    defaults write com.apple.dock minimize-to-application -bool true
    defaults write com.apple.finder DisableAllAnimations -bool true
    defaults write com.apple.universalaccess reduceMotion -bool true
    defaults write com.apple.universalaccess reduceTransparency -bool true

    ok "Animations reduced to the minimum practical level"
}

restore_animations() {
    log "Restoring animation defaults..."

    defaults delete NSGlobalDomain NSAutomaticWindowAnimationsEnabled 2>/dev/null || true
    defaults delete NSGlobalDomain NSWindowResizeTime 2>/dev/null || true
    defaults delete NSGlobalDomain NSViewAnimationDuration 2>/dev/null || true
    defaults delete NSGlobalDomain NSScrollAnimationEnabled 2>/dev/null || true
    defaults delete NSGlobalDomain NSToolbarFullScreenAnimationDuration 2>/dev/null || true
    defaults delete NSGlobalDomain QLPanelAnimationDuration 2>/dev/null || true
    defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
    defaults delete com.apple.dock autohide-delay 2>/dev/null || true
    defaults delete com.apple.dock launchanim 2>/dev/null || true
    defaults delete com.apple.dock expose-animation-duration 2>/dev/null || true
    defaults delete com.apple.dock springboard-show-duration 2>/dev/null || true
    defaults delete com.apple.dock springboard-hide-duration 2>/dev/null || true
    defaults delete com.apple.dock springboard-page-duration 2>/dev/null || true
    defaults delete com.apple.dock workspaces-swoosh-animation-off 2>/dev/null || true
    defaults delete com.apple.dock mineffect 2>/dev/null || true
    defaults delete com.apple.dock minimize-to-application 2>/dev/null || true
    defaults delete com.apple.finder DisableAllAnimations 2>/dev/null || true
    defaults delete com.apple.universalaccess reduceMotion 2>/dev/null || true
    defaults delete com.apple.universalaccess reduceTransparency 2>/dev/null || true

    ok "Animations restored"
}

# ============================================================================
# KEYBOARD
# ============================================================================
optimize_keyboard() {
    log "Setting fast keyboard repeat..."

    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15
    defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

    ok "Keyboard tuned for vim-style navigation"
}

restore_keyboard() {
    log "Restoring keyboard defaults..."

    defaults delete NSGlobalDomain KeyRepeat 2>/dev/null || true
    defaults delete NSGlobalDomain InitialKeyRepeat 2>/dev/null || true
    defaults delete NSGlobalDomain ApplePressAndHoldEnabled 2>/dev/null || true

    ok "Keyboard defaults restored"
}

# ============================================================================
# SPACES / MISSION CONTROL
# ============================================================================
optimize_spaces() {
    log "Making Spaces predictable for yabai..."

    defaults write com.apple.dock mru-spaces -bool false
    defaults write com.apple.dock workspaces-auto-swoosh -bool false
    defaults write com.apple.spaces spans-displays -bool false
    defaults write NSGlobalDomain AppleSpacesSwitchOnActivate -bool false

    ok "Separate Spaces per display enabled, auto-rearrange and auto-switch fades disabled"
}

restore_spaces() {
    log "Restoring Spaces defaults..."

    defaults delete com.apple.dock mru-spaces 2>/dev/null || true
    defaults delete com.apple.dock workspaces-auto-swoosh 2>/dev/null || true
    defaults delete com.apple.spaces spans-displays 2>/dev/null || true
    defaults delete NSGlobalDomain AppleSpacesSwitchOnActivate 2>/dev/null || true

    ok "Spaces defaults restored"
}

# ============================================================================
# DOCK
# ============================================================================
clean_dock() {
    log "Cleaning Dock for a launcher-first workflow..."

    defaults write com.apple.dock persistent-apps -array
    defaults write com.apple.dock show-recents -bool false

    ok "Dock cleaned"
}

restore_dock() {
    log "Restoring Dock defaults where possible..."

    defaults delete com.apple.dock show-recents 2>/dev/null || true
    warn "Pinned Dock apps are not restored automatically"
}

# ============================================================================
# LIGHT BACKGROUND SERVICES
# ============================================================================
disable_services() {
    local services=(
        com.apple.suggestd
        com.apple.knowledge-agent
    )

    log "Disabling lightweight suggestion services..."

    for svc in "${services[@]}"; do
        launchctl disable "gui/$(id -u)/$svc" 2>/dev/null && ok "Disabled $svc" || true
    done
}

restore_services() {
    local services=(
        com.apple.suggestd
        com.apple.knowledge-agent
    )

    log "Re-enabling suggestion services..."

    for svc in "${services[@]}"; do
        launchctl enable "gui/$(id -u)/$svc" 2>/dev/null && ok "Enabled $svc" || true
    done
}

# ============================================================================
# OPTIONAL AGGRESSIVE INDEXING TOGGLES
# ============================================================================
disable_indexing() {
    log "Disabling Spotlight indexing..."
    sudo mdutil -a -i off >/dev/null 2>&1 && ok "Spotlight indexing disabled" || warn "Could not disable Spotlight indexing"
}

restore_indexing() {
    log "Re-enabling Spotlight indexing..."
    sudo mdutil -a -i on >/dev/null 2>&1 && ok "Spotlight indexing enabled" || warn "Could not enable Spotlight indexing"
}

# ============================================================================
# EXPLICIT APP TRIM
# ============================================================================
trim_idle_apps() {
    local apps frontmost
    apps=("Music" "Photos" "Maps" "News" "Stocks" "TV" "Podcasts" "Home")
    frontmost="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true)"

    log "Trimming idle consumer apps..."

    for app in "${apps[@]}"; do
        if pgrep -x "$app" >/dev/null 2>&1 && [ "$app" != "$frontmost" ]; then
            osascript -e "tell application \"$app\" to quit" >/dev/null 2>&1 && ok "Quit $app" || true
        fi
    done
}

# ============================================================================
# MAIN
# ============================================================================
case "${1:-apply}" in
    apply)
        echo ""
        echo "  macOS Tiling Profile"
        echo "  ===================="
        echo ""
        disable_animations
        optimize_keyboard
        optimize_spaces
        clean_dock
        disable_services
        restart_ui_services
        echo ""
        ok "Profile applied. Use 'yabai-space-local.sh ensure' to converge Mission Control spaces."
        echo ""
        ;;
    reset)
        echo ""
        echo "  macOS Tiling Profile Reset"
        echo "  =========================="
        echo ""
        restore_animations
        restore_keyboard
        restore_spaces
        restore_dock
        restore_services
        restart_ui_services
        echo ""
        ok "Defaults restored where reversible."
        echo ""
        ;;
    trim)
        trim_idle_apps
        ;;
    indexing-off)
        disable_indexing
        ;;
    indexing-on)
        restore_indexing
        ;;
    daemon)
        warn "daemon mode is deprecated; modern macOS manages RAM itself"
        trim_idle_apps
        ;;
    *)
        err "Usage: macos-optimize.sh [apply|reset|trim|indexing-off|indexing-on|daemon]"
        exit 1
        ;;
esac
