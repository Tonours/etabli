#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_DIR/scripts/lib/pi-paths.sh"
. "$REPO_DIR/scripts/lib/etabli-scope.sh"
. "$REPO_DIR/scripts/lib/prefer-cursor-agent.sh"
. "$REPO_DIR/scripts/lib/vendor-surfaces.sh"
. "$REPO_DIR/scripts/lib/managed-surfaces.sh"
FIX=0
VERBOSE=0
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ISSUES=0
FIXED=0
UNRESOLVED=0
OS="$(uname -s)"
SKILL_CATALOG="$REPO_DIR/workflow/runtime/skill-surface.tsv"
SKILL_CATALOG_MISSING=0
if [ -f "$REPO_DIR/scripts/lib/skill-catalog.sh" ] && [ -f "$SKILL_CATALOG" ]; then
  . "$REPO_DIR/scripts/lib/skill-catalog.sh"
  PI_CORE_SKILLS=($(skill_catalog_names "$SKILL_CATALOG" pi pi_core))
  AGENTS_VISIBLE_SKILLS=($(skill_catalog_names "$SKILL_CATALOG" any agents_visible))
  # A present-but-degenerate catalog is corruption, not degradation:
  # fail loudly. (A genuinely absent catalog keeps the missing-catalog
  # degraded mode below.)
  if [ "${#PI_CORE_SKILLS[@]}" -eq 0 ] || { [ "${#PI_CORE_SKILLS[@]}" -eq 1 ] && [ -z "${PI_CORE_SKILLS[0]}" ]; } ||
    [ "${#AGENTS_VISIBLE_SKILLS[@]}" -eq 0 ] || { [ "${#AGENTS_VISIBLE_SKILLS[@]}" -eq 1 ] && [ -z "${AGENTS_VISIBLE_SKILLS[0]}" ]; }; then
    printf 'check-fix-symlinks: skill catalog present but degenerate (empty pi_core or agents_visible); aborting\n' >&2
    exit 1
  fi
else
  SKILL_CATALOG_MISSING=1
fi
if [ "$SKILL_CATALOG_MISSING" -eq 1 ]; then
  # Bash 3 with `set -u` treats an empty array expansion as unbound.
  PI_CORE_SKILLS=("")
  AGENTS_VISIBLE_SKILLS=("")
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [--fix] [--verbose]

Checks key local symlinks for this repo.

Options:
  --fix      Repair broken/wrong symlinks in place
  --verbose  Show ok entries too
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
  --fix) FIX=1 ;;
  --verbose) VERBOSE=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage
    exit 1
    ;;
  esac
  shift
done

status_line() {
  local status="$1"
  local message="$2"
  printf '%-6s %s\n' "$status" "$message"
}

managed_surface_status() {
  status_line "$@"
}

if [ "$SKILL_CATALOG_MISSING" -eq 1 ]; then
  UNRESOLVED=$((UNRESOLVED + 1))
  status_line WARN "skill catalog source missing; expected $SKILL_CATALOG"
fi

check_absent() {
  local path="$1"
  local type_label="$2"

  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    if [ "$VERBOSE" -eq 1 ]; then
      status_line OK "$type_label absent"
    fi
    return 0
  fi

  ISSUES=$((ISSUES + 1))
  status_line WARN "$type_label exists but must be absent"

  if [ "$FIX" -eq 1 ]; then
    local backup_path
    backup_path="$(managed_surface_backup_path "$path" "$TIMESTAMP")"
    mv "$path" "$backup_path"
    FIXED=$((FIXED + 1))
    status_line BACKUP "$type_label moved to $backup_path"
  fi
}

check_link() {
  managed_surface_reconcile_link check "$2" "$1" "$3"
}

check_script_link() {
  local script_name="$1"
  local link_path="$HOME/.local/bin/$script_name"
  local target_path="$REPO_DIR/scripts/$script_name"

  check_link "$link_path" "$target_path" "script $script_name"
}

