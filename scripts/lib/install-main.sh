#!/bin/bash

# ============================================================================
# ETABLI DEV SETUP
# Compatible: macOS, Linux (Ubuntu/Debian), Remote (SSH)
# ============================================================================

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$BOOTSTRAP_DIR/lib/pi-paths.sh"
. "$BOOTSTRAP_DIR/lib/prefer-cursor-agent.sh"
. "$BOOTSTRAP_DIR/lib/managed-surfaces.sh"

# ============================================================================
# VERSIONS (centralized for maintenance)
# ============================================================================
readonly PI_AGENT_NPM_PINS=(
    "vscode-languageserver-protocol@3.17.5"
)
NODE_CMD=(node)
NPM_CMD=(npm)

# ============================================================================
# COLORS & HELPERS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { printf "${BLUE}[*]${NC} %s\n" "$1"; }
print_success() { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
print_warning() { printf "${YELLOW}[!]${NC} %s\n" "$1"; }
print_error() { printf "${RED}[x]${NC} %s\n" "$1"; }

managed_surface_status() {
    local status="$1"
    local message="$2"
    case "$status" in
    WARN | MISSING | KEEP) print_warning "$message" ;;
    *) print_success "$message" ;;
    esac
}

converge_agent_surfaces() {
    ETABLI_DEPLOY_CALLER=install ETABLI_SCOPE="${ETABLI_SCOPE:-}" \
        "$BOOTSTRAP_DIR/deploy-agent-workflow" --apply --home "$HOME"
}

has_valid_rtk() {
    command -v rtk &>/dev/null && rtk gain >/dev/null 2>&1
}

node_available() {
    "${NODE_CMD[@]}" -v >/dev/null 2>&1
}

node_runtime_available() {
    node_available && "${NPM_CMD[@]}" -v >/dev/null 2>&1
}

prepend_asdf_shims() {
    local shims_dir="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"

    if [ -d "$shims_dir" ]; then
        case ":$PATH:" in
        *":$shims_dir:"*) ;;
        *) export PATH="$shims_dir:$PATH" ;;
        esac
    fi
}

append_path_entry() {
    local entry="$1"

    case ":${PATH:-}:" in
    *":$entry:"*) ;;
    *)
        if [ -n "${PATH:-}" ]; then
            export PATH="$PATH:$entry"
        else
            export PATH="$entry"
        fi
        ;;
    esac
}

ensure_local_bin_shell_path() {
    local rcfile="$1"
    local desired='case ":${PATH:-}:" in *":$HOME/.local/bin:"*) ;; *) export PATH="${PATH:+$PATH:}$HOME/.local/bin" ;; esac'
    local legacy='export PATH="$HOME/.local/bin:$PATH"'
    local tmp_file

    if [ ! -f "$rcfile" ] && [ "$rcfile" != "$HOME/.zshrc" ]; then
        return 0
    fi

    touch "$rcfile" 2>/dev/null || return 0

    tmp_file="$(mktemp)" || return 0
    if awk -v desired="$desired" -v legacy="$legacy" '
        $0 == desired {
            has_desired = 1
            has_local_bin = 1
            print
            next
        }
        $0 == legacy {
            if (!has_desired) {
                print desired
                has_desired = 1
            }
            has_local_bin = 1
            next
        }
        /\$HOME\/\.local\/bin/ || /~\/\.local\/bin/ || /\/\.local\/bin/ {
            has_local_bin = 1
        }
        { print }
        END {
            if (!has_local_bin && !has_desired) {
                print desired
            }
        }
    ' "$rcfile" >"$tmp_file" && cp "$tmp_file" "$rcfile"; then
        rm -f "$tmp_file"
    else
        rm -f "$tmp_file"
        return 0
    fi
}

reshim_asdf_node() {
    if [ "${NODE_CMD[0]}" = "asdf" ]; then
        asdf reshim nodejs >/dev/null 2>&1 || true
    fi
}

select_node_runtime() {
    print_step "Checking Node.js runtime..."

    if command -v asdf &>/dev/null; then
        if asdf exec node -v >/dev/null 2>&1 && asdf exec npm -v >/dev/null 2>&1; then
            prepend_asdf_shims
            NODE_CMD=(asdf exec node)
            NPM_CMD=(asdf exec npm)
            print_success "Node.js $("${NODE_CMD[@]}" -v) ready (via asdf)"
            return 0
        fi
    fi

    if command -v node &>/dev/null && command -v npm &>/dev/null; then
        NODE_CMD=(node)
        NPM_CMD=(npm)
        print_success "Node.js $("${NODE_CMD[@]}" -v) ready (via PATH)"
        return 0
    fi

    print_error "Node.js and npm are required but were not found"
    print_error "Install them with asdf, then rerun: asdf plugin add nodejs; asdf install nodejs latest"
    return 1
}

