#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-review-registration.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home" PR_REVIEW_WATCH_STATE_DIR="$TMP_DIR/state"
export PR_COUNCIL_CLAUDE=/usr/bin/false PR_COUNCIL_CODEX=/usr/bin/false
mkdir -p "$HOME" "$PR_REVIEW_WATCH_STATE_DIR" "$TMP_DIR/bin"
export PATH="$TMP_DIR/bin:$PATH"
cat >"$TMP_DIR/bin/gh" <<'GH'
#!/bin/bash
case "$1 $2" in
  "pr view")
    if [[ "$*" == *'--json author,state,headRefOid'* ]]; then
      jq -cn --arg login "${FAKE_AUTHOR:-other}" '{author:{login:$login},state:"OPEN",headRefOid:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}'
    else printf '%s\n' "${FAKE_AUTHOR:-other}"; fi ;;
  *) exit 1 ;;
esac
GH
chmod +x "$TMP_DIR/bin/gh"
. "$ROOT_DIR/claude/scopes/work/scripts/pr-council-review/lib.sh"
. "$ROOT_DIR/claude/scopes/work/scripts/pr-review-watch/register.sh"

SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
REPORT="$TMP_DIR/report.md"
printf '=== phase B: \n<!-- claudine:v1 {"kind":"run","run":"r","sha":"%s","findings":0,"floor":"should-fix","suppressed":0,"security":"clean","lenses":["done"]} -->\n' "$SHA" >"$REPORT"
export STATE_DIR="$PR_REVIEW_WATCH_STATE_DIR"
export RUNS="$STATE_DIR/runs" REPORTS="$STATE_DIR/reports"
mkdir -p "$RUNS" "$REPORTS"
WATCHED="$STATE_DIR/watched.tsv"; : >"$WATCHED"
log() { printf '%s\n' "$*"; }
notify() { printf '%s\n' "$*" >>"$TMP_DIR/notifications"; }
LAUNCH_GRACE_SECONDS=180
status_age() { echo 0; }
run_key() { printf '%s/%s_%s' "$RUNS" "${1//\//_}" "$2"; }
run_alive() { [ -f "$1.test-running" ]; }
count_records() { find "$STATE_DIR/register" -name '*.json' 2>/dev/null | wc -l | tr -d ' '; }

# A direct clean council transfers initial approval only to a ready watcher.
out="$(submit_council_registration o/r 7 "$SHA" me "$REPORT" approve)"
[[ "$out" == '=== watcher: not queued ('* ]] || { echo "missing readiness refusal: $out"; exit 1; }
write_watch_heartbeat me
out="$(submit_council_registration o/r 7 "$SHA" me "$REPORT" approve)"
[[ "$out" == "=== watcher: submitted $SHA (approval by the watcher once ingested)" ]] || exit 1
[ ! -s "$WATCHED" ] || { echo "sender must not rewrite watched.tsv"; exit 1; }
ingest_council_registrations me
KEY="$(run_key o/r 7)"
[ "$(cat "$KEY.council-clean")" = "$SHA" ]
[ "$(cat "$KEY.approval-pending")" = "$SHA" ]
[ "$(cat "$KEY.watermark")" = "$SHA" ]
[ "$(count_records)" = 0 ]
validator_run_findings "$REPORTS/o_r-7-aaaaaaaa-council.md" "$SHA" >/dev/null

# Fleet keeps its initial verification/approval; only later heads are watched.
out="$(submit_council_registration o/r 8 "$SHA" me "$REPORT" follow)"
[[ "$out" == "=== watcher: following $SHA (approval not queued)" ]] || exit 1
ingest_council_registrations me
[ -f "$(run_key o/r 8).council-clean" ]
[ ! -e "$(run_key o/r 8).approval-pending" ]

# Running state defers the immutable envelope; a restart can ingest it later.
submit_council_registration o/r 9 "$SHA" me "$REPORT" follow >/dev/null
printf '%s\tverify\trunning\t1\n' "$SHA" >"$(run_key o/r 9).status"
ingest_council_registrations me
[ "$(count_records)" = 1 ]
rm "$(run_key o/r 9).status"
ingest_council_registrations me
[ "$(count_records)" = 0 ]

# Account and author identity cannot be borrowed from a caller's report.
out="$(FAKE_AUTHOR=me submit_council_registration o/r 10 "$SHA" me "$REPORT" approve)"
[[ "$out" == '=== watcher: not queued ('* ]] || exit 1
submit_council_registration o/r 11 "$SHA" me "$REPORT" follow >/dev/null
ingest_council_registrations another
[ ! -e "$(run_key o/r 11).registered" ]