check_pi_skill_links() {
  local skill_name
  for skill_name in "${PI_CORE_SKILLS[@]}"; do
    [ -n "$skill_name" ] || continue
    check_link "$HOME/.pi/agent/skills/$skill_name" "$REPO_DIR/pi/skills/$skill_name" "pi skill $skill_name"
  done
  [ "$SKILL_CATALOG_MISSING" -eq 1 ] || managed_surface_prune_unlisted_source_skills \
    check "$REPO_DIR" "$HOME" .pi/agent/skills Pi pi "${PI_CORE_SKILLS[@]}"
}

check_agents_visible_skill_links() {
  local skill_name skill_source
  for skill_name in "${AGENTS_VISIBLE_SKILLS[@]}"; do
    [ -n "$skill_name" ] || continue
    skill_source="$(skill_catalog_dir "$SKILL_CATALOG" "$REPO_DIR" "$skill_name" || true)"
    [ -n "$skill_source" ] || skill_source="$REPO_DIR/pi/skills/$skill_name"
    check_link "$HOME/.agents/skills/$skill_name" "$skill_source" "grok/agents-visible skill $skill_name"
  done
  [ "$SKILL_CATALOG_MISSING" -eq 1 ] || managed_surface_prune_unlisted_source_skills \
    check "$REPO_DIR" "$HOME" .agents/skills Grok/agents-visible all "${AGENTS_VISIBLE_SKILLS[@]}"
}

check_vendor_skill_links() {
  local skill_name skill_dir active_scopes surface label
  local record_scope record_pi_core record_vendor

  managed_surface_prune_pi_cross_surface_links check "$REPO_DIR" "$HOME"
  [ "$SKILL_CATALOG_MISSING" -eq 0 ] || return 0

  active_scopes="$(deployed_scopes)"
  while IFS=$'\t' read -r record_scope skill_name skill_dir record_pi_core record_vendor; do
    [ -n "$skill_name" ] || continue
    for surface in .claude/skills .codex/skills .config/devin/skills .pi/agent/skills; do
      if vendor_surface_expected "$surface" "$record_scope" "$record_pi_core" "$active_scopes"; then
        case "$surface" in
        .claude/skills) label="claude" ;;
        .codex/skills) label="codex" ;;
        .config/devin/skills) label="devin" ;;
        .pi/agent/skills) label="pi" ;;
        esac
        check_link "$HOME/$surface/$skill_name" "$skill_dir" "$label vendor skill $skill_name"
      fi
    done
  done < <(skill_catalog_vendor_records "$SKILL_CATALOG" "$REPO_DIR")
  managed_surface_prune_vendor_skill_links check "$REPO_DIR" "$HOME" "$SKILL_CATALOG" "$active_scopes"
}

deployed_scopes() {
  etabli_active_scopes "$HOME"
}

check_claude_skill_links() {
  local scope scope_root skill_dir skill_name active_scopes skill_link

  active_scopes="$(deployed_scopes)"
  for scope in $active_scopes; do
    scope_root="$REPO_DIR/claude/scopes/$scope/skills"
    [ -d "$scope_root" ] || continue
    while IFS= read -r skill_dir; do
      skill_name="$(basename "$skill_dir")"
      if managed_surface_skill_is_shadowed "$skill_name" "$active_scopes"; then
        skill_link="$HOME/.claude/skills/$skill_name"
        if [ -L "$skill_link" ] && [ "$(readlink "$skill_link")" = "$skill_dir" ]; then
          ISSUES=$((ISSUES + 1))
          status_line WARN "shadowed claude skill $skill_name is still linked"
          if [ "$FIX" -eq 1 ]; then
            rm -f "$skill_link"
            FIXED=$((FIXED + 1))
            status_line FIXED "removed shadowed claude skill $skill_name"
          fi
        fi
        continue
      fi
      check_link "$HOME/.claude/skills/$skill_name" "$skill_dir" "claude skill $skill_name"
    done < <(find "$scope_root" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) | sort)
  done
}

check_claude_command_links() {
  local scope scope_root command_file command_name

  for scope in $(deployed_scopes); do
    scope_root="$REPO_DIR/claude/scopes/$scope/commands"
    [ -d "$scope_root" ] || continue
    while IFS= read -r command_file; do
      command_name="$(basename "$command_file")"
      check_link "$HOME/.claude/commands/$command_name" "$command_file" "claude command $command_name"
    done < <(find "$scope_root" -mindepth 1 -maxdepth 1 -type f -name '*.md' | sort)
  done
}

