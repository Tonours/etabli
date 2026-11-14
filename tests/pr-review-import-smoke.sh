#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-review-import.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home" PR_REVIEW_WATCH_STATE_DIR="$TMP_DIR/state"
mkdir -p "$HOME" "$TMP_DIR/bin"
export PATH="$TMP_DIR/bin:$PATH"
export FAKE_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
cat >"$TMP_DIR/bin/gh" <<'GH'
#!/bin/bash
[ "$1 $2" = 'pr view' ] || exit 1
result="$(jq -cn --arg head "$FAKE_HEAD" '{author:{login:"other"},state:"OPEN",headRefOid:$head}')"
if [[ "$*" == *'--jq .author.login'* ]]; then echo other; else printf '%s\n' "$result"; fi
GH
chmod +x "$TMP_DIR/bin/gh"
. "$ROOT_DIR/claude/scopes/work/scripts/pr-council-review/lib.sh"
. "$ROOT_DIR/claude/scopes/work/scripts/pr-review-watch/register.sh"
STATE_DIR="$PR_REVIEW_WATCH_STATE_DIR"
RUNS="$STATE_DIR/runs" REPORTS="$STATE_DIR/reports" WATCHED="$STATE_DIR/watched.tsv"
LAUNCH_GRACE_SECONDS=180
mkdir -p "$RUNS" "$REPORTS"
: >"$WATCHED"
log() { printf '%s\n' "$*" >>"$TMP_DIR/log"; }
notify() { printf '%s\n' "$*" >>"$TMP_DIR/notifications"; }
run_key() { printf '%s/%s_%s' "$RUNS" "${1//\//_}" "$2"; }
run_alive() { return 1; }
status_age() { echo "${TEST_STATUS_AGE:-0}"; }
report="$TMP_DIR/report"
printf '=== phase B: \n<!-- claudine:v1 {"kind":"run","run":"r","sha":"%s","findings":0,"floor":"should-fix","suppressed":0,"security":"clean","lenses":["done"]} -->\n' "$FAKE_HEAD" >"$report"
write_watch_heartbeat me
failures=0
check() { if "$@"; then printf 'ok %s\n' "$*"; else printf 'FAIL %s\n' "$*"; failures=$((failures+1)); fi; }

# A delayed full council cannot replace any completed same-head verification,
# veto, or incomplete decision, even when no same-head council report exists.
number=20
for decision in $'verify\t0' $'verify\t3' $'council\t4'; do
  number=$((number+1)); key="$(run_key o/r "$number")"
  submit_council_registration o/r "$number" "$FAKE_HEAD" me "$report" approve >/dev/null
  printf '%s\t%s\t3\n' "$FAKE_HEAD" "$decision" >"$key.status"
  cp "$key.status" "$TMP_DIR/status"
  ingest_council_registrations me
  check cmp -s "$key.status" "$TMP_DIR/status"
  check test ! -e "$key.approval-pending"
done

# An old-head report must not rearm a veto on the current head.
key="$(run_key o/r 24)"
submit_council_registration o/r 24 "$FAKE_HEAD" me "$report" approve >/dev/null
export FAKE_HEAD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
printf '%s\tverify\t3\t3\n' "$FAKE_HEAD" >"$key.status"
cp "$key.status" "$TMP_DIR/status"
ingest_council_registrations me
check cmp -s "$key.status" "$TMP_DIR/status"
check test ! -e "$key.approval-pending"

# A registered baseline requires its normal follow-up verify; direct clean
# review on a later head cannot take initial-approval authority.
key="$(run_key o/r 25)"
printf '%s\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa >"$key.council-done"
sed 's/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/' "$report" >"$TMP_DIR/report-b"
submit_council_registration o/r 25 "$FAKE_HEAD" me "$TMP_DIR/report-b" approve >/dev/null
ingest_council_registrations me
check test ! -e "$key.approval-pending"
check grep -qx aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$key.council-done"

