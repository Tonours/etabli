#!/bin/bash
# Runs inside the disposable tmux session: real interactive Claude instance
# (full MCP auth), fed with the sessions-report prompt.
CLAUDE=""
[ -r "$HOME/.claude/scripts/claude-bin.sh" ] && . "$HOME/.claude/scripts/claude-bin.sh"
[ -n "$CLAUDE" ] || { echo "claude binary not found" >&2; exit 1; }
cd "$HOME"
exec "$CLAUDE" \
  --dangerously-skip-permissions \
  "$(cat "$HOME/.claude/scripts/sessions-report-prompt.md")"
