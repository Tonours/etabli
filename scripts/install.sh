#!/bin/bash

# ============================================================================
# NEOVIM + TMUX SETUP
# Compatible: macOS, Linux (Ubuntu/Debian), Remote (SSH)
# ============================================================================

set -e

# ============================================================================
# VERSIONS (centralized for maintenance)
# ============================================================================
readonly NVM_VERSION="v0.40.1"
readonly NVIM_VERSION="v0.11.0"
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
if [ ! -d "$REPO_DIR/nvim" ]; then
    print_warning "Missing nvim config at $REPO_DIR/nvim - it will not be copied"
fi
if [ ! -f "$REPO_DIR/tmux.conf" ]; then
    print_warning "Missing tmux.conf at $REPO_DIR/tmux.conf - it will not be copied"
fi

echo ""
echo "-------------------------------------------------------------------"
echo "  Neovim + Tmux Setup"
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

    # Tiling WM stack (macOS only)
    print_step "Installing tiling WM tools..."
    brew install koekeishiya/formulae/yabai 2>/dev/null || true
    brew install koekeishiya/formulae/skhd 2>/dev/null || true
    brew install FelixKratz/formulae/sketchybar 2>/dev/null || true
    brew install FelixKratz/formulae/borders 2>/dev/null || true
    brew install --cask sol 2>/dev/null || true

    # Nerd Font via Homebrew (for Ghostty)
    brew tap homebrew/cask-fonts 2>/dev/null || true
    brew install --cask font-jetbrains-mono-nerd-font 2>/dev/null || true

elif [[ "$OS" == "debian" ]]; then
    # Ubuntu/Debian
    sudo apt update
    sudo apt install -y curl wget git unzip ripgrep fd-find fzf jq build-essential tmux xclip mosh || {
        print_warning "Some apt packages may have failed"
    }

    # fd symlink
    if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd || print_warning "Could not create fd symlink"
    fi

    # Neovim (0.11+ required for LazyVim)
    print_step "Installing Neovim ${NVIM_VERSION}..."
    (
        cd /tmp || exit 1
        if download_with_retry \
            "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
            "nvim-linux-x86_64.tar.gz"; then
            sudo rm -rf /opt/nvim
            sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
            sudo mv /opt/nvim-linux-x86_64 /opt/nvim
            rm -f nvim-linux-x86_64.tar.gz
        fi
    )

    # Add to PATH
    if ! grep -q '/opt/nvim/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH="/opt/nvim/bin:$PATH"' >> ~/.bashrc
    fi
    if ! grep -q '/opt/nvim/bin' ~/.zshrc 2>/dev/null; then
        echo 'export PATH="/opt/nvim/bin:$PATH"' >> ~/.zshrc
    fi
    export PATH="/opt/nvim/bin:$PATH"

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
    sudo dnf install -y neovim tmux git ripgrep fd-find fzf || {
        print_warning "Some dnf packages may have failed"
    }
fi

print_success "Dependencies installed"

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
    prettier \
    eslint \
    @tailwindcss/language-server \
    neovim; then
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
# SETUP NEOVIM CONFIG (LazyVim)
# ============================================================================
print_step "Setting up Neovim config (LazyVim)..."

# Backup existing config (skip if already a symlink to this repo)
if [ -d ~/.config/nvim ] && [ ! -L ~/.config/nvim ]; then
    print_warning "Backing up existing config to ~/.config/nvim.bak"
    rm -rf ~/.config/nvim.bak
    mv ~/.config/nvim ~/.config/nvim.bak
    # Clean plugin cache on fresh install
    rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
elif [ -L ~/.config/nvim ]; then
    print_success "nvim config already linked"
fi

# Symlink config
if [ -d "$REPO_DIR/nvim" ]; then
    if ln -sfn "$REPO_DIR/nvim" ~/.config/nvim; then
        print_success "LazyVim config linked"
    else
        print_error "Failed to link nvim config"
    fi
else
    print_warning "nvim folder not found in $REPO_DIR, please link manually"
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
# SETUP GHOSTTY CONFIG
# ============================================================================
print_step "Setting up Ghostty config..."

mkdir -p ~/.config/ghostty

if [ -f "$REPO_DIR/ghostty/config" ]; then
    # Backup if target is a regular file (not a symlink)
    if [ -f ~/.config/ghostty/config ] && [ ! -L ~/.config/ghostty/config ]; then
        print_warning "Backing up existing ghostty config"
        cp ~/.config/ghostty/config ~/.config/ghostty/config.bak
    fi

    if ln -sf "$REPO_DIR/ghostty/config" ~/.config/ghostty/config; then
        print_success "Ghostty config linked"
    else
        print_error "Failed to create ghostty symlink"
    fi
else
    print_warning "Ghostty config not found in $REPO_DIR/ghostty/"
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

# Link extensions directories for relative-path portability in settings
if [ -d "$REPO_DIR/pi/extensions" ]; then
    if [ -d ~/.pi/extensions ] && [ ! -L ~/.pi/extensions ]; then
        mv ~/.pi/extensions ~/.pi/extensions.bak
    fi
    if [ -d ~/.pi/agent/extensions ] && [ ! -L ~/.pi/agent/extensions ]; then
        mv ~/.pi/agent/extensions ~/.pi/agent/extensions.bak
    fi
    ln -sfn "$REPO_DIR/pi/extensions" ~/.pi/extensions
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
    if [ -f ~/.pi/agent/settings.json ] && [ ! -L ~/.pi/agent/settings.json ]; then
        cp ~/.pi/agent/settings.json ~/.pi/agent/settings.json.bak
    fi
    ln -sf "$REPO_DIR/pi/agent/settings.json" ~/.pi/agent/settings.json
    print_success "Pi agent settings.json linked"
