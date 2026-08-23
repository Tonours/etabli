#!/usr/bin/env bash

# Keep `agent` for Cursor (`~/.local/bin/agent`). Grok stays on `grok`.
# The Grok installer also ships ~/.grok/bin/agent and prepends that dir.

prefer_cursor_agent_hook_begin='# >>> etabli prefer cursor agent >>>'
prefer_cursor_agent_hook_end='# <<< etabli prefer cursor agent <<<'
prefer_cursor_agent_grok_installer_end='# <<< grok installer <<<'

prefer_cursor_agent_is_grok_collision() {
  local agent_path="$1"
  local grok_path="$2"

  if [ ! -e "$agent_path" ] && [ ! -L "$agent_path" ]; then
    return 1
  fi
  if [ -L "$agent_path" ]; then
    # A symlink is a collision only if it resolves to the grok binary;
    # a user-managed link to something else must survive.
    if [ -e "$grok_path" ] && [ "$(readlink -f "$agent_path" 2>/dev/null)" = "$(readlink -f "$grok_path" 2>/dev/null)" ]; then
      return 0
    fi
    return 1
  fi
  if [ -e "$grok_path" ] && [ "$agent_path" -ef "$grok_path" ]; then
    return 0
  fi
  return 1
}

prefer_cursor_agent_remove_grok_collision() {
  local home_dir="${1:-$HOME}"
  local agent_path="$home_dir/.grok/bin/agent"
  local grok_path="$home_dir/.grok/bin/grok"

  if prefer_cursor_agent_is_grok_collision "$agent_path" "$grok_path"; then
    rm -f "$agent_path"
  fi
}

prefer_cursor_agent_hook_text() {
  cat <<'EOF'
# >>> etabli prefer cursor agent >>>
# Grok CLI also ships `agent`; keep that name for Cursor (`~/.local/bin/agent`).
# Launch Grok with `grok`.
if [ -e "${HOME}/.grok/bin/agent" ] || [ -L "${HOME}/.grok/bin/agent" ]; then
  if { [ -L "${HOME}/.grok/bin/agent" ] && [ -e "${HOME}/.grok/bin/grok" ] && [ "$(readlink -f "${HOME}/.grok/bin/agent" 2>/dev/null)" = "$(readlink -f "${HOME}/.grok/bin/grok" 2>/dev/null)" ]; } || { [ ! -L "${HOME}/.grok/bin/agent" ] && [ -e "${HOME}/.grok/bin/grok" ] && [ "${HOME}/.grok/bin/agent" -ef "${HOME}/.grok/bin/grok" ]; }; then
    rm -f "${HOME}/.grok/bin/agent"
    hash -r 2>/dev/null || true
  fi
fi
# <<< etabli prefer cursor agent <<<
EOF
}

prefer_cursor_agent_ensure_shell_hook() {
  local rcfile="$1"
  local begin="$prefer_cursor_agent_hook_begin"
  local end="$prefer_cursor_agent_hook_end"
  local grok_end="$prefer_cursor_agent_grok_installer_end"
  local tmp_file hook

  if [ ! -f "$rcfile" ] && [ "$rcfile" != "${HOME}/.zshrc" ] && [ "$rcfile" != "${HOME}/.bashrc" ]; then
    return 0
  fi

  touch "$rcfile" 2>/dev/null || return 1
  hook="$(prefer_cursor_agent_hook_text)" || return 1
  tmp_file="$(mktemp)" || return 1

  if grep -Fxq "$begin" "$rcfile"; then
    if HOOK="$hook" BEGIN="$begin" END="$end" awk '
      BEGIN { hook = ENVIRON["HOOK"] }
      $0 == ENVIRON["BEGIN"] {
        skip = 1
        print hook
        printed = 1
        next
      }
      skip && $0 == ENVIRON["END"] {
        skip = 0
        next
      }
      skip { next }
      { print }
      END {
        if (skip) {
          exit 1
        }
      }
    ' "$rcfile" >"$tmp_file" && cp "$tmp_file" "$rcfile"; then
      rm -f "$tmp_file"
      return 0
    fi
  else
    if HOOK="$hook" GROK_END="$grok_end" awk '
      BEGIN { hook = ENVIRON["HOOK"] }
      $0 == ENVIRON["GROK_END"] {
        print
        if (!printed) {
          print ""
          print hook
          printed = 1
        }
        next
      }
      { print }
      END {
        if (!printed) {
          if (NR > 0) {
            print ""
          }
          print hook
        }
      }
    ' "$rcfile" >"$tmp_file" && cp "$tmp_file" "$rcfile"; then
      rm -f "$tmp_file"
      return 0
    fi
  fi

  rm -f "$tmp_file"
  return 1
}
