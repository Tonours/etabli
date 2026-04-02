#!/bin/sh
set -eu

# Copy stdin to system clipboard with best available tool.
if command -v pbcopy >/dev/null 2>&1; then
  pbcopy
  exit 0
fi

if command -v wl-copy >/dev/null 2>&1; then
  wl-copy
  exit 0
fi

if command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard
  exit 0
fi

if command -v xsel >/dev/null 2>&1; then
  xsel --clipboard --input
  exit 0
fi

# Fallback: OSC52 (best effort)
if command -v base64 >/dev/null 2>&1; then
  data="$(base64 | tr -d '\n')"
  printf "\033]52;c;%s\a" "$data"
  exit 0
fi

# No clipboard tool available; discard input.
cat >/dev/null