check_claude_hook_links() {
  local hook_file hook_name

  if [ ! -d "$REPO_DIR/claude/hooks" ]; then
    return
  fi

  for hook_file in "$REPO_DIR/claude/hooks"/*.mjs "$REPO_DIR/claude/hooks"/*.sh; do
    if [ -f "$hook_file" ]; then
      hook_name="$(basename "$hook_file")"
      check_link "$HOME/.claude/hooks/$hook_name" "$hook_file" "claude workflow hook $hook_name"
    fi
  done
}

check_claude_agent_links() {
  local scope scope_root agent_file agent_name

  for scope in $(deployed_scopes); do
    scope_root="$REPO_DIR/claude/scopes/$scope/agents"
    [ -d "$scope_root" ] || continue
    while IFS= read -r agent_file; do
      agent_name="$(basename "$agent_file")"
      check_link "$HOME/.claude/agents/$agent_name" "$agent_file" "claude agent $agent_name"
    done < <(find "$scope_root" -mindepth 1 -maxdepth 1 -type f -name '*.md' | sort)
  done
}

check_claude_script_links() {
  local scope scope_root script_entry script_name

  for scope in $(deployed_scopes); do
    scope_root="$REPO_DIR/claude/scopes/$scope/scripts"
    [ -d "$scope_root" ] || continue
    while IFS= read -r script_entry; do
      script_name="$(basename "$script_entry")"
      check_link "$HOME/.claude/scripts/$script_name" "$script_entry" "claude script $script_name"
    done < <(find "$scope_root" -mindepth 1 -maxdepth 1 | sort)
  done
}

check_stale_managed_claude_agent_links() {
  managed_surface_prune_stale_claude_agents check "$REPO_DIR" "$HOME"
}

check_link "$HOME/.config/nvim" "$REPO_DIR/nvim" "nvim"
check_link "$HOME/.tmux.conf" "$REPO_DIR/tmux.conf" "tmux config"
check_link "$HOME/.config/ghostty/config" "$REPO_DIR/ghostty/config" "ghostty config"
check_link "$HOME/.config/herdr/config.toml" "$REPO_DIR/herdr/config.toml" "herdr config"
check_link "$HOME/.config/herdr/plugins/config/sessionizer/config.toml" "$REPO_DIR/herdr/layouts/sessionizer.config.toml" "herdr Sessionizer layout"
check_link "$HOME/.claude/skills/herdr" "$REPO_DIR/herdr/skills/herdr" "herdr skill (claude)"
check_link "$HOME/.codex/skills/herdr" "$REPO_DIR/herdr/skills/herdr" "herdr skill (codex)"
check_link "$HOME/.config/devin/skills/herdr" "$REPO_DIR/herdr/skills/herdr" "herdr skill (devin)"
check_link "$HOME/.agents/skills/herdr" "$REPO_DIR/herdr/skills/herdr" "herdr skill (agents)"
check_link "$HOME/.pi/agent/skills/herdr" "$REPO_DIR/herdr/skills/herdr" "herdr skill (pi)"
check_link "$HOME/.pi/agent/AGENTS.md" "$REPO_DIR/pi/AGENTS.md" "pi AGENTS.md"
check_link "$HOME/.pi/agent/workflow" "$REPO_DIR/workflow" "pi workflow sources"
check_link "$HOME/.pi/agent/PLAN_TEMPLATE.md" "$REPO_DIR/PLAN_TEMPLATE.md" "pi PLAN_TEMPLATE.md"
check_link "$HOME/.pi/agent/PLAN_TEMPLATE_FULL.md" "$REPO_DIR/PLAN_TEMPLATE_FULL.md" "pi PLAN_TEMPLATE_FULL.md"
check_link "$HOME/.agents/PLAN_TEMPLATE.md" "$REPO_DIR/PLAN_TEMPLATE.md" "agents PLAN_TEMPLATE.md"
check_link "$HOME/.agents/PLAN_TEMPLATE_FULL.md" "$REPO_DIR/PLAN_TEMPLATE_FULL.md" "agents PLAN_TEMPLATE_FULL.md"
check_link "$HOME/.agents/workflow" "$REPO_DIR/workflow" "agents workflow sources"
check_link "$HOME/.pi/scripts" "$REPO_DIR/scripts" "pi canonical scripts"
check_link "$HOME/.pi/workflow" "$REPO_DIR/workflow" "pi canonical workflow"
check_link "$HOME/.pi/agent/extensions" "$REPO_DIR/pi/extensions" "pi extensions"
check_link "$REPO_DIR/pi/extensions/node_modules" "$(pi_agent_node_modules_dir "$HOME")" "pi extension node_modules"
check_absent "$HOME/.pi/extensions" "legacy pi extensions"
check_link "$HOME/.pi/agent/models.json" "$REPO_DIR/pi/models.json" "pi models.json"
check_link "$HOME/.pi/agent/subagents.json" "$REPO_DIR/pi/agent/subagents.json" "pi subagents.json"
for agent_file in "$REPO_DIR/pi/agents"/*.md; do
  if [ -f "$agent_file" ]; then
    agent_name="$(basename "$agent_file")"
    check_link "$HOME/.pi/agent/agents/$agent_name" "$agent_file" "pi agent $agent_name"
  fi
done
check_link "$HOME/.pi/settings.json" "$REPO_DIR/pi/settings.json" "pi settings.json"
check_link "$HOME/.pi/themes" "$REPO_DIR/pi/themes" "pi themes"
check_link "$HOME/.claude/CLAUDE.md" "$REPO_DIR/claude/CLAUDE.md" "claude CLAUDE.md"
check_link "$HOME/.claude/workflow" "$REPO_DIR/workflow" "claude workflow sources"
check_link "$HOME/.claude/PLAN_TEMPLATE.md" "$REPO_DIR/PLAN_TEMPLATE.md" "claude PLAN_TEMPLATE.md"
check_link "$HOME/.claude/PLAN_TEMPLATE_FULL.md" "$REPO_DIR/PLAN_TEMPLATE_FULL.md" "claude PLAN_TEMPLATE_FULL.md"
check_link "$HOME/.claude/review-rubric.md" "$REPO_DIR/workflow/review-rubric.md" "claude review rubric"
check_claude_command_links
check_link "$HOME/.claude/settings.workflow-hooks.json" "$REPO_DIR/claude/settings.workflow-hooks.json" "claude workflow hook settings fragment"
check_link "$HOME/.claude/statusline-command.sh" "$REPO_DIR/claude/statusline-command.sh" "claude statusline command"
check_claude_hook_links
check_stale_managed_claude_agent_links
check_claude_agent_links
check_claude_script_links
check_pi_skill_links
check_agents_visible_skill_links
check_vendor_skill_links
check_claude_skill_links

check_script_link "tmux-clipboard.sh"
check_script_link "fix-links"
check_script_link "deploy-workflow"
check_script_link "jev-judge"
check_absent "$HOME/.local/bin/deploy-harness" "legacy deploy-harness script"

if prefer_cursor_agent_is_grok_collision "$HOME/.grok/bin/agent" "$HOME/.grok/bin/grok"; then
  ISSUES=$((ISSUES + 1))
  status_line WARN "grok colliding agent launcher exists; keep agent for Cursor"
  if [ "$FIX" -eq 1 ]; then
    rm -f "$HOME/.grok/bin/agent"
    FIXED=$((FIXED + 1))
    status_line FIXED "removed ~/.grok/bin/agent (Grok stays on grok)"
  fi
elif [ -e "$HOME/.grok/bin/agent" ] || [ -L "$HOME/.grok/bin/agent" ]; then
  UNRESOLVED=$((UNRESOLVED + 1))
  status_line WARN "custom ~/.grok/bin/agent left in place"
elif [ "$VERBOSE" -eq 1 ]; then
  status_line OK "grok colliding agent launcher absent"
fi
check_script_link "scaffold-project"

printf '\nSummary: %d issue(s), %d fix(es) applied, %d unresolved\n' "$ISSUES" "$FIXED" "$UNRESOLVED"

if [ "$ISSUES" -gt 0 ] && { [ "$FIX" -eq 0 ] || [ "$UNRESOLVED" -gt 0 ]; }; then
  exit 1
fi
