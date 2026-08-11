#!/bin/bash
# Runs inside the disposable tmux session: real interactive Claude instance
# (full claude.ai connector auth) fed with prompts/<name>.md.
NAME="${1:?usage: inner.sh <routine-name>}"
CLAUDE=""
[ -r "$HOME/.claude/scripts/claude-bin.sh" ] && . "$HOME/.claude/scripts/claude-bin.sh"
[ -n "$CLAUDE" ] || { echo "claude binary not found" >&2; exit 1; }
cd "$HOME"
exec "$CLAUDE" \
  --dangerously-skip-permissions \
  "$(cat "$HOME/.claude/scripts/routines/prompts/$NAME.md")"
