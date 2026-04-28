#!/bin/bash

# ============================================================================
# ETABLI DEV SETUP
# Compatible: macOS, Linux (Ubuntu/Debian), Remote (SSH)
# ============================================================================

set -e

# ============================================================================
# VERSIONS (centralized for maintenance)
# ============================================================================
readonly NVM_VERSION="v0.40.1"
readonly NERD_FONT_VERSION="v3.1.1"
readonly MIN_NVIM_VERSION="0.12.2"
readonly PI_CORE_SKILLS=(
    "plan-loop"
    "plan-implement"
    "review"
    "implement"
    "caveman"
    "ui"
    "grill-me"
)

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

version_at_least() {
    local current="$1"
    local minimum="$2"
    local current_major current_minor current_patch minimum_major minimum_minor minimum_patch

    IFS=. read -r current_major current_minor current_patch <<EOF
$current
EOF
    IFS=. read -r minimum_major minimum_minor minimum_patch <<EOF
$minimum
EOF

    current_major=${current_major:-0}
    current_minor=${current_minor:-0}
    current_patch=${current_patch:-0}
    minimum_major=${minimum_major:-0}
    minimum_minor=${minimum_minor:-0}
    minimum_patch=${minimum_patch:-0}

    [ "$current_major" -gt "$minimum_major" ] && return 0
    [ "$current_major" -lt "$minimum_major" ] && return 1
    [ "$current_minor" -gt "$minimum_minor" ] && return 0
    [ "$current_minor" -lt "$minimum_minor" ] && return 1
    [ "$current_patch" -ge "$minimum_patch" ]
}

nvim_version() {
    command -v nvim >/dev/null 2>&1 || return 1
    nvim --version | sed -n '1s/^NVIM v//p' | awk '{print $1}'
}

ensure_nvim_version() {
    local version

    if ! version="$(nvim_version)"; then
        print_warning "Neovim not available after dependency install"
        return 1
    fi

    if version_at_least "$version" "$MIN_NVIM_VERSION"; then
        print_success "Neovim $version available"
        return 0
    fi

    print_warning "Neovim $version is older than required $MIN_NVIM_VERSION"
    return 1
}

has_valid_rtk() {
    command -v rtk &> /dev/null && rtk gain > /dev/null 2>&1
}

# Download helper with retries
download_with_retry() {
    local url="$1"
    local output="$2"
    local retries=3

    while [ $retries -gt 0 ]; do
        if curl -fsSLo "$output" "$url"; then
            return 0
        fi
        retries=$((retries - 1))
        [ $retries -gt 0 ] && print_warning "Download failed, retrying... ($retries left)" && sleep 2
    done
    print_error "Failed to download: $url"
    return 1
}

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

is_core_pi_skill() {
    local skill="$1"
    for core_skill in "${PI_CORE_SKILLS[@]}"; do
        if [ "$core_skill" = "$skill" ]; then
            return 0
        fi
    done
    return 1
}

