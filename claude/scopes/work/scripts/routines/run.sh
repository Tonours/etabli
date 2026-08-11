#!/bin/bash
# run.sh <routine-name> — generic launcher for local Claude routines.
# Spawns a real interactive Claude instance in a disposable tmux session (full
# claude.ai connector auth: Slack, Linear), feeds it prompts/<name>.md, waits
# for the done-marker, then kills the tmux session. Scheduled by launchd.
# GitHub access uses the local gh CLI (sees private repos), not the cloud MCP.
set -u

NAME="${1:?usage: run.sh <routine-name>}"
DIR="$HOME/.claude/scripts/routines"
PROMPT="$DIR/prompts/$NAME.md"
[ -f "$PROMPT" ] || { echo "no prompt: $PROMPT" >&2; exit 1; }

# Weekdays only by default; a prompt may run any day. Routines that must run on
# weekends should set WEEKEND=1 in their launchd plist env.
if [ "${WEEKEND:-0}" != "1" ] && [ "$(date +%u)" -ge 6 ]; then exit 0; fi

TMUX_BIN="/opt/homebrew/bin/tmux"
SESSION="routine-$NAME"
MARKER="/tmp/routine-$NAME.done"
LOG="$HOME/.claude/logs/routine-$NAME.log"
TIMEOUT="${TIMEOUT:-1200}"

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "=== $(date '+%F %T') start $NAME ==="

if "$TMUX_BIN" has-session -t "$SESSION" 2>/dev/null; then
  echo "session already running, abort"; exit 0
fi
rm -f "$MARKER"

"$TMUX_BIN" new-session -d -s "$SESSION" "NAME='$NAME' bash $DIR/inner.sh '$NAME'"

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
echo "=== $(date '+%F %T') end $NAME ==="
