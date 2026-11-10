#!/bin/bash
set -uo pipefail
umask 077
KEY="${1:?}" TOKEN="${2:?}" MODE="${3:?}" SHA="${4:?}" ATTEMPT="${5:?}"
HERE="$(cd "$(dirname "$0")" && pwd)"
canonical_key="$(cd "$(dirname "$KEY")" && pwd -P)/${KEY##*/}" || exit 1
if [ "$KEY" != "$canonical_key" ]; then shift; exec "$HERE/launch-run.sh" "$canonical_key" "$@"; fi
shift 5
. "$HERE/lifecycle.sh" || exit 1
status_age() { echo $(( $(date +%s) - $(perl -e 'print((stat shift)[9] // time)' "$1.status") )); }
deferred() {
  if [ "$TOKEN" = - ]; then echo 'review launch deferred: execution or reservation already exists' >&2; exit 75; fi
  exit 0
}
take_execution "$KEY" || deferred
child=''
owned=0
finish_launch() {
  local rc=$? pid
  if [ "$owned" = 1 ] && [ "$(cat "$KEY.execution/pid" 2>/dev/null)" = "$$" ]; then
    if [ "$MODE" != approve ]; then
      if [ "$TOKEN" = - ] || [ "$(cat "$KEY.token" 2>/dev/null)" = "$TOKEN" ]; then
        write_run_status "$KEY" "$SHA" "$MODE" "$rc" "$ATTEMPT"
      fi
    fi
    pid="$(cat "$KEY.pid" 2>/dev/null)"
    if [ "$pid" = "$$" ] || { [ -n "$child" ] && [ "$pid" = "$child" ]; }; then rm -f "$KEY.pid"; fi
  fi
  release_execution "$KEY"
}
stop_launch() {
  local rc="$1"
  if [ -n "$child" ]; then kill -TERM "$child" 2>/dev/null; wait "$child" 2>/dev/null; fi
  exit "$rc"
}
trap finish_launch EXIT
trap 'stop_launch 129' HUP
trap 'stop_launch 130' INT
trap 'stop_launch 143' TERM
if [ "$TOKEN" != - ]; then
  [ "$(cat "$KEY.token" 2>/dev/null)" = "$TOKEN" ] || exit 0
  [ "$(cat "$KEY.claimed" 2>/dev/null)" != "$TOKEN" ] || exit 0
  [ "$(cat "$KEY.status" 2>/dev/null)" = "$(printf '%s\t%s\trunning\t%s' "$SHA" "$MODE" "$ATTEMPT")" ] || exit 0
  printf '%s\n' "$TOKEN" >"$KEY.claimed" || exit 1
else
  # Legacy/direct CLI cannot overtake a pending asynchronous delivery.
  run_reserved "$KEY" && deferred
  rm -f "$KEY.token" "$KEY.claimed"
fi
[ "$(cat "$KEY.execution/pid" 2>/dev/null)" = "$$" ] || deferred
owned=1
printf '%s\n' "$TOKEN" >"$KEY.execution/token"
if [ -f "${PR_REVIEW_WATCH_STATE_DIR:-$HOME/.claude/state/pr-review-watch}/off" ]; then
  if [ "$MODE" != approve ]; then printf '%s\t%s\n' "$SHA" "$ATTEMPT" >"$KEY.paused"; fi
  exit 75
fi
rm -f "$KEY.paused"
printf '%s\n' "$$" >"$KEY.pid"
[ "$MODE" = approve ] || write_run_status "$KEY" "$SHA" "$MODE" running "$ATTEMPT"
export PR_REVIEW_WATCH_SUPERVISOR="$$" PR_REVIEW_WATCH_RUN_KEY="$KEY" PR_REVIEW_WATCH_RUN_TOKEN="$TOKEN"
"$@" & child=$!
printf '%s\n' "$child" >"$KEY.pid"
rc=0
wait "$child" || rc=$?
exit "$rc"
