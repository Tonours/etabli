#!/bin/sh
set -eu

usage() {
  echo "Usage: claude-usage.sh setup"
}

case "${1:-}" in
  setup)
    if [ ! -x "$HOME/.local/bin/tmux-claude-status.sh" ]; then
      echo "tmux-claude-status.sh not found in ~/.local/bin"
      echo "Run scripts/install.sh or copy scripts/tmux-claude-status.sh to ~/.local/bin"
      exit 1
    fi
    if command -v tmux >/dev/null 2>&1 && [ -n "${TMUX:-}" ]; then
      tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 || true
    fi
    echo "Claude status enabled in tmux"
    ;;
  *)
    usage
    exit 1
    ;;
esac
