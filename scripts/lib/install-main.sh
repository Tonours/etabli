#!/bin/bash

# ============================================================================
# ETABLI DEV SETUP
# Compatible: macOS, Linux (Ubuntu/Debian), Remote (SSH)
# ============================================================================

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)"
. "$BOOTSTRAP_DIR/lib/pi-paths.sh"
. "$BOOTSTRAP_DIR/lib/prefer-cursor-agent.sh"
. "$BOOTSTRAP_DIR/lib/managed-surfaces.sh"

# ============================================================================
# VERSIONS (centralized for maintenance)
# ============================================================================
readonly NERD_FONT_VERSION="v3.4.0"
readonly MIN_NVIM_VERSION="0.12.2"
readonly PI_AGENT_NPM_PINS=(
    "vscode-languageserver-protocol@3.17.5"
)
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
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

backup_path() {
    local path="$1"
    local candidate="${path}.bak.${TIMESTAMP}"
    local index=1

    while [ -e "$candidate" ]; do
        candidate="${path}.bak.${TIMESTAMP}.${index}"
        index=$((index + 1))
    done

    printf '%s\n' "$candidate"
}

backup_file() {
    local path="$1"
    local backup

    backup="$(backup_path "$path")"
    cp -R "$path" "$backup"
    print_warning "Existing file backed up to $backup"
}

backup_path_move() {
    local path="$1"
    local backup

    backup="$(backup_path "$path")"
    mv "$path" "$backup"
    print_warning "Existing path moved to $backup"
}

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

install_npm_global_binary_link() {
    local binary="$1"
    local prefix target

    if command -v "$binary" >/dev/null 2>&1; then
        print_success "$binary available"
        return 0
    fi

    prefix="$("${NPM_CMD[@]}" config get prefix 2>/dev/null || true)"
    if [ -z "$prefix" ]; then
        print_warning "Could not resolve npm prefix for $binary"
        return 1
    fi

    target="$prefix/bin/$binary"
    if [ ! -x "$target" ]; then
        print_warning "$binary not found after npm install"
        return 1
    fi

    mkdir -p "$HOME/.local/bin"
    ln -sf "$target" "$HOME/.local/bin/$binary"
    print_success "$binary linked into ~/.local/bin"
}