# Download helper with retries
# Script install helper (symlink to repo)
install_script() {
    local script="$1"
    local src="$SCRIPT_DIR/$script"
    local dst="$HOME/.local/bin/$script"

    if [ -f "$src" ]; then
        chmod +x "$src"
        ln -sf "$src" "$dst"
        print_success "$script linked"
        return 0
    fi
    return 1
}

pi_coding_agent_spec() {
    "${NODE_CMD[@]}" -e '
const version = require(process.argv[1]).dependencies["@earendil-works/pi-coding-agent"];
if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error("Pi requires an exact version in pi/package.json");
console.log(`@earendil-works/pi-coding-agent@${version}`);
' "$BOOTSTRAP_DIR/../pi/package.json"
}

stamp_pi_specialist_skills() {
    "$BOOTSTRAP_DIR/pi-dmi-stamp" --home "$HOME" --repo "$BOOTSTRAP_DIR/.." ||
        print_warning "Pi specialist visibility needs repair: run $BOOTSTRAP_DIR/pi-dmi-stamp --home \"$HOME\""
}

install_pi_packages_from_settings() {
    local settings_path="$REPO_DIR/pi/agent/settings.json"
    local package_sources

    if [ ! -f "$settings_path" ]; then
        print_warning "Pi package bootstrap file missing: $settings_path"
        return 0
    fi

    if ! node_runtime_available; then
        print_warning "Node.js not available - skipping Pi package sync"
        return 0
    fi

    package_sources="$(
        {
            "${NODE_CMD[@]}" -e '
const fs = require("fs");
const settingsPath = process.argv[1];
const raw = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
for (const entry of Array.isArray(raw.packages) ? raw.packages : []) {
  if (typeof entry === "string" && entry.trim()) {
    console.log(entry.trim());
    continue;
  }
  if (entry && typeof entry === "object" && typeof entry.source === "string" && entry.source.trim()) {
    console.log(entry.source.trim());
  }
}
' "$settings_path"
        } 2>/dev/null | awk 'NF && !seen[$0]++' || true
    )"

    if [ -z "$package_sources" ]; then
        print_warning "No Pi packages found in $settings_path"
        return 0
    fi

    printf '%s\n' "$package_sources" | while IFS= read -r package_source; do
        [ -z "$package_source" ] && continue
        case "$package_source" in
        local:*)
            print_step "Skipping '$package_source' (skills linked from this repo)"
            continue
            ;;
        esac
        if pi install "$package_source" >/dev/null 2>&1; then
            print_success "Pi package '$package_source' installed"
        else
            print_warning "Failed to install Pi package: $package_source"
        fi
    done
}

install_pi_agent_npm_pins() {
    local package_dir

    package_dir="$(pi_agent_npm_dir "$HOME")"

    if ! node_runtime_available; then
        print_warning "Node.js not available - skipping Pi agent npm pins"
        return 0
    fi

    mkdir -p "$package_dir"
    if (cd "$package_dir" && "${NPM_CMD[@]}" install --save-exact "${PI_AGENT_NPM_PINS[@]}" >/dev/null 2>&1); then
        print_success "Pi agent npm pins installed"
    else
        print_warning "Failed to install Pi agent npm pins"
    fi
}

if [ "${BASH_SOURCE[0]}" != "$0" ]; then
    return 0
fi

# ============================================================================
# VALIDATIONS
# ============================================================================

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
elif [[ -f /etc/debian_version ]]; then
    OS="debian"
elif [[ -f /etc/redhat-release ]]; then
    OS="redhat"
elif [[ -f /etc/arch-release ]]; then
    OS="arch"
fi

if [[ "$OS" == "unknown" ]]; then
    print_error "Unsupported OS: $OSTYPE"
    exit 1
fi

# Check disk space (minimum 500MB)
check_disk_space() {
    local available
    available=$(df -k "$HOME" | awk 'NR==2 {print $4}')

    if [ "$available" -lt 512000 ]; then
        print_error "Less than 500MB available in $HOME (${available}KB found)"
        exit 1
    fi
}

check_disk_space

# Create required directories early
mkdir -p ~/.config ~/.local/share ~/.local/bin ~/.local/state

# Get script and repo directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "-------------------------------------------------------------------"
echo "  Dev Environment Setup"
echo "  Detected OS: $OS"
echo "  Repo: $REPO_DIR"
echo "-------------------------------------------------------------------"
echo ""

# ============================================================================
# INSTALL DEPENDENCIES
# ============================================================================
print_step "Installing dependencies..."

if [[ "$OS" == "mac" ]]; then
    if ! command -v brew &>/dev/null; then
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    brew install git ripgrep fd jq || {
        print_warning "Some brew packages may have failed"
    }

