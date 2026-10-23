#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPTS="$ROOT_DIR/claude/scopes/work/scripts"
mkdir -p "$HOME/.cache"
TMP_DIR="$(mktemp -d "$HOME/.cache/pr-review-signals-smoke.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
export TMPDIR="$TMP_DIR"

failures=0
check() {
  local label="$1"
  shift
  if "$@"; then
    printf 'ok   %s\n' "$label"
  else
    printf 'FAIL %s\n' "$label"
    failures=$((failures + 1))
  fi
}

cat >"$TMP_DIR/standin.sh" <<'STANDIN'
#!/bin/bash
sleep 30017 &
sleep 30017
STANDIN
cat >"$TMP_DIR/standin-traps.sh" <<'STANDIN'
#!/bin/bash
trap 'echo INT >>"$1"' INT
trap 'echo TERM >>"$1"' TERM
while :; do sleep 0.1; done
STANDIN
chmod +x "$TMP_DIR/standin.sh" "$TMP_DIR/standin-traps.sh"

survivors() { pgrep -f "$1" | tr '\n' ' '; }

signal_runner() {
  local runner
  perl -e '$SIG{INT} = "DEFAULT"; exec @ARGV' /bin/bash -c \
    ". '$SCRIPTS/pr-council-review/lib.sh'; run_with_timeout 60 '$TMP_DIR/standin.sh'" &
  runner=$!
  sleep 1
  kill "-$1" "$runner"
  wait "$runner" 2>/dev/null || true
  sleep 0.5
}

case_signals() {
  signal_runner INT
  check "signals: INT leaves no stand-in" [ -z "$(survivors 'sleep 30017')" ]
  signal_runner TERM
  check "signals: TERM leaves no stand-in" [ -z "$(survivors 'sleep 30017')" ]
  signal_runner HUP
  check "signals: HUP leaves no stand-in" [ -z "$(survivors 'sleep 30017')" ]
  check "signals: the caller's traps come back" eval '[ "$(/bin/bash -c ". '"'"'$SCRIPTS/pr-council-review/lib.sh'"'"'; trap \"echo x\" TERM; run_with_timeout 5 true; trap -p TERM")" = "trap -- '"'"'echo x'"'"' SIGTERM" ]'
  local started elapsed rc=0
  started="$(date +%s)"
  PR_REVIEW_STOP_GRACE=1 /bin/bash -c ". '$SCRIPTS/pr-council-review/lib.sh'; run_with_timeout 1 '$TMP_DIR/standin-traps.sh' '$TMP_DIR/signals.log'" 2>/dev/null || rc=$?
  elapsed=$(( $(date +%s) - started ))
  check "timeout: exit 124" [ "$rc" = 124 ]
  check "timeout: INT, then TERM, then KILL" [ "$(tr '\n' ' ' <"$TMP_DIR/signals.log")" = "INT TERM " ]
  check "timeout: no stand-in survives" [ -z "$(survivors standin-traps)" ]
  check "timeout: stopped within the grace periods" [ "$elapsed" -lt 6 ]
}

case_signals

if [ "$failures" -ne 0 ]; then
  printf 'PR review signals smoke test: %s failure(s)\n' "$failures"
  exit 1
fi
printf 'PR review signals smoke test: ok\n'
