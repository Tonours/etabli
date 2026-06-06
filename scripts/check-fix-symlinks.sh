#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX=0
VERBOSE=0
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ISSUES=0
FIXED=0
UNRESOLVED=0
OS="$(uname -s)"
PI_CORE_SKILLS=(
  "plan-loop"
  "plan-implement"
  "review"
  "implement"
  "caveman"
  "grill-me"
)

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
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

status_line() {
  local status="$1"
  local message="$2"
  printf '%-6s %s\n' "$status" "$message"
}

ensure_parent_dir() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
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

repair_link() {
  local link_path="$1"
  local target_path="$2"
  local type_label="$3"

  if [ ! -e "$target_path" ] && [ ! -L "$target_path" ]; then
    UNRESOLVED=$((UNRESOLVED + 1))
    status_line WARN "$type_label source missing; not linking to $target_path"
    return 1
  fi

  ensure_parent_dir "$link_path"

  if [ -e "$link_path" ] && [ ! -L "$link_path" ]; then
    local backup_path
    backup_path="$(backup_path "$link_path")"
    mv "$link_path" "$backup_path"
    status_line BACKUP "$type_label moved to $backup_path"
  else
    rm -rf "$link_path"
  fi

  ln -sfn "$target_path" "$link_path"
  FIXED=$((FIXED + 1))
  status_line FIXED "$type_label -> $target_path"
}

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
    backup_path="$(backup_path "$path")"
    mv "$path" "$backup_path"
    FIXED=$((FIXED + 1))
    status_line BACKUP "$type_label moved to $backup_path"
  fi
}

check_link() {
  local link_path="$1"
  local target_path="$2"
  local type_label="$3"
  local current=""

  if [ ! -e "$target_path" ] && [ ! -L "$target_path" ]; then
    ISSUES=$((ISSUES + 1))
    UNRESOLVED=$((UNRESOLVED + 1))
    status_line WARN "$type_label source missing (expected $target_path)"
    return
  fi

  if [ -L "$link_path" ]; then
    current="$(readlink "$link_path")"
    if [ "$current" = "$target_path" ] && [ -e "$link_path" ]; then
      if [ "$VERBOSE" -eq 1 ]; then
        status_line OK "$type_label -> $current"
      fi
      return 0
    fi
  fi

  ISSUES=$((ISSUES + 1))
  if [ -L "$link_path" ]; then
    status_line WARN "$type_label -> ${current:-<unknown>} (expected $target_path)"
  elif [ -e "$link_path" ]; then
    status_line WARN "$type_label exists but is not a symlink (expected $target_path)"
  else
    status_line WARN "$type_label missing (expected $target_path)"
  fi

  if [ "$FIX" -eq 1 ]; then
    repair_link "$link_path" "$target_path" "$type_label"
  fi
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
    check_link "$HOME/.pi/agent/skills/$skill_name" "$REPO_DIR/pi/skills/$skill_name" "pi skill $skill_name"
  done
}

check_claude_skill_links() {
  local skill_dir skill_name

  if [ ! -d "$REPO_DIR/claude/skills" ]; then
    return
  fi

  for skill_dir in "$REPO_DIR/claude/skills"/*; do
    if [ -d "$skill_dir" ]; then
      skill_name="$(basename "$skill_dir")"
      check_link "$HOME/.claude/skills/$skill_name" "$skill_dir" "claude skill $skill_name"
    fi
  done
}

check_link "$HOME/.config/nvim" "$REPO_DIR/nvim" "nvim"
check_link "$HOME/.tmux.conf" "$REPO_DIR/tmux.conf" "tmux config"
check_link "$HOME/.config/ghostty/config" "$REPO_DIR/ghostty/config" "ghostty config"
check_link "$HOME/.pi/agent/AGENTS.md" "$REPO_DIR/pi/AGENTS.md" "pi AGENTS.md"
check_link "$HOME/.pi/agent/extensions" "$REPO_DIR/pi/extensions" "pi extensions"
check_absent "$HOME/.pi/extensions" "legacy pi extensions"
check_link "$HOME/.pi/agent/models.json" "$REPO_DIR/pi/models.json" "pi models.json"
check_link "$HOME/.pi/settings.json" "$REPO_DIR/pi/settings.json" "pi settings.json"
check_link "$HOME/.pi/themes" "$REPO_DIR/pi/themes" "pi themes"
check_link "$HOME/.claude/CLAUDE.md" "$REPO_DIR/claude/CLAUDE.md" "claude CLAUDE.md"
check_link "$HOME/.claude/PLAN_TEMPLATE.md" "$REPO_DIR/PLAN_TEMPLATE.md" "claude PLAN_TEMPLATE.md"
check_link "$HOME/.claude/review-rubric.md" "$REPO_DIR/workflow/review-rubric.md" "claude review rubric"
check_link "$HOME/.claude/commands/plan.md" "$REPO_DIR/claude/commands/plan-create.md" "claude command plan.md"
check_link "$HOME/.claude/commands/implement.md" "$REPO_DIR/claude/commands/implement.md" "claude command implement.md"
check_link "$HOME/.claude/commands/review.md" "$REPO_DIR/claude/commands/review.md" "claude command review.md"
check_pi_skill_links
check_claude_skill_links

check_script_link "dev-spawn"
check_script_link "tmux-clipboard.sh"
check_script_link "fix-links"
check_script_link "deploy-harness"

printf '\nSummary: %d issue(s), %d fix(es) applied, %d unresolved\n' "$ISSUES" "$FIXED" "$UNRESOLVED"

if [ "$ISSUES" -gt 0 ] && { [ "$FIX" -eq 0 ] || [ "$UNRESOLVED" -gt 0 ]; }; then
  exit 1
fi