elif [[ "$OS" == "debian" ]]; then
    sudo apt update
    sudo apt install -y curl git unzip ripgrep fd-find jq || {
        print_warning "Some apt packages may have failed"
    }

    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd || print_warning "Could not create fd symlink"
    fi

elif [[ "$OS" == "redhat" ]]; then
    sudo dnf install -y git ripgrep fd jq unzip curl || {
        print_warning "Some dnf packages may have failed"
    }
elif [[ "$OS" == "arch" ]]; then
    sudo pacman -Sy --needed --noconfirm curl git unzip ripgrep fd jq || {
        print_warning "Some pacman packages may have failed"
    }
fi

print_success "Dependencies installed"

# ============================================================================
# INSTALL RTK
# ============================================================================
print_step "Installing RTK..."

if has_valid_rtk; then
    print_success "RTK already installed"
else
    if [[ "$OS" == "mac" ]] && command -v brew &>/dev/null; then
        brew install rtk || print_warning "RTK brew install failed"
    else
        curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh ||
            print_warning "RTK install script failed"
    fi

    if has_valid_rtk; then
        print_success "RTK installed"
    else
        print_warning "RTK not available or wrong binary installed; verify with: rtk gain"
    fi
fi

# ============================================================================
# SELECT NODE.JS
# ============================================================================
if ! select_node_runtime; then
    exit 1
fi

# ============================================================================
# SETUP AGENT WORKFLOW SURFACES
# ============================================================================
print_step "Setting up agent workflow surfaces..."
converge_agent_surfaces
if ! command -v pi &>/dev/null; then
    print_step "Installing Pi Coding Agent..."
    pi_package_spec="$(pi_coding_agent_spec)"
    "${NPM_CMD[@]}" install -g --ignore-scripts "$pi_package_spec" &&
        reshim_asdf_node &&
        print_success "Pi installed" ||
        print_warning "Pi install failed (npm install -g --ignore-scripts $pi_package_spec)"
fi

if command -v pi &>/dev/null; then
    print_step "Installing Pi packages from tracked settings..."
    install_pi_packages_from_settings
    install_pi_agent_npm_pins
    stamp_pi_specialist_skills
fi

# ============================================================================
# INSTALL DEV SCRIPTS
# ============================================================================
print_step "Installing dev scripts..."

mkdir -p ~/.local/bin

append_path_entry "$HOME/.local/bin"

install_script "fix-links" || true
install_script "deploy-workflow" || true

prefer_cursor_agent_remove_grok_collision "$HOME"
for rcfile in ~/.bashrc ~/.zshrc; do
    ensure_local_bin_shell_path "$rcfile"
    prefer_cursor_agent_ensure_shell_hook "$rcfile" ||
        print_warning "could not refresh Cursor agent PATH hook in $rcfile"
done

print_success "Dev scripts installed"

# ============================================================================
# DONE
# ============================================================================
echo ""
echo "-------------------------------------------------------------------"
echo ""
print_success "Installation complete!"
echo ""
printf "  ${BLUE}Next steps:${NC}\n"
echo ""
if [[ "$SHELL" == *"zsh"* ]]; then
    printf "  1. Reload shell:     ${YELLOW}source ~/.zshrc${NC}\n"
else
    printf "  1. Reload shell:     ${YELLOW}source ~/.bashrc${NC}\n"
fi
printf "  2. Wire Claude hooks: ${YELLOW}scripts/claude-hooks-merge${NC}\n"
printf "  3. Verify:           ${YELLOW}scripts/verify-agentic-infra core${NC}\n"
printf "  Editor setup:        ${YELLOW}dotfiles/scripts/install-editor${NC}\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
printf "  ${BLUE}Pi Coding Agent:${NC}\n"
printf "  Start:           ${YELLOW}pi${NC}\n"
printf "  Auth providers:  ${YELLOW}/login${NC}\n"
printf "  Implement:       ${YELLOW}/skill:implement${NC}\n"
printf "  Plan loop:       ${YELLOW}/skill:plan-loop${NC}\n"
printf "  Plan implement:  ${YELLOW}/skill:plan-implement${NC}\n"
printf "  Model selector:  ${YELLOW}Ctrl+L${NC}\n"
printf "  Cycle models:    ${YELLOW}Ctrl+P / Shift+Ctrl+P${NC}\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
printf "  ${BLUE}Claude Code:${NC}\n"
printf "  Plan loop:       ${YELLOW}/plan-loop${NC}\n"
printf "  Plan implement:  ${YELLOW}/plan-implement${NC}\n"
printf "  Implement:       ${YELLOW}/implement${NC}\n"
printf "  Review:          ${YELLOW}/review${NC}\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
