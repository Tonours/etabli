#!/usr/bin/env bash

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { printf "${BLUE}[*]${NC} %s\n" "$1"; }
ok()  { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
warn(){ printf "${YELLOW}[!]${NC} %s\n" "$1"; }
err() { printf "${RED}[x]${NC} %s\n" "$1"; }

usage() {
    cat <<'EOF'
Usage: macos-disk-clean.sh [report|safe|deep] [--yes]

report  Show the main disk usage buckets without deleting anything.
safe    Clean macOS/app caches, logs, trash, Quick Look cache and Homebrew cruft.
deep    Run safe cleanup plus rebuildable developer caches.

Use --yes to apply safe/deep without prompting.
EOF
}

require_macos() {
    [ "$(uname -s)" = "Darwin" ] || {
        err "macos-disk-clean.sh only supports macOS"
        exit 1
    }
}

size_kb() {
    local path="$1"
    [ -e "$path" ] || {
        printf "0"
        return 0
    }
    du -sk "$path" 2>/dev/null | awk '{print $1}'
}

format_kb() {
    local kb="$1"
    awk -v kb="$kb" '
        BEGIN {
            if (kb >= 1024 * 1024) printf "%.1fG", kb / (1024 * 1024)
            else if (kb >= 1024) printf "%.1fM", kb / 1024
            else printf "%dK", kb
        }
    '
}

free_kb() {
    df -k / | awk 'NR == 2 {print $4}'
}

clear_dir_contents() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
}

clear_if_exists() {
    local path="$1"
    if [ -d "$path" ]; then
        clear_dir_contents "$path"
        ok "Cleared $path"
    fi
}

report_group() {
    local label="$1"
    local path="$2"
    printf "%-24s %8s  %s\n" "$label" "$(format_kb "$(size_kb "$path")")" "$path"
}

report() {
    printf "Disk free on /: %s\n\n" "$(df -h / | awk 'NR == 2 {print $4}')"
    printf "%-24s %8s  %s\n" "bucket" "size" "path"
    printf "%-24s %8s  %s\n" "------------------------" "--------" "----"
    report_group "Library Caches" "$HOME/Library/Caches"
    report_group "Library Logs" "$HOME/Library/Logs"
    report_group "Trash" "$HOME/.Trash"
    report_group "Dot cache" "$HOME/.cache"
    report_group "npm cache" "$HOME/.npm"
    report_group "bun cache" "$HOME/.bun/install/cache"
    report_group "DerivedData" "$HOME/Library/Developer/Xcode/DerivedData"
    report_group "CoreSimulator" "$HOME/Library/Developer/CoreSimulator"
    report_group "Homebrew cache" "$HOME/Library/Caches/Homebrew"
}

confirm_apply() {
    local mode="$1"
    local answer=""

    if [ "${ASSUME_YES:-false}" = "true" ]; then
        return 0
    fi

    printf "%s cleanup will delete rebuildable caches/logs. Continue? [y/N] " "$mode"
    read -r answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) warn "Cancelled"; exit 1 ;;
    esac
}

run_safe_cleanup() {
    log "Cleaning safe macOS junk..."

    clear_if_exists "$HOME/.Trash"
    clear_if_exists "$HOME/Library/Logs"
    clear_if_exists "$HOME/Library/Caches"

    if command -v qlmanage >/dev/null 2>&1; then
        qlmanage -r cache >/dev/null 2>&1 || true
        ok "Reset Quick Look cache"
    fi

    if command -v xcrun >/dev/null 2>&1; then
        xcrun simctl delete unavailable >/dev/null 2>&1 || true
        ok "Deleted unavailable simulators if any"
    fi

    if command -v brew >/dev/null 2>&1; then
        brew cleanup -s >/dev/null 2>&1 || true
        ok "Ran Homebrew cleanup"
    fi
}

run_deep_cleanup() {
    run_safe_cleanup

    log "Cleaning rebuildable developer caches..."

    clear_if_exists "$HOME/.cache"
    clear_if_exists "$HOME/.bun/install/cache"
    clear_if_exists "$HOME/Library/Developer/Xcode/DerivedData"

    if command -v npm >/dev/null 2>&1; then
        npm cache clean --force >/dev/null 2>&1 || true
        ok "Cleaned npm cache"
    else
        clear_if_exists "$HOME/.npm"
    fi

    if command -v pnpm >/dev/null 2>&1; then
        pnpm store prune >/dev/null 2>&1 || true
        ok "Pruned pnpm store"
    fi

    clear_if_exists "$HOME/Library/Caches/pnpm"
    clear_if_exists "$HOME/Library/Caches/CocoaPods"
}

apply_cleanup() {
    local mode="$1"
    local before_free after_free freed_kb

    before_free="$(free_kb)"
    confirm_apply "$mode"

    case "$mode" in
        safe) run_safe_cleanup ;;
        deep) run_deep_cleanup ;;
        *) err "unknown mode: $mode"; exit 1 ;;
    esac

    after_free="$(free_kb)"
    freed_kb=$((after_free - before_free))

    printf "\n"
    ok "Cleanup complete"
    printf "Recovered: %s\n" "$(format_kb "$freed_kb")"
    printf "Disk free: %s\n" "$(df -h / | awk 'NR == 2 {print $4}')"
}

require_macos

MODE="report"
ASSUME_YES="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        report|safe|deep)
            MODE="$1"
            shift
            ;;
        -y|--yes)
            ASSUME_YES="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
done

case "$MODE" in
    report) report ;;
    safe|deep) apply_cleanup "$MODE" ;;
esac
