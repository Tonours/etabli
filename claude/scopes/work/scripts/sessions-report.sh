#!/bin/bash
# sessions-report.sh — posts a summary of yesterday's Claude Code sessions to
# Slack #routines. Spawns a REAL interactive Claude instance in a disposable
# tmux session (full MCP auth, unlike `claude -p`), waits for the done-marker,
# then kills the tmux session. Scheduled by launchd (com.<account>.claude-sessions-report).
set -u

# Weekdays only (launchd fires daily; launchd catches up missed runs on wake)
[ "$(date +%u)" -ge 6 ] && exit 0

TMUX_BIN="/opt/homebrew/bin/tmux"
SESSION="claude-sessions-report"
MARKER="/tmp/claude-sessions-report.done"
LOG="$HOME/.claude/logs/sessions-report.log"
TIMEOUT=1200 # 20 min hard cap

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "=== $(date '+%F %T') start ==="

if "$TMUX_BIN" has-session -t "$SESSION" 2>/dev/null; then
  echo "session already running, abort"
  exit 0
fi
rm -f "$MARKER"

"$TMUX_BIN" new-session -d -s "$SESSION" "bash $HOME/.claude/scripts/sessions-report-inner.sh"

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  [ -f "$MARKER" ] && break
  sleep 15
  elapsed=$((elapsed + 15))
done

"$TMUX_BIN" kill-session -t "$SESSION" 2>/dev/null
if [ -f "$MARKER" ]; then
  echo "done OK after ${elapsed}s"
else
  echo "TIMEOUT after ${TIMEOUT}s — session killed without marker"
fi
echo "=== $(date '+%F %T') end ==="
