#!/bin/bash

# ============================================================================
# VS CODE + TMUX SETUP
# Compatible: macOS, Linux (Ubuntu/Debian), Remote (SSH)
# ============================================================================

set -e

# ============================================================================
# VERSIONS (centralized for maintenance)
# ============================================================================
readonly NVM_VERSION="v0.40.1"
readonly NERD_FONT_VERSION="v3.1.1"

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
if [ ! -d "$REPO_DIR/vscode" ]; then
    print_warning "Missing VS Code config at $REPO_DIR/vscode - it will not be copied"
fi
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
    brew install neovim tmux git ripgrep fd fzf jq lazygit mosh starship btop fastfetch || {
        print_warning "Some brew packages may have failed"
    }
    brew install --cask iterm2 visual-studio-code 2>/dev/null || true

    # Tiling WM stack (macOS only)
    print_step "Installing tiling WM tools..."
    brew install koekeishiya/formulae/yabai 2>/dev/null || true
    brew install koekeishiya/formulae/skhd 2>/dev/null || true
    brew install --cask sol 2>/dev/null || true

    # Nerd Font via Homebrew (for iTerm2)
    brew tap homebrew/cask-fonts 2>/dev/null || true
    brew install --cask font-jetbrains-mono-nerd-font 2>/dev/null || true