# A contradictory same-head review revokes pending clean approval, and findings
# are derived from report bytes rather than the caller's declared count.
sed 's/"findings":0/"findings":2/' "$REPORT" >"$TMP_DIR/findings.md"
submit_council_registration o/r 7 "$SHA" me "$TMP_DIR/findings.md" follow >/dev/null
record="$(find "$STATE_DIR/register" -name '*.json' | head -1)"
jq '.findings=0' "$record" >"$TMP_DIR/forged.json"
mv "$TMP_DIR/forged.json" "$record"
ingest_council_registrations me
[ ! -e "$KEY.approval-pending" ] && [ ! -e "$KEY.council-clean" ]
[ "$(validator_run_findings "$REPORTS/o_r-7-aaaaaaaa-council.md" "$SHA")" = 2 ]

# Delayed genuine clean completion cannot erase a later blocking same-head run.
submit_council_registration o/r 7 "$SHA" me "$REPORT" approve >/dev/null
ingest_council_registrations me
[ ! -e "$KEY.approval-pending" ] && [ ! -e "$KEY.council-clean" ]
[ "$(validator_run_findings "$REPORTS/o_r-7-aaaaaaaa-council.md" "$SHA")" = 2 ]

# Producers can publish concurrently without changing the watched list or
# writing over another completed registration.
submit_council_registration o/r 12 "$SHA" me "$REPORT" follow >/dev/null &
first=$!
submit_council_registration o/r 13 "$SHA" me "$REPORT" follow >/dev/null &
second=$!
wait "$first"; wait "$second"
[ "$(count_records)" = 2 ]
ingest_council_registrations me
[ -e "$(run_key o/r 12).registered" ] && [ -e "$(run_key o/r 13).registered" ]
printf 'me\t0\n' >"$STATE_DIR/heartbeat"
out="$(submit_council_registration o/r 14 "$SHA" me "$REPORT" approve)"
[[ "$out" == '=== watcher: not queued ('* ]] || exit 1
write_watch_heartbeat another
out="$(submit_council_registration o/r 15 "$SHA" me "$REPORT" approve)"
[[ "$out" == '=== watcher: not queued ('* ]] || exit 1

# Invalid neighbors exercise the actual producer boundaries, not a mocked gate.
refused() {
  local result
  result="$(submit_council_registration "$@")"
  [[ "$result" == '=== watcher: not queued ('* ]] || { printf 'unsafe registration: %s\n' "$result"; return 1; }
}
PR_REVIEW_WATCH_STATE_DIR="$TMP_DIR/new-root" write_watch_heartbeat me
[ -f "$TMP_DIR/new-root/heartbeat" ]
write_watch_heartbeat me
touch "$STATE_DIR/off"
refused o/r 16 "$SHA" me "$REPORT" approve
rm "$STATE_DIR/off"
mv "$STATE_DIR/heartbeat" "$STATE_DIR/real-heartbeat"
ln -s "$STATE_DIR/real-heartbeat" "$STATE_DIR/heartbeat"
refused o/r 16 "$SHA" me "$REPORT" approve
rm "$STATE_DIR/heartbeat"
mv "$STATE_DIR/real-heartbeat" "$STATE_DIR/heartbeat"
perl -e 'print "padding\n" x 50' >>"$STATE_DIR/heartbeat"
refused o/r 16 "$SHA" me "$REPORT" approve
write_watch_heartbeat me
refused invalid-repo 16 "$SHA" me "$REPORT" follow
refused o/r 0 "$SHA" me "$REPORT" follow
refused o/r 2147483648 "$SHA" me "$REPORT" follow
refused o/r 16 "$SHA" 'bad/login' "$REPORT" follow
sed "s/$SHA/not-a-sha/" "$REPORT" >"$TMP_DIR/bad-sha"
refused o/r 16 not-a-sha me "$TMP_DIR/bad-sha" follow
ln -s "$REPORT" "$TMP_DIR/report-link"
refused o/r 16 "$SHA" me "$TMP_DIR/report-link" follow
cp "$REPORT" "$TMP_DIR/large-report"
perl -e 'print "x" x 1048577' >>"$TMP_DIR/large-report"
refused o/r 16 "$SHA" me "$TMP_DIR/large-report" follow
printf 'ok registration: single writer, clean proof, follow-only, restart and identity\n'
