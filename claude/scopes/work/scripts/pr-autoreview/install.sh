#!/bin/bash
set -euo pipefail

ENTRY='[ -r "$HOME/.claude/scripts/pr-autoreview/hook-entry.sh" ] && . "$HOME/.claude/scripts/pr-autoreview/hook-entry.sh"'
MARKER="pr-autoreview/hook-entry.sh"

install_init_file() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  if [ -f "$target" ] && grep -qF "$MARKER" "$target"; then
    echo "already wired: $target"
    return
  fi
  printf '%s\n' "$ENTRY" >> "$target"
  echo "wired: $target"
}

install_init_file "$HOME/.huskyrc"
install_init_file "${XDG_CONFIG_HOME:-$HOME/.config}/husky/init.sh"

for repo in \
  "$HOME/work/agent-nodejs" \
  "$HOME/work/zendesk/employer-for-zendesk"
do
  [ -d "$repo/.husky" ] || { echo "no .husky in $repo, skip"; continue; }
  hook="$repo/.husky/pre-push"
  if [ -f "$hook" ]; then
    echo "pre-push already exists: $hook"
    continue
  fi
  if [ -f "$repo/.husky/_/husky.sh" ] && ! grep -q DEPRECATED "$repo/.husky/_/husky.sh" 2>/dev/null; then
    printf '#!/bin/sh\n. "$(dirname "$0")/_/husky.sh"\n\nexit 0\n' > "$hook"
  else
    printf 'exit 0\n' > "$hook"
  fi
  chmod +x "$hook"
  echo "created: $hook"
done

echo
echo "Verify nothing leaks into git:"
for repo in "$HOME/work/agent-nodejs" "$HOME/work/zendesk/employer-for-zendesk"; do
  printf '%-45s ' "$repo"
  if git -C "$repo" status --porcelain .husky/pre-push 2>/dev/null | grep -q .; then
    echo "VISIBLE TO GIT — fix ~/.gitignore_global"
  else
    echo "invisible to git"
  fi
done
