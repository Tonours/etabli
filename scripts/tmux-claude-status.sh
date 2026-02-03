#!/bin/sh
set -eu

# Lightweight tmux status helper; show Claude session count if running.
if ! command -v claude >/dev/null 2>&1; then
  exit 0
fi

count="0"
if command -v pgrep >/dev/null 2>&1; then
  count="$(pgrep -x claude 2>/dev/null | wc -l | tr -d ' ')"
else
  count="$(ps -ax -o comm= | grep -cx "claude" 2>/dev/null || true)"
fi

if [ "${count:-0}" -gt 0 ]; then
  printf " claude:%s " "$count"
fi