sync_nvim_plugins() {
    if ! command -v nvim &>/dev/null; then
        print_warning "Neovim not available - skipping plugin sync"
        return 0
    fi

    ensure_nvim_version || print_warning "Install Neovim $MIN_NVIM_VERSION+ before relying on this config"

    print_step "Installing Neovim plugins through vim.pack..."
    if nvim --headless +qa >/dev/null 2>&1; then
        print_success "Neovim plugins installed"
    else
        print_warning "Neovim plugin install failed - run: nvim --headless +qa"
    fi

    if nvim --headless "+lua vim.notify = function() end" +qa >/dev/null 2>&1; then
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

if [ "${ETABLI_INSTALL_HELPER_SMOKE:-}" = "1" ]; then
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT
    original_path="$PATH"

    first_backup="$tmp_dir/settings.json.bak.${TIMESTAMP}"
    second_backup="$tmp_dir/settings.json.bak.${TIMESTAMP}.1"
    : >"$first_backup"

    computed_backup="$(backup_path "$tmp_dir/settings.json")"
    if [ "$computed_backup" != "$second_backup" ]; then
        print_error "backup_path did not avoid an existing backup path"
        exit 1
    fi

    smoke_repo_dir="$(cd "$BOOTSTRAP_DIR/.." >/dev/null 2>&1 && pwd)"
    smoke_agent_home="$tmp_dir/agent-home"
    smoke_personal_target="$tmp_dir/personal-agent.md"
    mkdir -p "$smoke_agent_home/.claude/agents"
    printf '%s\n' 'personal agent' >"$smoke_personal_target"
    ln -s "$smoke_repo_dir/claude/agents/removed-agent.md" \
        "$smoke_agent_home/.claude/agents/removed-agent.md"
    ln -s "$smoke_personal_target" \
        "$smoke_agent_home/.claude/agents/personal.md"
    managed_surface_prune_stale_claude_agents install "$smoke_repo_dir" "$smoke_agent_home"
    if [ -L "$smoke_agent_home/.claude/agents/removed-agent.md" ]; then
        print_error "stale managed Claude agent link was not removed"
        exit 1
    fi
    if [ ! -L "$smoke_agent_home/.claude/agents/personal.md" ]; then
        print_error "personal Claude agent link was removed"
        exit 1
    fi

    smoke_command_home="$tmp_dir/command-home"
    smoke_external_command="$tmp_dir/external-command.md"
    mkdir -p "$smoke_command_home/.claude/commands"
    printf '%s\n' 'personal command' >"$smoke_command_home/.claude/commands/recap.md"
    printf '%s\n' 'external command' >"$smoke_external_command"
    ln -s "$smoke_external_command" \
        "$smoke_command_home/.claude/commands/commit.md"
    ln -s "$smoke_repo_dir/claude/commands/plan.md" \
        "$smoke_command_home/.claude/commands/plan.md"
    managed_surface_remove_exact_link install \
        "$smoke_command_home/.claude/commands/plan.md" \
        "stale Claude command plan.md" \
        "$smoke_repo_dir/claude/commands/plan.md" \
        "$smoke_repo_dir/claude/scopes/shared/commands/plan.md"
    managed_surface_remove_exact_link install \
        "$smoke_command_home/.claude/commands/commit.md" \
        "stale Claude command commit.md" \
        "$smoke_repo_dir/claude/commands/commit.md" \
        "$smoke_repo_dir/claude/scopes/shared/commands/commit.md"
    managed_surface_remove_exact_link install \
        "$smoke_command_home/.claude/commands/recap.md" \
        "stale Claude command recap.md" \
        "$smoke_repo_dir/claude/commands/recap.md" \
        "$smoke_repo_dir/claude/scopes/shared/commands/recap.md"
    if [ -L "$smoke_command_home/.claude/commands/plan.md" ]; then
        print_error "stale managed Claude command link was not removed"
        exit 1
    fi
    if [ ! -L "$smoke_command_home/.claude/commands/commit.md" ]; then
        print_error "external Claude command link was removed"
        exit 1
    fi
    if [ ! -f "$smoke_command_home/.claude/commands/recap.md" ]; then
        print_error "personal Claude command file was removed"
        exit 1
    fi

    smoke_skill_home="$tmp_dir/skill-home"
    smoke_unmanaged_skill="$tmp_dir/unmanaged-skill"
    mkdir -p "$smoke_skill_home/.claude/skills" "$smoke_unmanaged_skill"
    ln -s "$smoke_repo_dir/claude/scopes/shared/skills/removed-skill" \
        "$smoke_skill_home/.claude/skills/removed-scope-skill"
    ln -s "$smoke_repo_dir/vendor/ember-skills/skills/removed-skill" \
        "$smoke_skill_home/.claude/skills/removed-vendor-skill"
    ln -s "$smoke_repo_dir/pi/skills/removed-skill" \
        "$smoke_skill_home/.claude/skills/removed-pi-skill"
    ln -s "$smoke_unmanaged_skill" \
        "$smoke_skill_home/.claude/skills/unmanaged-skill"
    smoke_relative_target="$smoke_skill_home/.agents/skills/relative-live"
    mkdir -p "$smoke_relative_target"
    ln -s "../../.agents/skills/relative-live" \
        "$smoke_skill_home/.claude/skills/relative-live"
    ln -s "../../.agents/skills/relative-gone" \
        "$smoke_skill_home/.claude/skills/relative-dangling"
    smoke_relative_managed_root="$smoke_skill_home/relative-repo/pi/skills"
    mkdir -p "$smoke_relative_managed_root"
    ln -s "../../relative-repo/pi/skills/relative-managed-gone" \
        "$smoke_skill_home/.claude/skills/relative-managed-dangling"
    for smoke_live_skill in \
        "pi/skills/design-suite" \
        "vendor/ember-skills/skills/ember-employer-suite" \
        "pi/skills/react-doctor-100"; do
        ln -s "$smoke_repo_dir/$smoke_live_skill" \
            "$smoke_skill_home/.claude/skills/$(basename "$smoke_live_skill")"
    done

    for smoke_other_surface in .pi/agent/skills .codex/skills .config/devin/skills .agents/skills; do
        mkdir -p "$smoke_skill_home/$smoke_other_surface"
        ln -s "$smoke_repo_dir/vendor/ember-skills/skills/removed-skill" \
            "$smoke_skill_home/$smoke_other_surface/removed-vendor-skill"
        ln -s "$smoke_repo_dir/vendor/ember-skills/skills/ember-employer-suite" \
            "$smoke_skill_home/$smoke_other_surface/ember-employer-suite"
    done

    managed_surface_prune_stale_skill_links install "$smoke_repo_dir" "$smoke_skill_home"

    for smoke_other_surface in .pi/agent/skills .codex/skills .config/devin/skills .agents/skills; do
        if [ -L "$smoke_skill_home/$smoke_other_surface/removed-vendor-skill" ]; then
            print_error "stale vendor skill link survived in $smoke_other_surface"
            exit 1
        fi
        if [ ! -L "$smoke_skill_home/$smoke_other_surface/ember-employer-suite" ]; then
            print_error "live vendor skill link was removed from $smoke_other_surface"
            exit 1
        fi
    done

    for smoke_stale_skill in removed-scope-skill removed-vendor-skill removed-pi-skill; do
        if [ -L "$smoke_skill_home/.claude/skills/$smoke_stale_skill" ]; then
            print_error "stale managed Claude skill link '$smoke_stale_skill' was not removed"
            exit 1
        fi
    done
    if [ ! -L "$smoke_skill_home/.claude/skills/unmanaged-skill" ]; then
        print_error "unmanaged Claude skill link was removed"
        exit 1
    fi
    for smoke_relative_link in relative-live relative-dangling relative-managed-dangling; do
        if [ ! -L "$smoke_skill_home/.claude/skills/$smoke_relative_link" ]; then
            print_error "relative link '$smoke_relative_link' was removed by an unrelated repo root"
            exit 1
        fi
    done

    managed_surface_prune_stale_skill_links install "$smoke_skill_home/relative-repo" "$smoke_skill_home"

    if [ -L "$smoke_skill_home/.claude/skills/relative-managed-dangling" ]; then
        print_error "stale relative link under a managed root was not removed"
        exit 1
    fi

    smoke_symlinked_repo="$tmp_dir/symlinked-repo"
    ln -s "$smoke_skill_home/relative-repo" "$smoke_symlinked_repo"
    ln -s "$smoke_symlinked_repo/pi/skills/symlinked-gone" \
        "$smoke_skill_home/.claude/skills/symlinked-repo-dangling"
    managed_surface_prune_stale_skill_links install "$smoke_skill_home/relative-repo" "$smoke_skill_home"
    if [ -L "$smoke_skill_home/.claude/skills/symlinked-repo-dangling" ]; then
        print_error "stale link reached through a symlinked repo path was not removed"
        exit 1
    fi

    smoke_wholesale_repo="$tmp_dir/wholesale-repo"
    mkdir -p "$smoke_wholesale_repo/pi/skills" "$smoke_wholesale_repo/claude/scopes" \
        "$smoke_wholesale_repo/vendor/gone-vendor/skills/orphan"
    ln -s "$smoke_wholesale_repo/vendor/gone-vendor/skills/orphan" \
        "$smoke_skill_home/.claude/skills/wholesale-orphan"
    ln -s "$tmp_dir/outside-any-repo/skills/keep-me" \
        "$smoke_skill_home/.claude/skills/outside-repo-dangling"
    rm -rf "$smoke_wholesale_repo/vendor/gone-vendor"
    managed_surface_prune_stale_skill_links install "$smoke_wholesale_repo" "$smoke_skill_home"
    if [ -L "$smoke_skill_home/.claude/skills/wholesale-orphan" ]; then
        print_error "stale link under a wholesale-removed vendor tree was not removed"
        exit 1
    fi
    if [ ! -L "$smoke_skill_home/.claude/skills/outside-repo-dangling" ]; then
        print_error "dangling link outside every managed repo root was removed"
        exit 1
    fi
    for smoke_relative_link in relative-live relative-dangling; do
        if [ ! -L "$smoke_skill_home/.claude/skills/$smoke_relative_link" ]; then
            print_error "unmanaged relative link '$smoke_relative_link' was removed"
            exit 1
        fi
    done
    for smoke_kept_skill in design-suite ember-employer-suite react-doctor-100; do
        if [ ! -L "$smoke_skill_home/.claude/skills/$smoke_kept_skill" ]; then
            print_error "live managed Claude skill link '$smoke_kept_skill' was removed"
            exit 1
        fi
    done

    PATH="/tmp/asdf-shims:/usr/bin"
    append_path_entry "/tmp/local-bin"
    if [ "$PATH" != "/tmp/asdf-shims:/usr/bin:/tmp/local-bin" ]; then
        print_error "append_path_entry did not preserve existing PATH precedence"
        exit 1
    fi

    append_path_entry "/tmp/local-bin"
    if [ "$PATH" != "/tmp/asdf-shims:/usr/bin:/tmp/local-bin" ]; then
        print_error "append_path_entry duplicated an existing PATH entry"
        exit 1
    fi

    PATH=""
    append_path_entry "/tmp/local-bin"
    if [ "$PATH" != "/tmp/local-bin" ]; then
        print_error "append_path_entry did not initialize an empty PATH"
        exit 1
    fi
    PATH="$original_path"

    rcfile="$tmp_dir/zshrc"
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >"$rcfile"
    ensure_local_bin_shell_path "$rcfile"
    desired_rc_line='case ":${PATH:-}:" in *":$HOME/.local/bin:"*) ;; *) export PATH="${PATH:+$PATH:}$HOME/.local/bin" ;; esac'
    if ! grep -Fxq "$desired_rc_line" "$rcfile"; then
        print_error "ensure_local_bin_shell_path did not install the order-preserving PATH line"
        exit 1
    fi
    if grep -Fxq 'export PATH="$HOME/.local/bin:$PATH"' "$rcfile"; then
        print_error "ensure_local_bin_shell_path kept the legacy PATH-prepending line"
        exit 1
    fi

    symlink_target="$tmp_dir/linked-zshrc-target"
    symlink_rc="$tmp_dir/linked-zshrc"
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >"$symlink_target"
    ln -s "$symlink_target" "$symlink_rc"
    ensure_local_bin_shell_path "$symlink_rc"
    if [ ! -L "$symlink_rc" ]; then
        print_error "ensure_local_bin_shell_path replaced an rcfile symlink"
        exit 1
    fi
    if ! grep -Fxq "$desired_rc_line" "$symlink_target"; then
        print_error "ensure_local_bin_shell_path did not update the symlink target"
        exit 1
    fi

    smoke_grok_home="$tmp_dir/grok-home"
    mkdir -p "$smoke_grok_home/.grok/bin" "$smoke_grok_home/.local/bin"
    printf 'grok-bin\n' >"$smoke_grok_home/.grok/bin/grok-macos"
    ln -s grok-macos "$smoke_grok_home/.grok/bin/grok"
    ln -s grok-macos "$smoke_grok_home/.grok/bin/agent"
    printf 'cursor-agent\n' >"$smoke_grok_home/.local/bin/agent"
    prefer_cursor_agent_remove_grok_collision "$smoke_grok_home"
    if [ -e "$smoke_grok_home/.grok/bin/agent" ] || [ -L "$smoke_grok_home/.grok/bin/agent" ]; then
        print_error "prefer_cursor_agent_remove_grok_collision left Grok's agent name"
        exit 1
    fi
    if [ ! -L "$smoke_grok_home/.grok/bin/grok" ]; then
        print_error "prefer_cursor_agent_remove_grok_collision removed Grok's grok launcher"
        exit 1
    fi

    smoke_custom_agent="$tmp_dir/custom-grok-agent"
    mkdir -p "$smoke_custom_agent/.grok/bin"
    printf 'custom-agent\n' >"$smoke_custom_agent/.grok/bin/agent"
    printf 'grok-bin\n' >"$smoke_custom_agent/.grok/bin/grok"
    prefer_cursor_agent_remove_grok_collision "$smoke_custom_agent"
    if [ ! -f "$smoke_custom_agent/.grok/bin/agent" ]; then
        print_error "prefer_cursor_agent_remove_grok_collision removed a custom agent file"
        exit 1
    fi

    grok_rc="$tmp_dir/grok-zshrc"
    printf '%s\n' 'export PATH="$HOME/.grok/bin:$PATH"' '# <<< grok installer <<<' >"$grok_rc"
    prefer_cursor_agent_ensure_shell_hook "$grok_rc"
    if ! grep -Fq "$prefer_cursor_agent_hook_begin" "$grok_rc"; then
        print_error "prefer_cursor_agent_ensure_shell_hook did not install the Cursor agent hook"
        exit 1
    fi
    if ! awk -v grok_end="$prefer_cursor_agent_grok_installer_end" -v begin="$prefer_cursor_agent_hook_begin" '
        $0 == grok_end { saw_grok = 1 }
        $0 == begin && saw_grok { found = 1 }
        END { exit !found }
    ' "$grok_rc"; then
        print_error "prefer_cursor_agent_ensure_shell_hook did not follow the Grok installer block"
        exit 1
    fi
    prefer_cursor_agent_ensure_shell_hook "$grok_rc"
    if [ "$(grep -Fc "$prefer_cursor_agent_hook_begin" "$grok_rc")" -ne 1 ]; then
        print_error "prefer_cursor_agent_ensure_shell_hook duplicated the Cursor agent hook"
        exit 1
    fi

    symlink_hook_target="$tmp_dir/linked-hook-zshrc-target"
    symlink_hook_rc="$tmp_dir/linked-hook-zshrc"
    printf '%s\n' 'export PATH="$HOME/.grok/bin:$PATH"' >"$symlink_hook_target"
    ln -s "$symlink_hook_target" "$symlink_hook_rc"
    prefer_cursor_agent_ensure_shell_hook "$symlink_hook_rc"
    if [ ! -L "$symlink_hook_rc" ]; then
        print_error "prefer_cursor_agent_ensure_shell_hook replaced an rcfile symlink"
        exit 1
    fi
    if ! grep -Fq "$prefer_cursor_agent_hook_begin" "$symlink_hook_target"; then
        print_error "prefer_cursor_agent_ensure_shell_hook did not update the symlink target"
        exit 1
    fi

    truncated_rc="$tmp_dir/truncated-zshrc"
    printf '%s\n' 'keep-this-line' "$prefer_cursor_agent_hook_begin" 'export STAY=/should-remain' >"$truncated_rc"
    if prefer_cursor_agent_ensure_shell_hook "$truncated_rc"; then
        print_error "prefer_cursor_agent_ensure_shell_hook accepted a hook with no end marker"
        exit 1
    fi
    if ! grep -Fxq 'keep-this-line' "$truncated_rc" || ! grep -Fxq 'export STAY=/should-remain' "$truncated_rc"; then
        print_error "prefer_cursor_agent_ensure_shell_hook destroyed a truncated rcfile"
        exit 1
    fi
    if grep -Fq "$prefer_cursor_agent_hook_end" "$truncated_rc"; then
        print_error "prefer_cursor_agent_ensure_shell_hook rewrote a truncated hook"
        exit 1
    fi

    smoke_home="$tmp_dir/home"
    mkdir -p "$smoke_home/.pi/agent"
    printf '%s\n' '{"defaultProvider":"custom","defaultModel":"personal-model","defaultThinkingLevel":"low","enabledModels":["custom/personal-model"],"packages":["npm:@agwab/pi-workflow",{"source":"npm:@agwab/pi-workflow@0.7.0"},{"source":"npm:@agwab/pi-workflow-helper"}]}' \
        >"$smoke_home/.pi/agent/settings.json"
    # Resolve a real Node binary before HOME override. asdf shims exit 126 when HOME
    # points at a disposable tree; that is unrelated to settings-sync portability.
    smoke_node_bin="$("${NODE_CMD[@]}" -e 'process.stdout.write(process.execPath)' 2>/dev/null || true)"
    if [ -z "$smoke_node_bin" ] || [ ! -x "$smoke_node_bin" ]; then
        smoke_node_bin="$(command -v node)"
    fi
    NODE_CMD=("$smoke_node_bin")
    HOME="$smoke_home"
    REPO_DIR="$(cd "$BOOTSTRAP_DIR/.." >/dev/null 2>&1 && pwd)"
    converge_agent_surfaces >/dev/null
    "${NODE_CMD[@]}" - "$smoke_home/.pi/agent/settings.json" <<'NODE'
const fs = require("node:fs");
const settings = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const sources = settings.packages.map((entry) => typeof entry === "string" ? entry : entry.source);
if (!sources.includes("npm:@tintinweb/pi-tasks@0.7.1")) {
  throw new Error("settings sync did not add a pinned tracked source");
}
if (sources.some((source) => source === "npm:@agwab/pi-workflow" || source.startsWith("npm:@agwab/pi-workflow@"))) {
  throw new Error("settings sync kept a removed pi-workflow source");
}
if (!sources.includes("npm:@agwab/pi-workflow-helper")) {
  throw new Error("settings sync removed a similarly named user package");
}
if (
  !settings.enabledModels.includes("custom/personal-model") ||
  !settings.enabledModels.includes("zai/glm-5.2")
) {
  throw new Error("settings sync did not preserve the user model and add tracked model pins");
}
if (settings.defaultProvider !== "custom" || settings.defaultModel !== "personal-model" || settings.defaultThinkingLevel !== "low") {
  throw new Error("settings sync overwrote personal Pi defaults");
}
NODE

    if ! managed_surface_skill_is_shadowed adr "shared work"; then
        print_error "adr must be shadowed while scope work is active"
        exit 1
    fi
    if managed_surface_skill_is_shadowed adr "shared personal"; then
        print_error "adr must deploy when scope work is not active"
        exit 1
    fi
    if managed_surface_skill_is_shadowed adr "shared"; then
        print_error "adr must deploy on a shared-only machine"
        exit 1
    fi
    if managed_surface_skill_is_shadowed conventions "shared work"; then
        print_error "only listed skills are shadowed"
        exit 1
    fi

    smoke_shadow_home="$tmp_dir/shadow-home"
    smoke_shadow_target="$smoke_repo_dir/claude/scopes/shared/skills/adr"
    mkdir -p "$smoke_shadow_home/.claude/skills"
    ln -sfn "$smoke_shadow_target" "$smoke_shadow_home/.claude/skills/adr"
    managed_surface_remove_exact_link install \
        "$smoke_shadow_home/.claude/skills/adr" \
        "shadowed Claude skill 'adr'" \
        "$smoke_shadow_target" >/dev/null
    if [ -L "$smoke_shadow_home/.claude/skills/adr" ]; then
        print_error "a shadowed skill's installed link was not removed"
        exit 1
    fi

    smoke_converge_home="$tmp_dir/converge-home"
    mkdir -p "$smoke_converge_home/.pi/agent" "$smoke_converge_home/.pi"
    ln -s "$tmp_dir/missing-settings.json" "$smoke_converge_home/.pi/agent/settings.json"
    ln -s "$tmp_dir/legacy-damage-control.json" "$smoke_converge_home/.pi/damage-control-rules.json"
    HOME="$smoke_converge_home"
    converge_agent_surfaces >/dev/null
    if [ -L "$smoke_converge_home/.pi/agent/settings.json" ] || [ ! -f "$smoke_converge_home/.pi/agent/settings.json" ]; then
        print_error "agent convergence did not recover dangling Pi settings"
        exit 1
    fi
    if [ -L "$smoke_converge_home/.pi/damage-control-rules.json" ]; then
        print_error "agent convergence kept the legacy Pi damage-control link"
        exit 1
    fi
    if [ "$(readlink "$smoke_converge_home/.claude/statusline-command.sh")" != "$REPO_DIR/claude/statusline-command.sh" ]; then
        print_error "agent convergence did not install the Claude statusline"
        exit 1
    fi

    printf 'install helper smoke test: ok\n'
    exit 0
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
    if ! command -v brew &>/dev/null; then
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    brew install neovim tmux git ripgrep fd fzf jq lazygit mosh lua-language-server || {
        print_warning "Some brew packages may have failed"
    }
    brew upgrade neovim 2>/dev/null || true

    brew tap homebrew/cask-fonts 2>/dev/null || true
    brew install --cask font-caskaydia-mono-nerd-font 2>/dev/null || true

elif [[ "$OS" == "debian" ]]; then
    sudo apt update
    sudo apt install -y curl wget git unzip ripgrep fd-find fzf jq build-essential make neovim tmux xclip mosh || {
        print_warning "Some apt packages may have failed"
    }
    sudo apt install -y lua-language-server 2>/dev/null || {
        print_warning "lua-language-server package unavailable from apt"
    }

    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd || print_warning "Could not create fd symlink"
    fi

    if ! command -v lazygit &>/dev/null; then
        print_step "Installing Lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' || true)
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
    sudo dnf install -y neovim tmux git ripgrep fd fzf make gcc jq unzip curl mosh || {
        print_warning "Some dnf packages may have failed"
    }
    sudo dnf install -y lua-language-server 2>/dev/null || {
        print_warning "lua-language-server package unavailable from dnf"
    }
elif [[ "$OS" == "arch" ]]; then
    sudo pacman -Sy --needed --noconfirm \
        curl wget git unzip ripgrep fd fzf jq base-devel make neovim tmux \
        wl-clipboard xclip mosh lazygit lua-language-server || {
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
# INSTALL NPM TOOLS
# ============================================================================
print_step "Installing npm tools..."

if "${NPM_CMD[@]}" install -g \
    typescript \
    typescript-language-server \
    prettier \
    eslint \
    intelephense \
    vscode-langservers-extracted \
    yaml-language-server \
    @astrojs/language-server \
    @glint/core \
    @github/copilot-language-server \
    hunkdiff \
    @ember-tooling/ember-language-server \
    @tailwindcss/language-server; then
    reshim_asdf_node
    print_success "NPM tools installed"
else
    reshim_asdf_node
    print_warning "Some npm packages may have failed to install"
fi
install_npm_global_binary_link "hunk" || true
install_npm_global_binary_link "hunkdiff" || true

# ============================================================================
# INSTALL NERD FONT
# ============================================================================
print_step "Installing Nerd Font..."

mkdir -p ~/.local/share/fonts

(
    cd ~/.local/share/fonts || exit 1

    if [ ! -f "CaskaydiaMonoNerdFont-Regular.ttf" ]; then
        if download_with_retry \
            "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/CascadiaMono.zip" \
            "CascadiaMono.zip"; then
            if unzip -tq CascadiaMono.zip >/dev/null 2>&1; then
                unzip -qo CascadiaMono.zip
                rm -f CascadiaMono.zip
            else
                print_warning "Font zip corrupted, removing"
                rm -f CascadiaMono.zip
            fi
        fi
    fi
)

if [[ "$OS" != "mac" ]]; then
    fc-cache -fv >/dev/null 2>&1 || true
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
            backup_path_move "$NVIM_LINK"
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

if [ -f ~/.tmux.conf ] && [ ! -L ~/.tmux.conf ]; then
    backup_file "$HOME/.tmux.conf"
fi

if [ -f "$REPO_DIR/tmux.conf" ]; then
    if ln -sf "$REPO_DIR/tmux.conf" ~/.tmux.conf; then
        print_success "Tmux config linked"
    else
        print_error "Failed to link tmux config"
    fi
else
    print_warning "tmux.conf not found in $REPO_DIR"
fi

if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# ============================================================================
# SETUP GHOSTTY CONFIG
# ============================================================================
print_step "Setting up Ghostty config..."

GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
GHOSTTY_CONFIG_LINK="$GHOSTTY_CONFIG_DIR/config"
GHOSTTY_CONFIG_TARGET="$REPO_DIR/ghostty/config"

if [ -f "$GHOSTTY_CONFIG_TARGET" ]; then
    mkdir -p "$GHOSTTY_CONFIG_DIR"
    if [ -f "$GHOSTTY_CONFIG_LINK" ] && [ ! -L "$GHOSTTY_CONFIG_LINK" ]; then
        backup_file "$GHOSTTY_CONFIG_LINK"
    fi
    if ln -sf "$GHOSTTY_CONFIG_TARGET" "$GHOSTTY_CONFIG_LINK"; then
        print_success "Ghostty config linked"
    else
        print_warning "Failed to link Ghostty config"
    fi
else
    print_warning "Ghostty config not found in $REPO_DIR/ghostty/config"
fi

# ============================================================================
# SETUP HERDR (agent terminal workspace)
# ============================================================================
print_step "Setting up Herdr config..."
if bash "$REPO_DIR/herdr/scripts/setup.sh" --links; then
    print_success "Herdr config, Sessionizer layout and skills linked"
    print_warning "Run $REPO_DIR/herdr/scripts/setup.sh --install to install host-local plugins and integrations"
else
    print_warning "Herdr links failed; rerun herdr/scripts/setup.sh --links"
fi

# ============================================================================
# SETUP AGENT WORKFLOW SURFACES
# ============================================================================
print_step "Setting up agent workflow surfaces..."
converge_agent_surfaces
if ! command -v pi &>/dev/null; then
    print_step "Installing Pi Coding Agent..."
    "${NPM_CMD[@]}" install -g --ignore-scripts @earendil-works/pi-coding-agent &&
        reshim_asdf_node &&
        print_success "Pi installed" ||
        print_warning "Pi install failed (npm install -g --ignore-scripts @earendil-works/pi-coding-agent)"
fi

if command -v pi &>/dev/null; then
    print_step "Installing Pi packages from tracked settings..."
    install_pi_packages_from_settings
    install_pi_agent_npm_pins
fi

# ============================================================================
# INSTALL DEV SCRIPTS
# ============================================================================
print_step "Installing dev scripts..."

mkdir -p ~/.local/bin

append_path_entry "$HOME/.local/bin"

install_script "herdr-sync-mini" || true
install_script "tmux-clipboard.sh" || true
install_script "fix-links" || true
install_script "deploy-workflow" || true
install_script "scaffold-project" || true
install_script "claude-lean" || true
install_script "claude-full" || true

if [ -L ~/.local/bin/deploy-harness ]; then
    rm -f ~/.local/bin/deploy-harness
    print_success "Removed legacy deploy-harness link"
fi

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