prune_managed_pi_skills() {
    local skills_dir="$HOME/.pi/agent/skills"
    [ -d "$skills_dir" ] || return 0

    for skill_link in "$skills_dir"/*; do
        [ -L "$skill_link" ] || continue
        local target
        target="$(readlink "$skill_link")"
        case "$target" in
            "$REPO_DIR/pi/skills/"*)
                local skill_name
                skill_name="$(basename "$skill_link")"
                if ! is_core_pi_skill "$skill_name"; then
                    rm -f "$skill_link"
                    print_success "Removed stale Pi skill '$skill_name'"
                fi
                ;;
        esac
    done
}

sync_pi_agent_settings_resources() {
    local local_settings="$HOME/.pi/agent/settings.json"
    local tracked_settings="$REPO_DIR/pi/agent/settings.json"

    if [ ! -f "$local_settings" ] || [ ! -f "$tracked_settings" ]; then
        return 0
    fi

    if ! command -v node &> /dev/null; then
        print_warning "Node.js not available - skipping Pi agent settings resource sync"
        return 0
    fi

    if node - "$local_settings" "$tracked_settings" <<'NODE'
const fs = require("node:fs");

const [localPath, trackedPath] = process.argv.slice(2);
const localSettings = JSON.parse(fs.readFileSync(localPath, "utf8"));
const trackedSettings = JSON.parse(fs.readFileSync(trackedPath, "utf8"));

const managedSources = new Set([
  "local:etabli-workflow",
  "npm:pi-hooks",
  "npm:mitsupi",
  "git:github.com/badlogic/pi-skills",
  "npm:pi-interview",
  "https://github.com/davebcn87/pi-autoresearch",
  "npm:glimpseui",
]);
const localPackages = Array.isArray(localSettings.packages) ? localSettings.packages : [];
const trackedPackages = Array.isArray(trackedSettings.packages) ? trackedSettings.packages : [];

function packageSource(entry) {
  if (typeof entry === "string") return entry;
  if (entry && typeof entry === "object" && typeof entry.source === "string") return entry.source;
  return null;
}

const trackedBySource = new Map();
for (const entry of trackedPackages) {
  if (entry && typeof entry === "object" && managedSources.has(entry.source)) {
    trackedBySource.set(entry.source, entry);
  }
}

let changed = false;
for (const [source, trackedEntry] of trackedBySource) {
  const localIndex = localPackages.findIndex((entry) => packageSource(entry) === source);

  if (localIndex === -1) {
    localPackages.unshift(trackedEntry);
    changed = true;
    continue;
  }

  const before = JSON.stringify(localPackages[localIndex]);
  const after = JSON.stringify(trackedEntry);
  if (before !== after) {
    localPackages[localIndex] = trackedEntry;
    changed = true;
  }
}

if (changed) {
  localSettings.packages = localPackages;
  fs.writeFileSync(localPath, `${JSON.stringify(localSettings, null, 2)}\n`);
}
NODE
    then
        print_success "Pi agent settings resource filters synced"
    else
        print_warning "Pi agent settings resource sync failed"
    fi
}

sync_nvim_plugins() {
    if ! command -v nvim &> /dev/null; then
        print_warning "Neovim not available - skipping plugin sync"
        return 0
    fi

    ensure_nvim_version || print_warning "Install Neovim $MIN_NVIM_VERSION+ before relying on this config"

    print_step "Syncing Neovim plugins from lazy-lock.json..."
    if nvim --headless "+Lazy! restore" +qa > /dev/null 2>&1; then
        print_success "Neovim plugins synced"
    else
        print_warning "Neovim plugin sync failed - run: nvim '+Lazy! restore'"
    fi

    if nvim --headless "+lua vim.notify = function() end" +qa > /dev/null 2>&1; then
        print_success "Neovim config loads"
    else
        print_warning "Neovim config load check failed - run: nvim --headless +qa"
    fi
}

install_pi_packages_from_settings() {
    local settings_path="$REPO_DIR/pi/agent/settings.json"
    local package_sources

    if [ ! -f "$settings_path" ]; then
        print_warning "Pi package bootstrap file missing: $settings_path"
        return 0
    fi

    if ! command -v node &> /dev/null; then
        print_warning "Node.js not available - skipping Pi package sync"
        return 0
    fi

    package_sources="$({
        node -e '
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
    } 2>/dev/null | awk 'NF && !seen[$0]++')"

    if [ -z "$package_sources" ]; then
        print_warning "No Pi packages found in $settings_path"
        return 0
    fi

    printf '%s\n' "$package_sources" | while IFS= read -r package_source; do
        [ -z "$package_source" ] && continue
        if pi install "$package_source" > /dev/null 2>&1; then
            print_success "Pi package '$package_source' installed"
        else
            print_warning "Failed to install Pi package: $package_source"
        fi
    done
}

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
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Validate repo structure
if [ ! -f "$REPO_DIR/tmux.conf" ]; then
    print_warning "Missing tmux.conf at $REPO_DIR/tmux.conf - it will not be copied"
fi
if [ ! -d "$REPO_DIR/nvim" ]; then
    print_warning "Missing Neovim config at $REPO_DIR/nvim - it will not be linked"
fi

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
    # macOS with Homebrew
    if ! command -v brew &> /dev/null; then
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Note: node/npm installed via nvm below
    brew install neovim tmux git ripgrep fd fzf jq lazygit mosh lua-language-server || {
        print_warning "Some brew packages may have failed"
    }
    brew upgrade neovim 2>/dev/null || true

    # Nerd Font via Homebrew
    brew tap homebrew/cask-fonts 2>/dev/null || true
    brew install --cask font-caskaydia-mono-nerd-font 2>/dev/null || true

elif [[ "$OS" == "debian" ]]; then
    # Ubuntu/Debian
    sudo apt update
    sudo apt install -y curl wget git unzip ripgrep fd-find fzf jq build-essential make neovim tmux xclip mosh || {
        print_warning "Some apt packages may have failed"
    }
    sudo apt install -y lua-language-server 2>/dev/null || {
        print_warning "lua-language-server package unavailable from apt"
    }

    # fd symlink
    if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd || print_warning "Could not create fd symlink"
    fi

    # Lazygit
    if ! command -v lazygit &> /dev/null; then
        print_step "Installing Lazygit..."
        # Use sed instead of grep -P for macOS compatibility
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p')
        if [ -n "$LAZYGIT_VERSION" ]; then
            (
                cd /tmp || exit 1
                if download_with_retry \
                    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
                    "lazygit.tar.gz"; then
                    tar xf lazygit.tar.gz lazygit
                    sudo install lazygit /usr/local/bin
                    rm -f lazygit lazygit.tar.gz
                fi
            )
        else
            print_warning "Could not fetch lazygit version from GitHub API"
        fi
    fi

elif [[ "$OS" == "redhat" ]]; then
    # RHEL/CentOS/Fedora (node via nvm plus bas)
    sudo dnf install -y neovim tmux git ripgrep fd fzf make gcc jq unzip curl mosh || {
        print_warning "Some dnf packages may have failed"
    }
    sudo dnf install -y lua-language-server 2>/dev/null || {
        print_warning "lua-language-server package unavailable from dnf"
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
    if [[ "$OS" == "mac" ]] && command -v brew &> /dev/null; then
        brew install rtk || print_warning "RTK brew install failed"
    else
        curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh || \
            print_warning "RTK install script failed"
    fi

    if has_valid_rtk; then
        print_success "RTK installed"
    else
        print_warning "RTK not available or wrong binary installed; verify with: rtk gain"
    fi
fi

# ============================================================================
# INSTALL NODE.JS (via nvm)
# ============================================================================
print_step "Setting up Node.js via nvm..."

export NVM_DIR="$HOME/.nvm"

# Install nvm if not present
if [ ! -d "$NVM_DIR" ] || [ ! -f "$NVM_DIR/nvm.sh" ]; then
    print_step "Installing nvm ${NVM_VERSION}..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

# Verify nvm.sh exists after installation
if [ ! -f "$NVM_DIR/nvm.sh" ]; then
    print_error "nvm installation failed - $NVM_DIR/nvm.sh not found"
    print_error "Please restart your shell and re-run this script"
    exit 1
fi

# Load nvm (it is a shell function, not a command)
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# Verify nvm is loaded as a function
if ! declare -f nvm > /dev/null 2>&1; then
    print_error "nvm failed to load as a function"
    print_error "Please restart your shell and re-run this script"
    exit 1
fi

# Install LTS node if not present via nvm
if ! command -v node &> /dev/null; then
    print_step "Installing Node.js LTS..."
    nvm install --lts
    nvm use --lts
    nvm alias default lts/*
fi

# Verify node is available
if command -v node &> /dev/null; then
    print_success "Node.js $(node -v) ready (via nvm)"
else
    print_error "Node.js installation failed"
    exit 1
fi

# ============================================================================
# INSTALL NPM TOOLS
# ============================================================================
print_step "Installing npm tools..."

# Verify npm works
if ! command -v npm &> /dev/null; then
    print_error "npm not available - nvm setup may have failed"
    exit 1
fi

if npm install -g \
    typescript \
    typescript-language-server \
    prettier \
    eslint \
    intelephense \
    @github/copilot-language-server \
    @ember-tooling/ember-language-server \
    @tailwindcss/language-server; then
    print_success "NPM tools installed"
else
    print_warning "Some npm packages may have failed to install"
fi

# ============================================================================
# INSTALL NERD FONT
# ============================================================================
print_step "Installing Nerd Font..."

mkdir -p ~/.local/share/fonts

(
    cd ~/.local/share/fonts || exit 1

    if [ ! -f "CaskaydiaMonoNerdFont-Regular.ttf" ]; then
        if download_with_retry \
            "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/CaskaydiaMono.zip" \
            "CaskaydiaMono.zip"; then
            # Verify zip integrity before extracting
            if unzip -tq CaskaydiaMono.zip > /dev/null 2>&1; then
                unzip -qo CaskaydiaMono.zip
                rm -f CaskaydiaMono.zip
            else
                print_warning "Font zip corrupted, removing"
                rm -f CaskaydiaMono.zip
            fi
        fi
    fi
)

# Refresh font cache (Linux only)
if [[ "$OS" != "mac" ]]; then
    fc-cache -fv > /dev/null 2>&1 || true
fi

print_success "Nerd Font installed"

# ============================================================================
# SETUP NEOVIM CONFIG
# ============================================================================
print_step "Setting up Neovim config..."

mkdir -p ~/.config

if [ -d "$REPO_DIR/nvim" ]; then
    NVIM_TARGET="$REPO_DIR/nvim"
    NVIM_LINK="$HOME/.config/nvim"
    CURRENT_LINK_TARGET=""

    if [ -L "$NVIM_LINK" ]; then
        CURRENT_LINK_TARGET="$(readlink "$NVIM_LINK")"
    fi

    if [ -e "$NVIM_LINK" ] || [ -L "$NVIM_LINK" ]; then
        if [ "$CURRENT_LINK_TARGET" != "$NVIM_TARGET" ]; then
            NVIM_BACKUP="$HOME/.config/nvim.bak.$(date +%Y%m%d-%H%M%S)"
            mv "$NVIM_LINK" "$NVIM_BACKUP"
            print_warning "Existing Neovim config moved to $NVIM_BACKUP"
        fi
    fi

    if ln -sfn "$NVIM_TARGET" "$NVIM_LINK"; then
        print_success "Neovim config linked"
        sync_nvim_plugins
    else
        print_error "Failed to link Neovim config"
    fi
else
    print_warning "Neovim config directory not found in $REPO_DIR/nvim"
fi

# ============================================================================
# SETUP TMUX CONFIG
# ============================================================================
print_step "Setting up Tmux config..."

# Backup existing config (skip if already a symlink)
if [ -f ~/.tmux.conf ] && [ ! -L ~/.tmux.conf ]; then
    cp ~/.tmux.conf ~/.tmux.conf.bak
fi

# Symlink config
if [ -f "$REPO_DIR/tmux.conf" ]; then
    if ln -sf "$REPO_DIR/tmux.conf" ~/.tmux.conf; then
        print_success "Tmux config linked"
    else
        print_error "Failed to link tmux config"
    fi
else
    print_warning "tmux.conf not found in $REPO_DIR"
fi

# Install TPM (Tmux Plugin Manager)
if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# ============================================================================
# SETUP PI CODING AGENT
# ============================================================================
print_step "Setting up Pi Coding Agent..."

mkdir -p ~/.pi ~/.pi/agent/skills ~/.pi/agent/themes ~/.pi/agent/extensions

# AGENTS.md
if [ -f "$REPO_DIR/pi/AGENTS.md" ]; then
    ln -sf "$REPO_DIR/pi/AGENTS.md" ~/.pi/agent/AGENTS.md
    print_success "Pi AGENTS.md linked"
fi

# models.json (backup existing if not a symlink)
if [ -f "$REPO_DIR/pi/models.json" ]; then
    if [ -f ~/.pi/agent/models.json ] && [ ! -L ~/.pi/agent/models.json ]; then
        cp ~/.pi/agent/models.json ~/.pi/agent/models.json.bak
    fi
    ln -sf "$REPO_DIR/pi/models.json" ~/.pi/agent/models.json
    print_success "Pi models.json linked"
fi

# Link extensions directory (agent path only — ~/.pi/extensions auto-scans and would cause conflicts)
if [ -d "$REPO_DIR/pi/extensions" ]; then
    # Remove ~/.pi/extensions if it exists (avoid double-loading conflicts)
    if [ -L ~/.pi/extensions ]; then
        rm ~/.pi/extensions
    elif [ -d ~/.pi/extensions ]; then
        mv ~/.pi/extensions ~/.pi/extensions.bak
    fi
    if [ -d ~/.pi/agent/extensions ] && [ ! -L ~/.pi/agent/extensions ]; then
        mv ~/.pi/agent/extensions ~/.pi/agent/extensions.bak
    fi
    ln -sfn "$REPO_DIR/pi/extensions" ~/.pi/agent/extensions
    print_success "Pi extensions linked"
fi

if [ -d "$REPO_DIR/pi/themes" ]; then
    if [ -d ~/.pi/themes ] && [ ! -L ~/.pi/themes ]; then
        mv ~/.pi/themes ~/.pi/themes.bak
    fi
    ln -sfn "$REPO_DIR/pi/themes" ~/.pi/themes
fi

# settings.json (root + agent)
if [ -f "$REPO_DIR/pi/settings.json" ]; then
    if [ -f ~/.pi/settings.json ] && [ ! -L ~/.pi/settings.json ]; then
        cp ~/.pi/settings.json ~/.pi/settings.json.bak
    fi
    ln -sf "$REPO_DIR/pi/settings.json" ~/.pi/settings.json
    print_success "Pi settings.json linked"
fi

if [ -f "$REPO_DIR/pi/agent/settings.json" ]; then
    mkdir -p ~/.pi/agent
    if [ -L ~/.pi/agent/settings.json ]; then
        tmp_settings="$(mktemp)"
        if cp -L ~/.pi/agent/settings.json "$tmp_settings" 2>/dev/null; then
            rm ~/.pi/agent/settings.json
            mv "$tmp_settings" ~/.pi/agent/settings.json
            print_success "Pi agent settings migrated to local file"
        else
            rm -f "$tmp_settings"
            rm ~/.pi/agent/settings.json
            cp "$REPO_DIR/pi/agent/settings.json" ~/.pi/agent/settings.json
            print_success "Pi agent settings bootstrapped locally"
        fi
    elif [ ! -f ~/.pi/agent/settings.json ]; then
        cp "$REPO_DIR/pi/agent/settings.json" ~/.pi/agent/settings.json
        print_success "Pi agent settings bootstrapped locally"
    else
        print_success "Pi agent settings kept local"
    fi

    sync_pi_agent_settings_resources
fi

# damage-control is not part of the default Pi profile; remove stale managed
# symlinks left by older installer versions without touching user-owned files.
if [ -L ~/.pi/damage-control-rules.json ]; then
    rm -f ~/.pi/damage-control-rules.json
fi

# Themes
for theme_file in "$REPO_DIR/pi/themes"/*.json; do
    if [ -f "$theme_file" ]; then
        theme_name=$(basename "$theme_file")
        ln -sf "$theme_file" ~/.pi/agent/themes/"$theme_name"
        print_success "Pi theme '$theme_name' linked"
    fi
done

# Core Pi skills only
prune_managed_pi_skills
for skill_name in "${PI_CORE_SKILLS[@]}"; do
    skill_dir="$REPO_DIR/pi/skills/$skill_name"
    if [ -d "$skill_dir" ]; then
        ln -sfn "$skill_dir" ~/.pi/agent/skills/"$skill_name"
        print_success "Pi skill '$skill_name' linked"
    else
        print_warning "Pi skill '$skill_name' missing from repo"
    fi
done

rm -f ~/.pi/agent/skills/verify

mkdir -p ~/.claude/commands
for command_file in "$REPO_DIR/claude/commands"/*.md; do
    if [ -f "$command_file" ]; then
        command_name=$(basename "$command_file")
        target_name="$command_name"
        if [ "$command_name" = "plan-create.md" ]; then
            target_name="plan.md"
        fi
        ln -sf "$command_file" ~/.claude/commands/"$target_name"
        print_success "Claude command '$target_name' linked"
    fi
done
rm -f ~/.claude/commands/verify.md
rm -f ~/.claude/commands/plan-create.md

for shared_doc in review-rubric.md handoff-template.md; do
    if [ -f "$REPO_DIR/workflow/$shared_doc" ]; then
        ln -sf "$REPO_DIR/workflow/$shared_doc" ~/.claude/"$shared_doc"
        print_success "Claude doc '$shared_doc' linked"
    fi
done

# Install Pi if not present
if ! command -v pi &> /dev/null; then
    print_step "Installing Pi Coding Agent..."
    npm install -g @mariozechner/pi-coding-agent && \
        print_success "Pi installed" || \
        print_warning "Pi install failed (npm i -g @mariozechner/pi-coding-agent)"
fi

# Install packages declared in tracked bootstrap settings
if command -v pi &> /dev/null; then
    print_step "Installing Pi packages from tracked settings..."
    install_pi_packages_from_settings
fi

# ============================================================================
# INSTALL DEV SCRIPTS
# ============================================================================
print_step "Installing dev scripts..."

mkdir -p ~/.local/bin

# Export PATH immediately for current session
export PATH="$HOME/.local/bin:$PATH"

# Install scripts using helper function
install_script "dev-spawn" || true
install_script "tmux-clipboard.sh" || true
install_script "fix-links" || true

# Add ~/.local/bin to PATH in shell configs (if not already present)
for rcfile in ~/.bashrc ~/.zshrc; do
    if [ -f "$rcfile" ] || [ "$rcfile" = ~/.zshrc ]; then
        if ! grep -q '\$HOME/.local/bin' "$rcfile" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rcfile" 2>/dev/null || true
        fi
    fi
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
printf "  2. Start Neovim:     ${YELLOW}nvim${NC}\n"
printf "  3. Auth Copilot:     ${YELLOW}:LspCopilotSignIn${NC} in a Neovim project buffer\n"
printf "  4. Start Tmux:       ${YELLOW}tmux${NC}\n"
printf "  5. Install plugins:  ${YELLOW}prefix + I${NC} (Ctrl+b then I)\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
printf "  ${BLUE}Remote Connection (Mosh):${NC}\n"
printf "  From your Mac:   ${YELLOW}mosh user@your-vps.com${NC}\n"
printf "  Firewall VPS:    ${YELLOW}sudo ufw allow 60000:61000/udp${NC}\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
printf "  ${BLUE}Neovim Defaults:${NC}\n"
printf "  Leader          Space\n"
printf "  Files / Grep    <leader><space> / <leader>/\n"
printf "  Buffers         <leader>.\n"
printf "  Explorer        <leader>ft / <leader>fe\n"
printf "  Projects        <leader>pp / <leader>pr / <leader>pi\n"
printf "  Sessions        <leader>ps / <leader>pl\n"
printf "  Project files   <leader>fp\n"
printf "  Aliases         <leader>ff / <leader>fg / <leader>fb\n"
printf "  Copilot         Native inline: Tab/<A-l> accept, <A-]> / <A-[> cycle, :CopilotToggle\n"
printf "  Doctor          :EtabliDoctor\n"
printf "  Complete        <C-n> / <C-p> / <CR>\n"
printf "  Format          <leader>cf\n"
printf "  LSP rename      <leader>rn (buffer-local)\n"
printf "  Code action     <leader>ca (buffer-local)\n"
printf "  Help            Minimal which-key on leader maps\n"
printf "  Notes           See nvim/README.md\n"
echo ""
printf "  ${BLUE}Tmux Shortcuts:${NC}\n"
printf "  Ctrl+b          Prefix\n"
printf "  Ctrl+b |        Split vertical\n"
printf "  Ctrl+b -        Split horizontal\n"
printf "  Ctrl+b h/j/k/l  Navigate panes\n"
printf "  Shift+Left/Right Switch windows\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
printf "  ${BLUE}Dev Spawn:${NC}\n"
printf "  dev-spawn           Launch both tmux sessions (local + VPS)\n"
printf "  dev-spawn local     Local session only\n"
printf "  dev-spawn vps       VPS session only\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
printf "  ${BLUE}Pi Coding Agent:${NC}\n"
printf "  Start:           ${YELLOW}pi${NC}\n"
printf "  Auth providers:  ${YELLOW}/login${NC}\n"
printf "  Implement:       ${YELLOW}/skill:implement${NC}\n"
printf "  Plan loop:       ${YELLOW}/skill:plan-loop${NC}\n"
printf "  Plan implement:  ${YELLOW}/skill:plan-implement${NC}\n"
printf "  Caveman:         ${YELLOW}/skill:caveman${NC}\n"
printf "  Grill me:        ${YELLOW}/skill:grill-me${NC}\n"
printf "  UI:              ${YELLOW}/skill:ui${NC}\n"
printf "  Model selector:  ${YELLOW}Ctrl+L${NC}\n"
printf "  Cycle models:    ${YELLOW}Ctrl+P / Shift+Ctrl+P${NC}\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
printf "  ${BLUE}Claude Code:${NC}\n"
printf "  Plan:            ${YELLOW}/plan${NC}\n"
printf "  Plan review:     ${YELLOW}/plan-review${NC}\n"
printf "  Implement:       ${YELLOW}/implement${NC}\n"
printf "  Plan loop:       ${YELLOW}/plan-loop${NC}\n"
printf "  Plan implement:  ${YELLOW}/plan-implement${NC}\n"
printf "  Review:          ${YELLOW}/review${NC}\n"
printf "  Handoff:         ${YELLOW}/handoff${NC}\n"
printf "  Impl handoff:    ${YELLOW}/handoff-implement${NC}\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