elif [[ "$OS" == "debian" ]]; then
    # Ubuntu/Debian
    sudo apt update
    sudo apt install -y curl wget git unzip ripgrep fd-find fzf jq build-essential make neovim tmux xclip mosh || {
        print_warning "Some apt packages may have failed"
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

    if [ ! -f "JetBrainsMonoNerdFont-Regular.ttf" ]; then
        if download_with_retry \
            "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip" \
            "JetBrainsMono.zip"; then
            # Verify zip integrity before extracting
            if unzip -tq JetBrainsMono.zip > /dev/null 2>&1; then
                unzip -qo JetBrainsMono.zip
                rm -f JetBrainsMono.zip
            else
                print_warning "Font zip corrupted, removing"
                rm -f JetBrainsMono.zip
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
# SETUP VS CODE CONFIG
# ============================================================================
print_step "Setting up VS Code config..."

if [[ "$OS" == "mac" ]]; then
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
else
    VSCODE_USER_DIR="$HOME/.config/Code/User"
fi

mkdir -p "$VSCODE_USER_DIR"

for config_file in settings.json keybindings.json; do
    src="$REPO_DIR/vscode/$config_file"
    dst="$VSCODE_USER_DIR/$config_file"

    if [ -f "$src" ]; then
        if [ -f "$dst" ] && [ ! -L "$dst" ]; then
            cp "$dst" "$dst.bak"
        fi

        if ln -sf "$src" "$dst"; then
            print_success "VS Code $config_file linked"
        else
            print_error "Failed to link VS Code $config_file"
        fi
    else
        print_warning "Missing VS Code file: $src"
    fi
done

VSCODE_BIN=""
if command -v code &> /dev/null; then
    VSCODE_BIN="$(command -v code)"
elif [[ "$OS" == "mac" ]] && [ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
    VSCODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi

if [ -n "$VSCODE_BIN" ] && [ -f "$REPO_DIR/vscode/extensions.txt" ]; then
    print_step "Installing VS Code extensions..."
    while IFS= read -r extension || [ -n "$extension" ]; do
        [ -z "$extension" ] && continue
        "$VSCODE_BIN" --install-extension "$extension" --force > /dev/null 2>&1 || \
            print_warning "Failed to install VS Code extension: $extension"
    done < "$REPO_DIR/vscode/extensions.txt"
    print_success "VS Code extensions processed"
else
    print_warning "VS Code CLI 'code' not found - install extensions later from $REPO_DIR/vscode/extensions.txt"
fi

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
# SETUP ITERM2 PROFILE
# ============================================================================
if [[ "$OS" == "mac" ]]; then
    print_step "Setting up iTerm2 profile..."

    ITERM2_PROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    mkdir -p "$ITERM2_PROFILES_DIR"

    if [ -f "$REPO_DIR/iterm2/etabli.json" ]; then
        if [ -f "$ITERM2_PROFILES_DIR/etabli.json" ] && [ ! -L "$ITERM2_PROFILES_DIR/etabli.json" ]; then
            print_warning "Backing up existing iTerm2 profile"
            cp "$ITERM2_PROFILES_DIR/etabli.json" "$ITERM2_PROFILES_DIR/etabli.json.bak"
        fi

        if ln -sf "$REPO_DIR/iterm2/etabli.json" "$ITERM2_PROFILES_DIR/etabli.json"; then
            print_success "iTerm2 dynamic profile linked"
        else
            print_error "Failed to create iTerm2 profile symlink"
        fi
    else
        print_warning "iTerm2 profile not found in $REPO_DIR/iterm2/"
    fi
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

# damage-control-rules.json (global safety rules)
if [ -f "$REPO_DIR/pi/damage-control-rules.json" ]; then
    ln -sf "$REPO_DIR/pi/damage-control-rules.json" ~/.pi/damage-control-rules.json
    print_success "Pi damage-control-rules.json linked"
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
fi

# Themes
for theme_file in "$REPO_DIR/pi/themes"/*.json; do
    if [ -f "$theme_file" ]; then
        theme_name=$(basename "$theme_file")
        ln -sf "$theme_file" ~/.pi/agent/themes/"$theme_name"
        print_success "Pi theme '$theme_name' linked"
    fi
done

# Custom skills (plan workflow, review)
for skill_dir in "$REPO_DIR/pi/skills"/*/; do
    if [ -d "$skill_dir" ]; then
        skill_name=$(basename "$skill_dir")
        ln -sfn "$skill_dir" ~/.pi/agent/skills/"$skill_name"
        print_success "Pi skill '$skill_name' linked"
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

# Shared skills from etabli/skills/ (only if not already linked in Pi)
for shared_skill in vercel-react-best-practices web-design-guidelines; do
    if [ -d "$REPO_DIR/skills/$shared_skill" ] && [ ! -e ~/.pi/agent/skills/"$shared_skill" ]; then
        ln -sfn "$REPO_DIR/skills/$shared_skill" ~/.pi/agent/skills/"$shared_skill"
        print_success "Pi shared skill '$shared_skill' linked"
    fi
done

# Install Pi if not present
if ! command -v pi &> /dev/null; then
    print_step "Installing Pi Coding Agent..."
    npm install -g @mariozechner/pi-coding-agent && \
        print_success "Pi installed" || \
        print_warning "Pi install failed (npm i -g @mariozechner/pi-coding-agent)"
fi

# Install packages (core + agentic plugins)
if command -v pi &> /dev/null; then
    print_step "Installing Pi packages..."
    pi install npm:mitsupi 2>/dev/null && print_success "mitsupi installed" || true
    pi install npm:pi-hooks 2>/dev/null && print_success "pi-hooks installed" || true
    pi install npm:checkpoint 2>/dev/null && print_success "checkpoint installed" || true
    pi install npm:pi-notify 2>/dev/null && print_success "pi-notify installed" || true
    pi install git:github.com/badlogic/pi-skills 2>/dev/null && print_success "pi-skills installed" || true
fi

# Symlink node_modules into extensions dir so createRequire() can resolve npm packages (e.g. mitsupi)
if [ -d ~/.pi/npm/node_modules ] && [ -d "$REPO_DIR/pi/extensions" ]; then
    ln -sfn ~/.pi/npm/node_modules "$REPO_DIR/pi/extensions/node_modules"
    print_success "Pi extensions node_modules linked"
fi

# ============================================================================
# SETUP TILING WM (macOS only)
# ============================================================================
if [[ "$OS" == "mac" ]]; then
    print_step "Setting up tiling WM configs..."

    # Yabai
    mkdir -p ~/.config/yabai
    if [ -f "$REPO_DIR/yabai/yabairc" ]; then
        ln -sf "$REPO_DIR/yabai/yabairc" ~/.config/yabai/yabairc
        chmod +x ~/.config/yabai/yabairc
        print_success "Yabai config linked"
    fi

    # skhd
    mkdir -p ~/.config/skhd
    if [ -f "$REPO_DIR/skhd/skhdrc" ]; then
        ln -sf "$REPO_DIR/skhd/skhdrc" ~/.config/skhd/skhdrc
        print_success "skhd config linked"
    fi

    # Starship
    if [ -f "$REPO_DIR/starship/starship.toml" ]; then
        ln -sf "$REPO_DIR/starship/starship.toml" ~/.config/starship.toml
        print_success "Starship config linked"
    fi

    # Add starship init to zshrc if not present
    if [ -f ~/.zshrc ] && ! grep -q 'starship init' ~/.zshrc 2>/dev/null; then
        echo 'eval "$(starship init zsh)"' >> ~/.zshrc
        print_success "Starship init added to .zshrc"
    fi

    # btop
    mkdir -p ~/.config/btop/themes
    if [ -f "$REPO_DIR/btop/btop.conf" ]; then
        ln -sf "$REPO_DIR/btop/btop.conf" ~/.config/btop/btop.conf
        print_success "btop config linked"
    fi
    if [ -f "$REPO_DIR/btop/themes/catppuccin_mocha.theme" ]; then
        ln -sf "$REPO_DIR/btop/themes/catppuccin_mocha.theme" ~/.config/btop/themes/catppuccin_mocha.theme
        print_success "btop Catppuccin theme linked"
    fi

    # fastfetch
    mkdir -p ~/.config/fastfetch
    if [ -f "$REPO_DIR/fastfetch/config.jsonc" ]; then
        ln -sf "$REPO_DIR/fastfetch/config.jsonc" ~/.config/fastfetch/config.jsonc
        print_success "fastfetch config linked"
    fi

    # Start tiling services
    print_step "Starting tiling WM services..."
    yabai --start-service 2>/dev/null || true
    skhd --start-service 2>/dev/null || true
    print_success "Tiling WM services started"
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
install_script "iterm2-tmux.sh" || true

if [[ "$OS" == "mac" ]]; then
    install_script "open-iterm2.sh" || true
    install_script "macos-optimize.sh" || true
    install_script "macos-disk-clean.sh" || true
    install_script "mem-status" || true
    install_script "tiling-toggle.sh" || true
    install_script "yabai-space-local.sh" || true
    install_script "yabai-sudoers-update.sh" || true
fi

# Add ~/.local/bin to PATH in shell configs (if not already present)
for rcfile in ~/.bashrc ~/.zshrc; do
    if [ -f "$rcfile" ] || [ "$rcfile" = ~/.zshrc ]; then
        if ! grep -q '\$HOME/.local/bin' "$rcfile" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rcfile" 2>/dev/null || true
        fi
    fi
done

print_success "Dev scripts installed"

if [[ "$OS" == "mac" ]] && [ -x "$HOME/.local/bin/yabai-space-local.sh" ]; then
    "$HOME/.local/bin/yabai-space-local.sh" ensure >/dev/null 2>&1 || \
        print_warning "Could not converge spaces to 5 per display automatically"
fi

# ============================================================================
# SETUP GITHUB COPILOT
# ============================================================================
echo ""
print_step "GitHub Copilot setup..."
echo ""
printf "  To enable Copilot:\n"
if [ -n "$VSCODE_BIN" ]; then
    printf "  1. Open VS Code: ${YELLOW}code .${NC}\n"
    printf "  2. Install the ${YELLOW}code${NC} shell command from the Command Palette if needed\n"
    printf "  3. Sign in to GitHub / Copilot when prompted\n"
    printf "  4. Verify inline suggestions are enabled\n"
else
    printf "  1. Install VS Code and expose the ${YELLOW}code${NC} CLI\n"
    printf "  2. Open this repo in VS Code\n"
    printf "  3. Install extensions from ${YELLOW}$REPO_DIR/vscode/extensions.txt${NC}\n"
    printf "  4. Sign in to GitHub / Copilot when prompted\n"
fi
printf "  5. In Neovim, run ${YELLOW}:Copilot auth${NC} once after first launch\n"
echo ""

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
if [ -n "$VSCODE_BIN" ]; then
    printf "  2. Start VS Code:    ${YELLOW}code .${NC}\n"
    printf "  3. Auth Copilot:     Sign in inside VS Code\n"
else
    printf "  2. Install VS Code:  Ensure the ${YELLOW}code${NC} CLI is available\n"
    printf "  3. Open the repo:    Open it manually in VS Code\n"
fi
printf "  4. Start Neovim:     ${YELLOW}nvim${NC}\n"
printf "  5. Auth Copilot:     ${YELLOW}:Copilot auth${NC} in Neovim\n"
printf "  6. Start Tmux:       ${YELLOW}tmux${NC}\n"
printf "  7. Install plugins:  ${YELLOW}prefix + I${NC} (Ctrl+b then I)\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
printf "  ${BLUE}Remote Connection (Mosh):${NC}\n"
printf "  From your Mac:   ${YELLOW}mosh user@your-vps.com${NC}\n"
printf "  Firewall VPS:    ${YELLOW}sudo ufw allow 60000:61000/udp${NC}\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
printf "  ${BLUE}VS Code Defaults (VS Code only):${NC}\n"
printf "  Theme           Catppuccin Mocha\n"
printf "  Font            JetBrainsMono Nerd Font @ 18\n"
printf "  Alt+l           Accept Copilot inline suggestion\n"
printf "  Cmd/Ctrl+P      Quick open\n"
printf "  Cmd/Ctrl+Shift+P Command Palette\n"
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
printf "  Copilot         In cmp menu after :Copilot auth\n"
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
if [[ "$OS" == "mac" ]]; then
printf "  ${BLUE}Tiling WM (macOS) — Manual Steps Required:${NC}\n"
echo ""
printf "  1. ${YELLOW}Partially disable SIP${NC} (Recovery Mode):\n"
printf "     Boot to Recovery > Terminal > csrutil enable --without fs --without debug --without nvram\n"
printf "  2. ${YELLOW}Configure yabai sudoers${NC}:\n"
printf "     ${YELLOW}yabai-sudoers-update.sh${NC}\n"
printf "  3. ${YELLOW}Enable separate Spaces per display${NC} and disable auto-rearrange\n"
printf "     ${YELLOW}macos-optimize.sh apply${NC} handles both defaults for you\n"
printf "  4. ${YELLOW}Hide macOS menu bar${NC} (System Settings > Control Center > Menu Bar Only)\n"
printf "  5. ${YELLOW}Configure Sol hotkey${NC} (alt+space) in Sol preferences\n"
printf "  6. ${YELLOW}Apply performance optimizations${NC}:\n"
printf "     ${YELLOW}macos-optimize.sh apply${NC}\n"
printf "  7. ${YELLOW}Converge spaces to 5 per display${NC} if needed:\n"
printf "     ${YELLOW}yabai-space-local.sh ensure${NC}\n"
echo ""
printf "  ${BLUE}Tiling WM Shortcuts:${NC}\n"
printf "  alt+1..5        Switch workspace on focused display\n"
printf "  alt+arrows      Focus window direction\n"
printf "  alt+shift+arrows Swap windows\n"
printf "  alt+return      Open iTerm2\n"
printf "  alt+w           Close window\n"
printf "  alt+f           Toggle fullscreen\n"
printf "  alt+t           Toggle float\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
fi
printf "  ${BLUE}Pi Coding Agent:${NC}\n"
printf "  Start:           ${YELLOW}pi${NC}\n"
printf "  Auth providers:  ${YELLOW}/login${NC}\n"
printf "  Plan:            ${YELLOW}/skill:plan${NC}\n"
printf "  Plan review:     ${YELLOW}/skill:plan-review${NC}\n"
printf "  Implement:       ${YELLOW}/skill:implement${NC}\n"
printf "  Plan loop:       ${YELLOW}/skill:plan-loop${NC}\n"
printf "  Plan implement:  ${YELLOW}/skill:plan-implement${NC}\n"
printf "  Code review:     ${YELLOW}Ctrl+R${NC} (mitsupi)\n"
printf "  Handoff:         ${YELLOW}/handoff${NC}\n"
printf "  Impl handoff:    ${YELLOW}/handoff-implement${NC}\n"
printf "  TDD loop:        ${YELLOW}/loop tests${NC} (mitsupi)\n"
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
