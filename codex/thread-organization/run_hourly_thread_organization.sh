#!/bin/zsh
set -eu

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SCRIPT="$CODEX_HOME/thread-organization/build_thread_organization.py"
LOCK_DIR="$CODEX_HOME/thread-organization/.hourly.lock"
LOG_DIR="$HOME/Library/Logs"
OUT_LOG="$LOG_DIR/codex-thread-organization-hourly.log"
ERR_LOG="$LOG_DIR/codex-thread-organization-hourly.err"

mkdir -p "$LOG_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  printf '%s skipped: previous run still active\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$OUT_LOG"
  exit 0
fi

cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

printf '%s start\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$OUT_LOG"
/usr/bin/python3 "$SCRIPT" >> "$OUT_LOG" 2>> "$ERR_LOG"
printf '%s done\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$OUT_LOG"