# A dead runner is deferred during launch grace, then a completed registration
# may recover it; importing proof launches no additional model attempt.
key="$(run_key o/r 26)"
submit_council_registration o/r 26 "$FAKE_HEAD" me "$TMP_DIR/report-b" follow >/dev/null
printf '%s\tverify\trunning\t3\n' "$FAKE_HEAD" >"$key.status"
TEST_STATUS_AGE=179 ingest_council_registrations me
check test ! -e "$key.registered"
TEST_STATUS_AGE=600 ingest_council_registrations me
check test -e "$key.registered"

# A dead launch may recover its own head, but cannot erase another head's stop.
for number in 29 30; do
  key="$(run_key o/r "$number")"
  printf '%s\n' "$FAKE_HEAD" >"$key.exhausted"
  stopped_status_head="$FAKE_HEAD"
  [ "$number" != 29 ] || stopped_status_head=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  printf '%s\tcouncil\trunning\t3\n' "$stopped_status_head" >"$key.status"
  cp "$key.status" "$TMP_DIR/status"
  submit_council_registration o/r "$number" "$FAKE_HEAD" me "$TMP_DIR/report-b" approve >/dev/null
  TEST_STATUS_AGE=600 ingest_council_registrations me
  if [ "$number" = 29 ]; then
    check cmp -s "$key.status" "$TMP_DIR/status"
    check test ! -e "$key.approval-pending"
  else
    check grep -qx "$FAKE_HEAD" "$key.approval-pending"
  fi
done

# Initial ownership stays with Fleet on an equal clean direct handoff; the
# watcher explicitly notifies rather than claiming it queued another approver.
submit_council_registration o/r 27 "$FAKE_HEAD" me "$TMP_DIR/report-b" follow >/dev/null
ingest_council_registrations me
submit_council_registration o/r 27 "$FAKE_HEAD" me "$TMP_DIR/report-b" approve >/dev/null
ingest_council_registrations me
check test ! -e "$(run_key o/r 27).approval-pending"
check test -s "$TMP_DIR/notifications"

# Uncontested clean initial approval remains eligible.
submit_council_registration o/r 28 "$FAKE_HEAD" me "$TMP_DIR/report-b" approve >/dev/null
ingest_council_registrations me
check grep -qx "$FAKE_HEAD" "$(run_key o/r 28).approval-pending"

# A full deferred batch resumes after bounded launch grace; no envelope is lost
# and the 65th entry is consumed on the next bounded pass.
for number in $(seq 100 164); do
  submit_council_registration o/r "$number" "$FAKE_HEAD" me "$TMP_DIR/report-b" follow >/dev/null
  printf '%s\tverify\trunning\t3\n' "$FAKE_HEAD" >"$(run_key o/r "$number").status"
done
records() { find "$STATE_DIR/register" -name '*.json' | wc -l | tr -d ' '; }
TEST_STATUS_AGE=179 ingest_council_registrations me
check test "$(records)" = 65
TEST_STATUS_AGE=600 ingest_council_registrations me
check test "$(records)" = 1
TEST_STATUS_AGE=600 ingest_council_registrations me
check test "$(records)" = 0

# A dry-run outcome is no posting decision: a posting registration of the same head lands
# and retires the dry-run intent.
key="$(run_key o/r 40)"
sed "s/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/$FAKE_HEAD/" "$report" >"$TMP_DIR/report-dry"
printf '%s\tdryrun\t0\t1\n' "$FAKE_HEAD" >"$key.status"
printf '%s\tauthor\n' "$FAKE_HEAD" >"$key.dryrun"
submit_council_registration o/r 40 "$FAKE_HEAD" me "$TMP_DIR/report-dry" follow >/dev/null
TEST_STATUS_AGE=600 ingest_council_registrations me
check test -e "$key.registered"
check test ! -e "$key.dryrun"
test "$failures" = 0
