#!/bin/bash

# Read JSON input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd')
DIR=$(basename "$CWD")
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Claude"')
USED=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty')
LEFT=$(echo "$INPUT" | jq -r '.context_window.remaining_percentage // empty')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# robbyrussell-inspired: cyan directory
printf "\033[36m%s\033[0m" "$DIR"

# Git branch: blue "git:(" + red branch + blue ")"
BRANCH=$(git -C "$CWD" --no-optional-locks branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
  DIRTY=$(git -C "$CWD" --no-optional-locks status --porcelain 2>/dev/null)
  if [ -n "$DIRTY" ]; then
    printf " \033[1;34mgit:(\033[31m%s\033[34m)\033[0m \033[33mx\033[0m" "$BRANCH"
  else
    printf " \033[1;34mgit:(\033[31m%s\033[34m)\033[0m" "$BRANCH"
  fi
fi

# Model name (bold white)
printf " \033[1m%s\033[0m" "$MODEL"

# Context usage percentage (if available)
if [ -n "$USED" ]; then
  USED_INT=$(printf "%.0f" "$USED")
  if [ "$USED_INT" -lt 50 ]; then
    CTX_COLOR="\033[32m"
  elif [ "$USED_INT" -lt 80 ]; then
    CTX_COLOR="\033[33m"
  else
    CTX_COLOR="\033[31m"
  fi
  printf " ${CTX_COLOR}ctx:%d%%\033[0m" "$USED_INT"
  if [ -n "$LEFT" ]; then
    printf " ${CTX_COLOR}(%d%% left)\033[0m" "$(printf "%.0f" "$LEFT")"
  fi
fi

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  TPS=$(python3 "$HOME/.claude/statusline-tps.py" "$TRANSCRIPT" 2>/dev/null)
  if [ -n "$TPS" ]; then
    printf " \033[35m%s tok/s\033[0m" "$TPS"
  fi
fi

echo
