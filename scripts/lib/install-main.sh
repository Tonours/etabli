#!/bin/bash

# ============================================================================
# ETABLI DEV SETUP
# Compatible: macOS, Linux (Ubuntu/Debian), Remote (SSH)
# ============================================================================

set -e

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)"
. "$BOOTSTRAP_DIR/lib/pi-paths.sh"
. "$BOOTSTRAP_DIR/lib/skill-catalog.sh"
. "$BOOTSTRAP_DIR/lib/etabli-scope.sh"
SKILL_CATALOG="$BOOTSTRAP_DIR/../workflow/runtime/skill-surface.tsv"

# ============================================================================
# VERSIONS (centralized for maintenance)
# ============================================================================
readonly NERD_FONT_VERSION="v3.4.0"
readonly MIN_NVIM_VERSION="0.12.2"
readonly PI_CORE_SKILLS=( $(skill_catalog_names "$SKILL_CATALOG" pi pi_core) )
readonly AGENTS_VISIBLE_SKILLS=( $(skill_catalog_names "$SKILL_CATALOG" pi agents_visible) )
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

prune_stale_managed_claude_agent_links() {
    local repo_dir="$1"
    local home_dir="$2"
    local legacy_managed_dir="$repo_dir/claude/agents"
    local scoped_managed_root="$repo_dir/claude/scopes"
    local installed_dir="$home_dir/.claude/agents"
    local agent_link agent_target

    [ -d "$installed_dir" ] || return 0

    for agent_link in "$installed_dir"/*.md; do
        [ -L "$agent_link" ] || continue
        agent_target="$(readlink "$agent_link")"
        case "$agent_target" in
            "$legacy_managed_dir"/* | "$scoped_managed_root"/*/agents/*) ;;
            *) continue ;;
        esac
        [ -e "$agent_target" ] && continue

        rm -f "$agent_link"
        print_success "Removed stale managed Claude agent '$(basename "$agent_link")'"
    done
}

managed_skill_roots() {
    local repo_dir="$1"
    local candidate resolved

    while IFS= read -r candidate; do
        resolved="$(cd "$candidate" >/dev/null 2>&1 && pwd -P)" || continue
        printf '%s\n' "$resolved"
    done < <(
        printf '%s/pi/skills\n' "$repo_dir"
        find "$repo_dir/vendor" "$repo_dir/claude/scopes" \
            -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
            while IFS= read -r group_dir; do
                printf '%s/skills\n' "$group_dir"
            done
    )
}

skill_target_is_managed() {
    local repo_dir="$1"
    local managed_roots="$2"
    local skill_target="$3"
    local skill_parent

    skill_parent="$(cd "$(dirname "$skill_target")" >/dev/null 2>&1 && pwd -P)"
    if [ -n "$skill_parent" ]; then
        printf '%s\n' "$managed_roots" | grep -qxF "$skill_parent"
        return
    fi

    case "$skill_target" in
        "$repo_dir/pi/skills/"?* | \
        "$repo_dir/vendor/"?*"/skills/"?* | \
        "$repo_dir/claude/scopes/"?*"/skills/"?*) return 0 ;;
    esac

    return 1
}

prune_stale_managed_skill_links() {
    local repo_dir="$1"
    local home_dir="$2"
    local managed_roots surface skill_link skill_target

    managed_roots="$(managed_skill_roots "$repo_dir")"

    for surface in \
        "$home_dir/.claude/skills" \
        "$home_dir/.pi/agent/skills" \
        "$home_dir/.codex/skills" \
        "$home_dir/.agents/skills"; do
        [ -d "$surface" ] || continue

        while IFS= read -r skill_link; do
            [ -n "$skill_link" ] || continue
            skill_target="$(readlink "$skill_link")"
            if [ "${skill_target#/}" = "$skill_target" ]; then
                skill_target="$(dirname "$skill_link")/$skill_target"
            fi
            skill_target_is_managed "$repo_dir" "$managed_roots" "$skill_target" || continue
            [ -e "$skill_target" ] && continue

            rm -f "$skill_link"
            print_success "Removed stale managed skill '$(basename "$skill_link")' from $surface"
        done < <(find "$surface" -mindepth 1 -maxdepth 1 -type l | sort)
    done
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
    cp "$path" "$backup"
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
    command -v rtk &> /dev/null && rtk gain > /dev/null 2>&1
}

node_available() {
    "${NODE_CMD[@]}" -v > /dev/null 2>&1
}

node_runtime_available() {
    node_available && "${NPM_CMD[@]}" -v > /dev/null 2>&1
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
    ' "$rcfile" > "$tmp_file" && cp "$tmp_file" "$rcfile"; then
        rm -f "$tmp_file"
    else
        rm -f "$tmp_file"
        return 0
    fi
}

reshim_asdf_node() {
    if [ "${NODE_CMD[0]}" = "asdf" ]; then
        asdf reshim nodejs > /dev/null 2>&1 || true
    fi
}

select_node_runtime() {
    print_step "Checking Node.js runtime..."

    if command -v asdf &> /dev/null; then
        if asdf exec node -v > /dev/null 2>&1 && asdf exec npm -v > /dev/null 2>&1; then
            prepend_asdf_shims
            NODE_CMD=(asdf exec node)
            NPM_CMD=(asdf exec npm)
            print_success "Node.js $("${NODE_CMD[@]}" -v) ready (via asdf)"
            return 0
        fi
    fi

    if command -v node &> /dev/null && command -v npm &> /dev/null; then
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

    if command -v "$binary" > /dev/null 2>&1; then
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

    if ! node_available; then
        print_warning "Node.js not available - skipping Pi agent settings resource sync"
        return 0
    fi

    if "${NODE_CMD[@]}" - "$local_settings" "$tracked_settings" <<'NODE'
const fs = require("node:fs");

const [localPath, trackedPath] = process.argv.slice(2);
const localSettings = JSON.parse(fs.readFileSync(localPath, "utf8"));
const trackedSettings = JSON.parse(fs.readFileSync(trackedPath, "utf8"));

const managedSources = new Set([
  "local:etabli-workflow",
  "npm:mitsupi",
  "git:github.com/badlogic/pi-skills",
  "npm:@tintinweb/pi-tasks@0.7.1",
]);
const legacySources = new Set([
  "npm:pi-subagents",
  "npm:pi-interview",
  "npm:@tintinweb/pi-subagents",
  "npm:@tintinweb/pi-tasks",
  "npm:pi-hooks",
  "npm:glimpseui",
]);
let localPackages = Array.isArray(localSettings.packages) ? localSettings.packages : [];
const trackedPackages = Array.isArray(trackedSettings.packages) ? trackedSettings.packages : [];
let localModels = Array.isArray(localSettings.enabledModels) ? localSettings.enabledModels : [];
// Retired aliases / catalog IDs that must not stay in local cycling lists.
const legacyModels = new Set([
  "openai-codex/gpt-5.6",
  "opencode-go/kimi-k2.6",
  "kimi-coding/kimi-for-coding",
  "kimi-coding/kimi-for-coding-highspeed",
  "github-copilot/claude-opus-4.7",
  "opencode-go/minimax-m2.7",
  "opencode-go/qwen3.6-plus",
  "local-mlx//path/to/models/mlx/gemma-4-12B-it-4bit",
]);
const isLegacyModel = (model) =>
  legacyModels.has(model) ||
  (typeof model === "string" && model.startsWith("local-mlx/"));

function packageSource(entry) {
  if (typeof entry === "string") return entry;
  if (entry && typeof entry === "object" && typeof entry.source === "string") return entry.source;
  return null;
}

function isLegacySource(source) {
  return legacySources.has(source) ||
    source.startsWith("npm:@tintinweb/pi-subagents@") ||
    ((source.startsWith("npm:@tintinweb/pi-tasks@")) && source !== "npm:@tintinweb/pi-tasks@0.7.1") ||
    (source === "npm:@agwab/pi-workflow" || source.startsWith("npm:@agwab/pi-workflow@"));
}

localPackages = localPackages.filter((entry) => {
  const source = packageSource(entry);
  return !source || !isLegacySource(source);
});

const trackedBySource = new Map();
for (const entry of trackedPackages) {
  if (entry && typeof entry === "object" && managedSources.has(entry.source)) {
    trackedBySource.set(entry.source, entry);
  }
}

let changed = localPackages.length !== (Array.isArray(localSettings.packages) ? localSettings.packages.length : 0);
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

const beforeModels = JSON.stringify(localModels);
localModels = localModels.filter((model) => !isLegacyModel(model));
for (const model of trackedSettings.enabledModels ?? []) {
  if (!localModels.includes(model)) localModels.push(model);
}
// Keep a personal default selectable even when it is outside the tracked pin set.
if (
  typeof localSettings.defaultProvider === "string" &&
  typeof localSettings.defaultModel === "string" &&
  localSettings.defaultProvider &&
  localSettings.defaultModel
) {
  const defaultId = `${localSettings.defaultProvider}/${localSettings.defaultModel}`;
  if (!localModels.includes(defaultId) && !isLegacyModel(defaultId)) {
    localModels.push(defaultId);
  }
}
if (JSON.stringify(localModels) !== beforeModels) changed = true;

if (changed) {
  localSettings.packages = localPackages;
  localSettings.enabledModels = localModels;
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

    print_step "Installing Neovim plugins through vim.pack..."
    if nvim --headless +qa > /dev/null 2>&1; then
        print_success "Neovim plugins installed"
    else
        print_warning "Neovim plugin install failed - run: nvim --headless +qa"
    fi

    if nvim --headless "+lua vim.notify = function() end" +qa > /dev/null 2>&1; then
        print_success "Neovim config loads"
    else
        print_warning "Neovim config load check failed - run: nvim --headless +qa"
    fi
}

ensure_pi_extension_node_modules_link() {
    local link_path="$REPO_DIR/pi/extensions/node_modules"
    local target_path

    target_path="$(pi_agent_node_modules_dir "$HOME")"

    mkdir -p "$target_path"

    if [ -e "$link_path" ] && [ ! -L "$link_path" ]; then
        print_warning "pi/extensions/node_modules exists but is not a symlink; leaving it untouched"
        return 0
    fi

    if ln -sfn "$target_path" "$link_path"; then
        print_success "Pi extension node_modules linked"
    else
        print_warning "Failed to link Pi extension node_modules"
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
        } 2>/dev/null | awk 'NF && !seen[$0]++'
    )"

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

install_pi_agent_npm_pins() {
    local package_dir

    package_dir="$(pi_agent_npm_dir "$HOME")"

    if ! node_runtime_available; then
        print_warning "Node.js not available - skipping Pi agent npm pins"
        return 0
    fi

    mkdir -p "$package_dir"
    if (cd "$package_dir" && "${NPM_CMD[@]}" install --save-exact "${PI_AGENT_NPM_PINS[@]}" > /dev/null 2>&1); then
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
    : > "$first_backup"

    computed_backup="$(backup_path "$tmp_dir/settings.json")"
    if [ "$computed_backup" != "$second_backup" ]; then
        print_error "backup_path did not avoid an existing backup path"
        exit 1
    fi

    smoke_repo_dir="$(cd "$BOOTSTRAP_DIR/.." >/dev/null 2>&1 && pwd)"
    smoke_agent_home="$tmp_dir/agent-home"
    smoke_personal_target="$tmp_dir/personal-agent.md"
    mkdir -p "$smoke_agent_home/.claude/agents"
    printf '%s\n' 'personal agent' > "$smoke_personal_target"
    ln -s "$smoke_repo_dir/claude/agents/removed-agent.md" \
        "$smoke_agent_home/.claude/agents/removed-agent.md"
    ln -s "$smoke_personal_target" \
        "$smoke_agent_home/.claude/agents/personal.md"
    prune_stale_managed_claude_agent_links "$smoke_repo_dir" "$smoke_agent_home"
    if [ -L "$smoke_agent_home/.claude/agents/removed-agent.md" ]; then
        print_error "stale managed Claude agent link was not removed"
        exit 1
    fi
    if [ ! -L "$smoke_agent_home/.claude/agents/personal.md" ]; then
        print_error "personal Claude agent link was removed"
        exit 1
    fi

    smoke_skill_home="$tmp_dir/skill-home"
    smoke_unmanaged_skill="$tmp_dir/unmanaged-skill"
    mkdir -p "$smoke_skill_home/.claude/skills" "$smoke_unmanaged_skill"
    ln -s "$smoke_repo_dir/claude/scopes/shared/skills/removed-skill" \
        "$smoke_skill_home/.claude/skills/removed-scope-skill"
    ln -s "$smoke_repo_dir/vendor/mcollina-skills/skills/removed-skill" \
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
        "claude/scopes/shared/skills/stack-suite" \
        "vendor/mcollina-skills/skills/node" \
        "pi/skills/react-doctor-100"; do
        ln -s "$smoke_repo_dir/$smoke_live_skill" \
            "$smoke_skill_home/.claude/skills/$(basename "$smoke_live_skill")"
    done

    for smoke_other_surface in .pi/agent/skills .codex/skills .agents/skills; do
        mkdir -p "$smoke_skill_home/$smoke_other_surface"
        ln -s "$smoke_repo_dir/vendor/mcollina-skills/skills/removed-skill" \
            "$smoke_skill_home/$smoke_other_surface/removed-vendor-skill"
        ln -s "$smoke_repo_dir/vendor/mcollina-skills/skills/node" \
            "$smoke_skill_home/$smoke_other_surface/node"
    done

    prune_stale_managed_skill_links "$smoke_repo_dir" "$smoke_skill_home"

    for smoke_other_surface in .pi/agent/skills .codex/skills .agents/skills; do
        if [ -L "$smoke_skill_home/$smoke_other_surface/removed-vendor-skill" ]; then
            print_error "stale vendor skill link survived in $smoke_other_surface"
            exit 1
        fi
        if [ ! -L "$smoke_skill_home/$smoke_other_surface/node" ]; then
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

    prune_stale_managed_skill_links "$smoke_skill_home/relative-repo" "$smoke_skill_home"

    if [ -L "$smoke_skill_home/.claude/skills/relative-managed-dangling" ]; then
        print_error "stale relative link under a managed root was not removed"
        exit 1
    fi

    smoke_symlinked_repo="$tmp_dir/symlinked-repo"
    ln -s "$smoke_skill_home/relative-repo" "$smoke_symlinked_repo"
    ln -s "$smoke_symlinked_repo/pi/skills/symlinked-gone" \
        "$smoke_skill_home/.claude/skills/symlinked-repo-dangling"
    prune_stale_managed_skill_links "$smoke_skill_home/relative-repo" "$smoke_skill_home"
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
    prune_stale_managed_skill_links "$smoke_wholesale_repo" "$smoke_skill_home"
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
    for smoke_kept_skill in stack-suite node react-doctor-100; do
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
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' > "$rcfile"
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
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' > "$symlink_target"
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

    smoke_home="$tmp_dir/home"
    mkdir -p "$smoke_home/.pi/agent"
    printf '%s\n' '{"defaultProvider":"custom","defaultModel":"personal-model","defaultThinkingLevel":"low","enabledModels":["custom/personal-model"],"packages":["npm:@agwab/pi-workflow",{"source":"npm:@agwab/pi-workflow@0.7.0"},{"source":"npm:@agwab/pi-workflow-helper"}]}' \
        > "$smoke_home/.pi/agent/settings.json"
    # Resolve a real Node binary before HOME override. asdf shims exit 126 when HOME
    # points at a disposable tree; that is unrelated to settings-sync portability.
    smoke_node_bin="$("${NODE_CMD[@]}" -e 'process.stdout.write(process.execPath)' 2>/dev/null || true)"
    if [ -z "$smoke_node_bin" ] || [ ! -x "$smoke_node_bin" ]; then
        smoke_node_bin="$(command -v node)"
    fi
    NODE_CMD=("$smoke_node_bin")
    HOME="$smoke_home"
    REPO_DIR="$(cd "$BOOTSTRAP_DIR/.." >/dev/null 2>&1 && pwd)"
    sync_pi_agent_settings_resources >/dev/null
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
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
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
    if ! command -v brew &> /dev/null; then
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

    if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd || print_warning "Could not create fd symlink"
    fi

    if ! command -v lazygit &> /dev/null; then
        print_step "Installing Lazygit..."
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
            if unzip -tq CascadiaMono.zip > /dev/null 2>&1; then
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

HERDR_CONFIG_DIR="$HOME/.config/herdr"
HERDR_CONFIG_LINK="$HERDR_CONFIG_DIR/config.toml"
HERDR_CONFIG_TARGET="$REPO_DIR/herdr/config.toml"

if [ -f "$HERDR_CONFIG_TARGET" ]; then
    mkdir -p "$HERDR_CONFIG_DIR"
    if [ -f "$HERDR_CONFIG_LINK" ] && [ ! -L "$HERDR_CONFIG_LINK" ]; then
        backup_file "$HERDR_CONFIG_LINK"
    fi
    if ln -sf "$HERDR_CONFIG_TARGET" "$HERDR_CONFIG_LINK"; then
        print_success "Herdr config linked"
    else
        print_warning "Failed to link Herdr config"
    fi
else
    print_warning "Herdr config not found in $REPO_DIR/herdr/config.toml"
fi

# ============================================================================
# SETUP PI CODING AGENT
# ============================================================================
print_step "Setting up Pi Coding Agent..."

mkdir -p ~/.pi ~/.pi/agent/agents ~/.pi/agent/skills ~/.pi/agent/themes ~/.pi/agent/extensions

if [ -f "$REPO_DIR/pi/AGENTS.md" ]; then
    ln -sf "$REPO_DIR/pi/AGENTS.md" ~/.pi/agent/AGENTS.md
    print_success "Pi AGENTS.md linked"
fi

if [ -d "$REPO_DIR/workflow" ]; then
    if [ -e ~/.pi/agent/workflow ] && [ ! -L ~/.pi/agent/workflow ]; then
        backup_path_move "$HOME/.pi/agent/workflow"
    fi
    ln -sfn "$REPO_DIR/workflow" ~/.pi/agent/workflow
    print_success "Pi workflow sources linked"
fi

for template_file in PLAN_TEMPLATE.md PLAN_TEMPLATE_FULL.md; do
    if [ -f "$REPO_DIR/$template_file" ]; then
        if [ -e "$HOME/.pi/agent/$template_file" ] && [ ! -L "$HOME/.pi/agent/$template_file" ]; then
            backup_path_move "$HOME/.pi/agent/$template_file"
        fi
        ln -sf "$REPO_DIR/$template_file" "$HOME/.pi/agent/$template_file"
        print_success "Pi $template_file linked"
    fi
done

mkdir -p "$HOME/.agents"
if [ -d "$REPO_DIR/workflow" ]; then
    if [ -e "$HOME/.agents/workflow" ] && [ ! -L "$HOME/.agents/workflow" ]; then
        backup_path_move "$HOME/.agents/workflow"
    fi
    ln -sfn "$REPO_DIR/workflow" "$HOME/.agents/workflow"
    print_success "Agents workflow sources linked"
fi
for template_file in PLAN_TEMPLATE.md PLAN_TEMPLATE_FULL.md; do
    if [ -f "$REPO_DIR/$template_file" ]; then
        if [ -e "$HOME/.agents/$template_file" ] && [ ! -L "$HOME/.agents/$template_file" ]; then
            backup_path_move "$HOME/.agents/$template_file"
        fi
        ln -sf "$REPO_DIR/$template_file" "$HOME/.agents/$template_file"
        print_success "Agents $template_file linked"
    fi
done

if [ -f "$REPO_DIR/pi/models.json" ]; then
    if [ -f ~/.pi/agent/models.json ] && [ ! -L ~/.pi/agent/models.json ]; then
        backup_file "$HOME/.pi/agent/models.json"
    fi
    ln -sf "$REPO_DIR/pi/models.json" ~/.pi/agent/models.json
    print_success "Pi models.json linked"
fi

if [ -f "$REPO_DIR/pi/agent/subagents.json" ]; then
    if [ -f ~/.pi/agent/subagents.json ] && [ ! -L ~/.pi/agent/subagents.json ]; then
        backup_file "$HOME/.pi/agent/subagents.json"
    fi
    ln -sf "$REPO_DIR/pi/agent/subagents.json" ~/.pi/agent/subagents.json
    print_success "Pi subagents.json linked"
fi

for agent_file in "$REPO_DIR/pi/agents"/*.md; do
    if [ -f "$agent_file" ]; then
        agent_name="$(basename "$agent_file")"
        if [ -f "$HOME/.pi/agent/agents/$agent_name" ] && [ ! -L "$HOME/.pi/agent/agents/$agent_name" ]; then
            backup_file "$HOME/.pi/agent/agents/$agent_name"
        fi
        ln -sf "$agent_file" "$HOME/.pi/agent/agents/$agent_name"
        print_success "Pi agent '$agent_name' linked"
    fi
done

if [ -d "$REPO_DIR/pi/extensions" ]; then
    if [ -L ~/.pi/extensions ]; then
        rm ~/.pi/extensions
    elif [ -d ~/.pi/extensions ]; then
        backup_path_move "$HOME/.pi/extensions"
    fi
    if [ -d ~/.pi/agent/extensions ] && [ ! -L ~/.pi/agent/extensions ]; then
        backup_path_move "$HOME/.pi/agent/extensions"
    fi
    ln -sfn "$REPO_DIR/pi/extensions" ~/.pi/agent/extensions
    print_success "Pi extensions linked"
    ensure_pi_extension_node_modules_link
fi

if [ -d "$REPO_DIR/pi/themes" ]; then
    if [ -d ~/.pi/themes ] && [ ! -L ~/.pi/themes ]; then
        backup_path_move "$HOME/.pi/themes"
    fi
    ln -sfn "$REPO_DIR/pi/themes" ~/.pi/themes
fi

if [ -f "$REPO_DIR/pi/settings.json" ]; then
    if [ -f ~/.pi/settings.json ] && [ ! -L ~/.pi/settings.json ]; then
        backup_file "$HOME/.pi/settings.json"
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

if [ -L ~/.pi/damage-control-rules.json ]; then
    rm -f ~/.pi/damage-control-rules.json
fi

for theme_file in "$REPO_DIR/pi/themes"/*.json; do
    if [ -f "$theme_file" ]; then
        theme_name=$(basename "$theme_file")
        ln -sf "$theme_file" ~/.pi/agent/themes/"$theme_name"
        print_success "Pi theme '$theme_name' linked"
    fi
done

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

mkdir -p ~/.agents/skills
for skill_name in "${AGENTS_VISIBLE_SKILLS[@]}"; do
    skill_dir="$(skill_catalog_dir "$SKILL_CATALOG" "$REPO_DIR" "$skill_name" || true)"
    if [ -n "$skill_dir" ] && [ -d "$skill_dir" ]; then
        ln -sfn "$skill_dir" ~/.agents/skills/"$skill_name"
        print_success "Agents-visible skill '$skill_name' linked"
    else
        print_warning "Agents-visible skill '$skill_name' missing from repo"
    fi
done

ETABLI_ACTIVE_SCOPES="$(etabli_active_scopes "$HOME")"

mkdir -p ~/.pi/agent/skills ~/.claude/skills ~/.codex/skills

mkdir -p ~/.agents/skills
prune_stale_managed_skill_links "$REPO_DIR" "$HOME"

CROSS_HARNESS_PI_SKILLS=( $(skill_catalog_names "$SKILL_CATALOG" pi cross_harness) )

for skill_name in "${CROSS_HARNESS_PI_SKILLS[@]}"; do
    skill_dir="$REPO_DIR/pi/skills/$skill_name"
    if [ ! -d "$skill_dir" ]; then
        print_warning "Cross-harness Pi skill '$skill_name' missing from repo"
        continue
    fi
    ln -sfn "$skill_dir" ~/.claude/skills/"$skill_name"
    ln -sfn "$skill_dir" ~/.codex/skills/"$skill_name"
    print_success "Pi skill '$skill_name' also linked for Claude and Codex"
done

while IFS=$'\t' read -r vendor_name vendor_repo vendor_ref vendor_scope vendor_skills; do
    case "$vendor_name" in ''|\#*) continue ;; esac

    case " $ETABLI_ACTIVE_SCOPES " in
        *" $vendor_scope "*) ;;
        *)
            print_step "Skipping vendor '$vendor_name' (scope $vendor_scope not active)"
            continue
            ;;
    esac

    for skill_dir_name in $(skill_catalog_names "$SKILL_CATALOG" "$vendor_name" any); do
        skill_dir="$REPO_DIR/vendor/$vendor_name/skills/$skill_dir_name"
        if [ ! -d "$skill_dir" ]; then
            print_warning "Vendored skill '$skill_dir_name' missing from $vendor_name"
            continue
        fi
        skill_name="$(skill_declared_name "$skill_dir")"
        ln -sfn "$skill_dir" ~/.pi/agent/skills/"$skill_name"
        ln -sfn "$skill_dir" ~/.claude/skills/"$skill_name"
        ln -sfn "$skill_dir" ~/.codex/skills/"$skill_name"
        print_success "Vendored skill '$skill_name' linked for Claude, Pi and Codex"
    done
done <"$REPO_DIR/vendor/sources.tsv"

mkdir -p ~/.claude/commands
if [ -f "$REPO_DIR/claude/CLAUDE.md" ]; then
    ln -sf "$REPO_DIR/claude/CLAUDE.md" ~/.claude/CLAUDE.md
    print_success "Claude CLAUDE.md linked"
fi

if [ -d "$REPO_DIR/workflow" ]; then
    if [ -e ~/.claude/workflow ] && [ ! -L ~/.claude/workflow ]; then
        backup_path_move "$HOME/.claude/workflow"
    fi
    ln -sfn "$REPO_DIR/workflow" ~/.claude/workflow
    print_success "Claude workflow sources linked"
fi

for template_file in PLAN_TEMPLATE.md PLAN_TEMPLATE_FULL.md; do
    if [ -f "$REPO_DIR/$template_file" ]; then
        if [ -e "$HOME/.claude/$template_file" ] && [ ! -L "$HOME/.claude/$template_file" ]; then
            backup_path_move "$HOME/.claude/$template_file"
        fi
        ln -sf "$REPO_DIR/$template_file" "$HOME/.claude/$template_file"
        print_success "Claude $template_file linked"
    fi
done

for scope in $ETABLI_ACTIVE_SCOPES; do
for command_file in $(find "$REPO_DIR/claude/scopes/$scope/commands" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort); do
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
done
rm -f ~/.claude/commands/verify.md
rm -f ~/.claude/commands/plan-create.md
rm -f ~/.claude/commands/plan-review.md
rm -f ~/.claude/commands/handoff.md
rm -f ~/.claude/commands/handoff-implement.md
rm -f ~/.claude/commands/ops-status.md
rm -f ~/.claude/commands/ops-pi-status.md
rm -f ~/.claude/handoff-template.md

if [ -d "$REPO_DIR/claude/hooks" ]; then
    mkdir -p ~/.claude/hooks
    for hook_file in "$REPO_DIR/claude/hooks"/*.mjs; do
        if [ -f "$hook_file" ]; then
            hook_name=$(basename "$hook_file")
            ln -sf "$hook_file" ~/.claude/hooks/"$hook_name"
            print_success "Claude workflow hook '$hook_name' linked"
        fi
    done
fi

if [ -f "$REPO_DIR/claude/settings.workflow-hooks.json" ]; then
    ln -sf "$REPO_DIR/claude/settings.workflow-hooks.json" ~/.claude/settings.workflow-hooks.json
    print_success "Claude workflow hook settings fragment linked"
fi

mkdir -p ~/.claude/skills ~/.claude/agents
prune_stale_managed_claude_agent_links "$REPO_DIR" "$HOME"

for scope in $ETABLI_ACTIVE_SCOPES; do
    for skill_dir in $(find "$REPO_DIR/claude/scopes/$scope/skills" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | sort); do
        skill_name=$(basename "$skill_dir")
        ln -sfn "$skill_dir" ~/.claude/skills/"$skill_name"
        print_success "Claude skill '$skill_name' linked"
    done

    for agent_file in $(find "$REPO_DIR/claude/scopes/$scope/agents" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort); do
        agent_name=$(basename "$agent_file")
        ln -sf "$agent_file" ~/.claude/agents/"$agent_name"
        print_success "Claude agent '$agent_name' linked"
    done
done

for shared_doc in review-rubric.md; do
    if [ -f "$REPO_DIR/workflow/$shared_doc" ]; then
        ln -sf "$REPO_DIR/workflow/$shared_doc" ~/.claude/"$shared_doc"
        print_success "Claude doc '$shared_doc' linked"
    fi
done

if ! command -v pi &> /dev/null; then
    print_step "Installing Pi Coding Agent..."
    "${NPM_CMD[@]}" install -g --ignore-scripts @earendil-works/pi-coding-agent && \
        reshim_asdf_node && \
        print_success "Pi installed" || \
        print_warning "Pi install failed (npm install -g --ignore-scripts @earendil-works/pi-coding-agent)"
fi

if command -v pi &> /dev/null; then
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

install_script "dev-spawn" || true
install_script "herdr-sync-mini" || true
install_script "tmux-clipboard.sh" || true
install_script "fix-links" || true
install_script "deploy-workflow" || true
install_script "scaffold-project" || true

if [ -L ~/.local/bin/deploy-harness ]; then
    rm -f ~/.local/bin/deploy-harness
    print_success "Removed legacy deploy-harness link"
fi

for rcfile in ~/.bashrc ~/.zshrc; do
    ensure_local_bin_shell_path "$rcfile"
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