fi

# Themes
for theme_file in "$REPO_DIR/pi/themes"/*.json; do
    if [ -f "$theme_file" ]; then
        theme_name=$(basename "$theme_file")
        ln -sf "$theme_file" ~/.pi/agent/themes/"$theme_name"
        print_success "Pi theme '$theme_name' linked"
    fi
done

# Custom skills (plan, verify)
for skill_dir in "$REPO_DIR/pi/skills"/*/; do
    if [ -d "$skill_dir" ]; then
        skill_name=$(basename "$skill_dir")
        ln -sfn "$skill_dir" ~/.pi/agent/skills/"$skill_name"
        print_success "Pi skill '$skill_name' linked"
    fi
done

# Shared skills from etabli/skills/ (only if not already in ~/.agents/skills/)
for shared_skill in vercel-react-best-practices web-design-guidelines; do
    if [ -d "$REPO_DIR/skills/$shared_skill" ] && [ ! -e ~/.agents/skills/"$shared_skill" ]; then
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
    pi install npm:checkpoint 2>/dev/null && print_success "checkpoint installed" || true
    pi install npm:pi-notify 2>/dev/null && print_success "pi-notify installed" || true
    pi install git:github.com/ogulcancelik/pi-ghostty-theme-sync 2>/dev/null && print_success "pi-ghostty-theme-sync installed" || true
    pi install git:github.com/badlogic/pi-skills 2>/dev/null && print_success "pi-skills installed" || true
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

    # SketchyBar (directory symlink)
    if [ -d "$REPO_DIR/sketchybar" ]; then
        if [ -d ~/.config/sketchybar ] && [ ! -L ~/.config/sketchybar ]; then
            mv ~/.config/sketchybar ~/.config/sketchybar.bak
        fi
        ln -sfn "$REPO_DIR/sketchybar" ~/.config/sketchybar
        print_success "SketchyBar config linked"
    fi

    # JankyBorders
    mkdir -p ~/.config/borders
    if [ -f "$REPO_DIR/borders/bordersrc" ]; then
        ln -sf "$REPO_DIR/borders/bordersrc" ~/.config/borders/bordersrc
        print_success "JankyBorders config linked"
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
    brew services start sketchybar 2>/dev/null || true
    brew services start borders 2>/dev/null || true
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
install_script "cw" || true
install_script "cw-clean" || true
install_script "nightshift" || true
install_script "agent-scorecard" || true
install_script "agent-fanout" || true

if [[ "$OS" == "mac" ]]; then
    install_script "macos-optimize.sh" || true
    install_script "tiling-toggle.sh" || true
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

# ============================================================================
# SETUP GITHUB COPILOT
# ============================================================================
echo ""
print_step "GitHub Copilot setup..."
echo ""
printf "  To enable Copilot:\n"
printf "  1. Open Neovim: ${YELLOW}nvim${NC}\n"
printf "  2. Wait for plugins to install\n"
printf "  3. Run: ${YELLOW}:Copilot auth${NC}\n"
printf "  4. Follow the instructions (GitHub login)\n"
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
printf "  2. Start Neovim:     ${YELLOW}nvim${NC} (plugins auto-install)\n"
printf "  3. Auth Copilot:     ${YELLOW}:Copilot auth${NC}\n"
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
printf "  ${BLUE}Neovim Shortcuts:${NC}\n"
printf "  <Space>         Leader key\n"
printf "  <Space>e        File explorer\n"
printf "  <Space>ff       Find files\n"
printf "  <Space>fg       Grep\n"
printf "  Alt+l           Accept Copilot suggestion\n"
printf "  <Space>cp       Copilot panel\n"
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
printf "  3. ${YELLOW}Create 5+ Mission Control Spaces${NC} (System Settings > Desktop & Dock)\n"
printf "     Also disable: \"Automatically rearrange Spaces based on most recent use\"\n"
printf "  4. ${YELLOW}Hide macOS menu bar${NC} (System Settings > Control Center > Menu Bar Only)\n"
printf "  5. ${YELLOW}Configure Sol hotkey${NC} (alt+space) in Sol preferences\n"
printf "  6. ${YELLOW}Apply performance optimizations${NC}:\n"
printf "     ${YELLOW}macos-optimize.sh apply${NC}\n"
echo ""
printf "  ${BLUE}Tiling WM Shortcuts:${NC}\n"
printf "  alt+1..9        Switch workspace\n"
printf "  alt+arrows      Focus window direction\n"
printf "  alt+shift+arrows Swap windows\n"
printf "  alt+return      Open Ghostty\n"
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
printf "  Verify:          ${YELLOW}/skill:verify${NC}\n"
printf "  Code review:     ${YELLOW}Ctrl+R${NC} (mitsupi)\n"
printf "  TDD loop:        ${YELLOW}/loop tests${NC} (mitsupi)\n"
printf "  Switch model:    ${YELLOW}Ctrl+P${NC}\n"
echo ""
echo "-------------------------------------------------------------------"
echo ""
