#!/bin/bash

resolve_claude_bin() {
  local candidate
  for candidate in \
    "$HOME/.local/share/fnm/aliases/default/bin/claude" \
    "$HOME/.local/bin/claude" \
    "$(ls -t "$HOME"/.local/share/fnm/node-versions/*/installation/bin/claude 2>/dev/null | head -1)" \
    "$(ls -t "$HOME"/.nvm/versions/node/*/bin/claude 2>/dev/null | head -1)" \
    /opt/homebrew/bin/claude
  do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  command -v claude 2>/dev/null || return 1
}

CLAUDE="$(resolve_claude_bin || true)"
