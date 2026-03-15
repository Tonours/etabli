#!/usr/bin/env bash

set -euo pipefail

login_shell="${SHELL:-/bin/zsh}"

if [ -n "${TMUX:-}" ]; then
    exec "$login_shell" -l
fi

if command -v tmux >/dev/null 2>&1; then
    exec tmux new-session -A -s main
fi

exec "$login_shell" -l
