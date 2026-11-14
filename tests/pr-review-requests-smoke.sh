#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-review-requests.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home" PR_REVIEW_WATCH_STATE_DIR="$TMP_DIR/state"
mkdir -p "$HOME/.local/bin"
export GH_CALLS="$TMP_DIR/gh.calls" GH_WRITES="$TMP_DIR/gh.writes"
: >"$GH_CALLS"; : >"$GH_WRITES"
export FAKE_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa FAKE_AUTHOR=other FAKE_STATE=OPEN FAKE_DRAFT=false
cat >"$HOME/.local/bin/gh" <<'GH'
#!/bin/bash
# Every call is recorded; every write (assumption A5) goes to gh.writes too.
printf '%s\n' "$*" >>"$GH_CALLS"
case "$1 $2" in
  'pr review'|'pr comment'|'pr edit'|'pr merge'|'pr close'|'pr ready'|'issue '*) printf '%s\n' "$*" >>"$GH_WRITES" ;;
  *) for arg in "$@"; do case "$arg" in -f|-F|--input|-X|--method|--field|--raw-field) printf '%s\n' "$*" >>"$GH_WRITES"; break ;; esac; done ;;
esac
case "$1 $2" in
  'api user') echo me ;;
  'pr view')
    jq -cn --arg head "$FAKE_HEAD" --arg author "$FAKE_AUTHOR" --arg state "$FAKE_STATE" --argjson draft "$FAKE_DRAFT" '{headRefOid:$head,author:{login:$author},state:$state,isDraft:$draft}' ;;
  *) exit 1 ;;
esac
GH
chmod +x "$HOME/.local/bin/gh"
. "$ROOT_DIR/claude/scopes/work/scripts/pr-review-watch/watch.sh" || true
mkdir -p "$RUNS" "$REPORTS"
: >"$WATCHED"
log() { printf '%s\n' "$*" >>"$TMP_DIR/log"; }
write_review_request_ready Me
# Line 1 stays what Fleet v1 parses; line 2 announces protocol v2.
test "$(head -1 "$STATE_DIR/requests/ready" | cut -f1-2)" = $'1\tme'
test "$(sed -n 2p "$STATE_DIR/requests/ready")" = v2
test "$(wc -l <"$STATE_DIR/requests/ready" | tr -d ' ')" = 2
test "$(wc -c <"$STATE_DIR/requests/ready" | tr -d ' ')" -le 64
test "$(perl -e 'printf "%o",(stat shift)[2]&0777' "$STATE_DIR/requests/ready")" = 600
test "$(perl -e 'printf "%o",(stat shift)[2]&0777' "$STATE_DIR/requests")" = 700
stamp="$(head -1 "$STATE_DIR/requests/ready" | cut -f3)"
test "$stamp" -le "$(date +%s)"
test "$(($(date +%s) - stamp))" -lt 5
request() {
  local id="$1" number="$2"
  jq -cn --arg id "$id" --argjson number "$number" --arg sha "$FAKE_HEAD" '{version:1,id:$id,repo:"o/r",number:$number,sha:$sha,login:"me"}' >"$STATE_DIR/requests/$id.json"
}
id=w-00000000000000000000000000000001
request "$id" 7
key="$(run_key o/r 7)"
printf '%s\n' bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb >"$key.council-done"
cp "$key.council-done" "$key.watermark"
printf '%s\tverify\t3\t1\n' "$FAKE_HEAD" >"$key.status"
cp "$key.status" "$TMP_DIR/status"
ingest_review_requests me
test "$(cat "$STATE_DIR/requests/$id.receipt")" = $'accepted\t'"$FAKE_HEAD"
test ! -e "$STATE_DIR/requests/$id.json"
cmp "$key.status" "$TMP_DIR/status"
test "$(cat "$key.council-done")" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
test "$(cat "$key.watermark")" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
test ! -e "$key.approval-pending"
test "$(cat "$key.registered")" = "$FAKE_HEAD"$'\tme'
run_alive() { return 1; }
real_diff_scope="$(declare -f diff_scope)"
diff_scope() { echo 1; }
running_count() { echo 0; }
launched_today() { echo 0; }
launch() { printf '%s\t%s\n' "$5" "$6" >>"$TMP_DIR/launches"; rm -f "$7.requested"; }
consider me o/r 7 "$FAKE_HEAD" url
test ! -e "$TMP_DIR/launches"
fresh=w-00000000000000000000000000000010
request "$fresh" 10
ingest_review_requests me
consider me o/r 10 "$FAKE_HEAD" url
test "$(cat "$TMP_DIR/launches")" = $'council\t-'
test "$(cut -d' ' -f1 "$(run_key o/r 10).seen")" = "$FAKE_HEAD"
test "$(cut -d' ' -f2 "$(run_key o/r 10).seen")" -ge "$stamp"
key10="$(run_key o/r 10)"
printf '%s\n' "$FAKE_HEAD" >"$key10.council-done"
cp "$key10.council-done" "$key10.watermark"
printf '%s\tcouncil\t0\t1\n' "$FAKE_HEAD" >"$key10.status"
export FAKE_HEAD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
request w-00000000000000000000000000000011 10
ingest_review_requests me
consider me o/r 10 "$FAKE_HEAD" url
test "$(tail -1 "$TMP_DIR/launches")" = $'verify\taaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
test "$(cut -f1 "$key10.registered")" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
printf '%s\tverify\t0\t1\n' "$FAKE_HEAD" >"$key10.status"
consider me o/r 10 "$FAKE_HEAD" url
test "$(wc -l <"$TMP_DIR/launches" | tr -d ' ')" = 2
export FAKE_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
request "$id" 7
ingest_review_requests me
test "$(wc -l <"$WATCHED" | tr -d ' ')" = 2
for reason in own closed draft stale account registered-other-account malformed; do
  id=w-00000000000000000000000000000002
  request "$id" 8
  case "$reason" in
    own) export FAKE_AUTHOR=me ;;
    closed) export FAKE_STATE=CLOSED ;;
    draft) export FAKE_DRAFT=true ;;
    stale) export FAKE_HEAD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ;;
    account) sed 's/"me"/"other"/' "$STATE_DIR/requests/$id.json" >"$TMP_DIR/change"; mv "$TMP_DIR/change" "$STATE_DIR/requests/$id.json" ;;
    registered-other-account) printf '%s\tother\n' "$FAKE_HEAD" >"$(run_key o/r 8).registered" ;;
    malformed) echo '{}' >"$STATE_DIR/requests/$id.json" ;;
  esac
  ingest_review_requests me
  grep -q "^rejected"$'\t'"$reason" "$STATE_DIR/requests/$id.receipt"
  test "$(wc -l <"$WATCHED" | tr -d ' ')" = 2
  rm "$STATE_DIR/requests/$id.receipt"
  rm -f "$(run_key o/r 8).registered"
  export FAKE_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa FAKE_AUTHOR=other FAKE_STATE=OPEN FAKE_DRAFT=false
done
id=w-00000000000000000000000000000003
request "$id" 9
touch "$KILL_SWITCH"
ingest_review_requests me
test -e "$STATE_DIR/requests/$id.json"
test ! -e "$STATE_DIR/requests/$id.receipt"
rm "$KILL_SWITCH"
ingest_review_requests me
test -e "$STATE_DIR/requests/$id.receipt"
id=w-00000000000000000000000000000004
request "$id" 11
receipt_function="$(declare -f review_request_receipt)"
review_request_receipt() { return 1; }
ingest_review_requests me
test -e "$STATE_DIR/requests/$id.json"
test ! -e "$STATE_DIR/requests/$id.receipt"
eval "$receipt_function"
ingest_review_requests me
test ! -e "$STATE_DIR/requests/$id.json"
test -e "$STATE_DIR/requests/$id.receipt"
for invalid in extra oversized symlink id-binding; do
  id=w-00000000000000000000000000000005
  request "$id" 12
  case "$invalid" in
    id-binding) jq ' .id="w-00000000000000000000000000000006"' "$STATE_DIR/requests/$id.json" >"$TMP_DIR/change"; mv "$TMP_DIR/change" "$STATE_DIR/requests/$id.json" ;;
    extra) jq '.extra="PRIVATE"' "$STATE_DIR/requests/$id.json" >"$TMP_DIR/change"; mv "$TMP_DIR/change" "$STATE_DIR/requests/$id.json" ;;
    oversized) printf '%02000d' 0 >>"$STATE_DIR/requests/$id.json" ;;
    symlink) mv "$STATE_DIR/requests/$id.json" "$TMP_DIR/outside"; ln -s "$TMP_DIR/outside" "$STATE_DIR/requests/$id.json" ;;
  esac
  ingest_review_requests me
  test "$(cat "$STATE_DIR/requests/$id.receipt")" = $'rejected\tmalformed'
  test ! -e "$(run_key o/r 12).registered"
  rm "$STATE_DIR/requests/$id.receipt"
done
# Fresh automatic, stale-head and foreign-account markers must still settle.
launch_count="$(wc -l <"$TMP_DIR/launches")"
for neighbor in automatic stale foreign symlink; do
  neighbor_key="$(run_key o/r 90)"
  rm -f "$neighbor_key.seen" "$neighbor_key.requested"
  case "$neighbor" in
    stale) printf '%s\tme\n' bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb >"$neighbor_key.requested" ;;
    symlink) printf '%s\tme\n' "$FAKE_HEAD" >"$TMP_DIR/marker-target"; ln -s "$TMP_DIR/marker-target" "$neighbor_key.requested" ;;
    foreign) printf '%s\tother\n' "$FAKE_HEAD" >"$neighbor_key.requested" ;;
  esac
  consider me o/r 90 "$FAKE_HEAD" url
  test "$(wc -l <"$TMP_DIR/launches")" = "$launch_count"
done
# Valid request remains pending under other scheduler gates.
blocked_key="$(run_key o/r 91)"
request w-00000000000000000000000000000091 91
ingest_review_requests me
test "$(cat "$blocked_key.requested")" = "$FAKE_HEAD"$'\tme'
touch "$KILL_SWITCH"
consider me o/r 91 "$FAKE_HEAD" url
rm "$KILL_SWITCH"
test -f "$blocked_key.requested"
test "$(wc -l <"$TMP_DIR/launches")" = "$launch_count"
running_count() { echo "$MAX_CONCURRENT"; }
consider me o/r 91 "$FAKE_HEAD" url
test -f "$blocked_key.requested"
test "$(wc -l <"$TMP_DIR/launches")" = "$launch_count"
running_count() { echo 0; }
launched_today() { echo "$MAX_RUNS_PER_DAY"; }
consider me o/r 91 "$FAKE_HEAD" url
test -f "$blocked_key.requested"
test "$(wc -l <"$TMP_DIR/launches")" = "$launch_count"
launched_today() { echo 0; }
consider me o/r 91 "$FAKE_HEAD" url
test ! -f "$blocked_key.requested"
test "$(wc -l <"$TMP_DIR/launches")" -eq "$((launch_count + 1))"
# Exercise the real policy gate after first-seen bookkeeping: docs never launch.
(
  eval "$real_diff_scope"
  gh() { printf '%s\n' '{"author":{"login":"other","is_bot":false},"files":[{"path":"docs/guide.md","additions":1,"deletions":0}],"changedFiles":1,"additions":1,"deletions":0}'; }
  skipped_key="$(run_key o/r 92)"
  consider me o/r 92 "$FAKE_HEAD" url
  # The first automatic tick settles; the next exercises policy without delay.
  printf '%s %s\n' "$FAKE_HEAD" "$(( $(date +%s) - SETTLE_SECONDS ))" >"$skipped_key.seen"
  consider me o/r 92 "$FAKE_HEAD" url
  test "$(cat "$skipped_key.skipped")" = "$FAKE_HEAD"
  test ! -e "$skipped_key.status"
  test "$(wc -l <"$TMP_DIR/launches")" -eq "$((launch_count + 1))"
)
# Duplicate receipt must not re-arm the consumed marker.
request w-00000000000000000000000000000091 91
ingest_review_requests me
test ! -f "$blocked_key.requested"
for number in $(seq 100 164); do
  id="$(printf 'w-%032x' "$number")"
  request "$id" "$number"
done
ingest_review_requests me
test "$(find "$STATE_DIR/requests" -name '*.json' | wc -l | tr -d ' ')" = 1
ingest_review_requests me
test "$(find "$STATE_DIR/requests" -name '*.json' | wc -l | tr -d ' ')" = 0
# Protocol v2: mode post|dry-run. An own PR is accepted only as a dry-run.
request2() {
  jq -cn --arg id "$1" --argjson number "$2" --arg sha "$FAKE_HEAD" --arg mode "$3" '{version:2,id:$id,repo:"o/r",number:$number,sha:$sha,login:"me",mode:$mode}' >"$STATE_DIR/requests/$1.json"
}
receipt_of() { cat "$STATE_DIR/requests/$1.receipt"; }
v2_post=w-00000000000000000000000000000020
request2 "$v2_post" 20 post
ingest_review_requests me
test "$(receipt_of "$v2_post")" = $'accepted\t'"$FAKE_HEAD"
test -f "$(run_key o/r 20).registered"
test ! -e "$(run_key o/r 20).dryrun"
export FAKE_AUTHOR=me
own_post=w-00000000000000000000000000000022
request2 "$own_post" 22 post
ingest_review_requests me
test "$(receipt_of "$own_post")" = $'rejected\town'
test ! -e "$(run_key o/r 22).dryrun" && test ! -e "$(run_key o/r 22).registered" && test ! -e "$(run_key o/r 22).requested"
if awk -F'\t' '$2==22 {f=1} END {exit !f}' "$WATCHED"; then echo 'own post request was watched' >&2; exit 1; fi
own_v1=w-00000000000000000000000000000023
request "$own_v1" 23
ingest_review_requests me
test "$(receipt_of "$own_v1")" = $'rejected\town'
dry=w-00000000000000000000000000000021
request2 "$dry" 21 dry-run
ingest_review_requests me
test "$(receipt_of "$dry")" = $'accepted\t'"$FAKE_HEAD"
dry_key="$(run_key o/r 21)"
test "$(cat "$dry_key.dryrun")" = "$FAKE_HEAD"$'\tme'
test "$(cat "$dry_key.requested")" = "$FAKE_HEAD"$'\tme'
test ! -e "$dry_key.registered"
awk -F'\t' '$2==21 {f=1} END {exit !f}' "$WATCHED"
export FAKE_AUTHOR=other
other_dry=w-00000000000000000000000000000024
request2 "$other_dry" 24 dry-run
ingest_review_requests me
test "$(receipt_of "$other_dry")" = $'rejected\tmalformed'
test ! -e "$(run_key o/r 24).dryrun"
for bad in bogus-mode no-mode v1-with-mode stream; do
  id=w-00000000000000000000000000000025
  case "$bad" in
    bogus-mode) request2 "$id" 25 later ;;
    no-mode) request2 "$id" 25 post; jq 'del(.mode)' "$STATE_DIR/requests/$id.json" >"$TMP_DIR/change"; mv "$TMP_DIR/change" "$STATE_DIR/requests/$id.json" ;;
    v1-with-mode) request2 "$id" 25 post; jq '.version=1' "$STATE_DIR/requests/$id.json" >"$TMP_DIR/change"; mv "$TMP_DIR/change" "$STATE_DIR/requests/$id.json" ;;
    stream) request2 "$id" 25 post; { jq -cn --arg id "$id" '{version:2,id:$id,mode:"bogus"}'; cat "$STATE_DIR/requests/$id.json"; } >"$TMP_DIR/change"; mv "$TMP_DIR/change" "$STATE_DIR/requests/$id.json" ;;
  esac
  ingest_review_requests me
  test "$(receipt_of "$id")" = $'rejected\tmalformed'
  rm "$STATE_DIR/requests/$id.receipt"
done
# Only the requested head of a dry-run PR is considered, with no settling delay.
dry_launches="$(wc -l <"$TMP_DIR/launches")"
consider me o/r 21 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb url
test "$(wc -l <"$TMP_DIR/launches")" -eq "$dry_launches"
test ! -e "$dry_key.status"
consider me o/r 21 "$FAKE_HEAD" url
test "$(tail -1 "$TMP_DIR/launches")" = $'dryrun\t-'
test "$(wc -l <"$TMP_DIR/launches")" -eq "$((dry_launches + 1))"
# The run: findings file, no post, no approval, and no gh write at all.
cat >"$TMP_DIR/council" <<'COUNCIL'
#!/bin/bash
printf '%s\n' "$*" >>"$COUNCIL_ARGS"
sha="${FAKE_HEAD}"
echo '=== phase B: /validator'
case "$FAKE_COUNCIL" in
  findings|nopayload|stale|trailing)
    echo 'WOULD SUBMIT'
    if [ "$FAKE_COUNCIL" != nopayload ]; then
      echo 'gh api repos/o/r/pulls/21/reviews'
      jq -n --arg sha "$sha" '{commit_id:$sha,event:"COMMENT",body:"summary",comments:[{path:"a.rs",line:3,side:"RIGHT",body:"bug <!-- finding:1 -->"}]}'
    fi
    [ "$FAKE_COUNCIL" = stale ] && jq -n '{commit_id:"0000000000000000000000000000000000000000",event:"COMMENT",body:"stale",comments:[]}'
    [ "$FAKE_COUNCIL" = trailing ] && jq -n '{path:"b.rs",line:1,side:"RIGHT",body:"loose"}'
    count=1 ;;
  typed)
    echo 'WOULD SUBMIT'
    jq -n --arg sha "$sha" '{commit_id:$sha,event:"COMMENT",body:42,comments:[{path:17,line:3,body:23}]}'
    count=1 ;;
  wrapped)
    echo 'WOULD SUBMIT'
    printf '[\n  {"commit_id": "%s", "body": "inner", "comments": []}\n]\n' "$sha"
    count=1 ;;
  unicode)
    echo 'WOULD SUBMIT'
    printf '{"commit_id": "%s", "body": "caf\\u00e9", "comments": [{"path": "caf\\u00e9.rs", "line": 1, "body": "x"}]}\n' "$sha"
    count=1 ;;
  broken)
    echo 'WOULD SUBMIT'
    printf '{\n  "commit_id": "%s",\n  "comments": [\n    {"path": "a.rs", "line": 3, "body": "nested"}\n  ],\n' "$sha"
    count=1 ;;
  *) echo 'WOULD SUBMIT: nothing'; count=0 ;;
esac
printf '<!-- claudine:v1 {"kind":"run","run":"r1","sha":"%s","findings":%s,"floor":"should-fix","suppressed":0,"security":"clean","lenses":["done"]} -->\n' "$sha" "$count"
echo '=== done (validator exit 0)'
COUNCIL
chmod +x "$TMP_DIR/council"
export PR_REVIEW_WATCH_COUNCIL="$TMP_DIR/council" COUNCIL_ARGS="$TMP_DIR/council.args" FAKE_HEAD
runner="$ROOT_DIR/claude/scopes/work/scripts/pr-review-watch/review-run.sh"
findings_file="$REPORTS/o_r-21-${FAKE_HEAD:0:8}-findings.json"
dryrun_run() {
  FAKE_COUNCIL="$1" "$runner" dryrun o/r 21 "$FAKE_HEAD" - url "$REPORTS/o_r-21-${FAKE_HEAD:0:8}-dryrun.md" "$dry_key" >"$TMP_DIR/run.out" 2>&1
}
: >"$COUNCIL_ARGS"
dryrun_run nopayload && { echo 'dry-run with findings but no payload passed' >&2; exit 1; }
test ! -e "$findings_file"
dryrun_run findings || { cat "$TMP_DIR/run.out" >&2; exit 1; }
test "$(jq -r .sha "$findings_file")" = "$FAKE_HEAD"
test "$(jq -r .findings "$findings_file")" = 1
test "$(jq -r '.comments[0].path' "$findings_file")" = a.rs
test "$(jq -r .body "$findings_file")" = summary
test "$(perl -e 'printf "%o",(stat shift)[2]&0777' "$findings_file")" = 600
# A payload for another head is never taken as this head's findings.
dryrun_run stale || { cat "$TMP_DIR/run.out" >&2; exit 1; }
test "$(jq -r .body "$findings_file")" = summary
test "$(jq -r '.comments[0].path' "$findings_file")" = a.rs
# A loose object after the payload does not replace it; a broken payload is no payload.
dryrun_run trailing || { cat "$TMP_DIR/run.out" >&2; exit 1; }
test "$(jq -r .body "$findings_file")" = summary
test "$(jq -c '[.comments[].path]' "$findings_file")" = '["a.rs"]'
cp "$findings_file" "$TMP_DIR/findings.kept"
dryrun_run broken && { echo 'broken dry-run payload passed' >&2; exit 1; }
cmp "$findings_file" "$TMP_DIR/findings.kept"
# Text fields must be JSON strings, and a value nested in an array is never the payload.
for bad in typed wrapped; do
  dryrun_run "$bad" && { echo "$bad dry-run payload passed" >&2; exit 1; }
  cmp "$findings_file" "$TMP_DIR/findings.kept"
done
# Escaped Unicode survives the round trip.
dryrun_run unicode || { cat "$TMP_DIR/run.out" >&2; exit 1; }
test "$(jq -r .body "$findings_file")" = 'café'
test "$(jq -r '.comments[0].path' "$findings_file")" = 'café.rs'
dryrun_run clean || { cat "$TMP_DIR/run.out" >&2; exit 1; }
test "$(jq -c '[.findings,.comments]' "$findings_file")" = '[0,[]]'
if grep -q -- '--post' "$COUNCIL_ARGS"; then echo 'dry-run council got --post' >&2; exit 1; fi
test "$(wc -l <"$COUNCIL_ARGS" | tr -d ' ')" = 9
test ! -e "$dry_key.registered" && test ! -e "$dry_key.council-done" && test ! -e "$dry_key.approval-pending"
# Assumption A5: nothing is written through gh, so nothing targets the PR.
test ! -s "$GH_WRITES" || { echo 'gh write during dry-run:' >&2; cat "$GH_WRITES" >&2; exit 1; }
if grep -Eq 'pulls/21|pr (review|comment) 21' "$GH_WRITES"; then echo 'gh write targets the PR' >&2; exit 1; fi
# A dry-run of this account is not held by another account's registration or pending approval.
printf '%s\tother\n' "$FAKE_HEAD" >"$dry_key.registered"
printf '%s\tme\n' "$FAKE_HEAD" >"$dry_key.dryrun"
cp "$dry_key.dryrun" "$dry_key.requested"
: >"$dry_key.approval-pending"
rm -f "$dry_key.status"
held_launches="$(wc -l <"$TMP_DIR/launches")"
consider me o/r 21 "$FAKE_HEAD" url
test "$(wc -l <"$TMP_DIR/launches")" -eq "$((held_launches + 1))"
test "$(tail -1 "$TMP_DIR/launches")" = $'dryrun\t-'
rm -f "$dry_key.registered" "$dry_key.approval-pending"
# A posting request from another account retires the dry-run state of the same head.
printf '%s\tdryrun\t0\t1\n' "$FAKE_HEAD" >"$dry_key.status"
post_after=w-00000000000000000000000000000026
jq -cn --arg id "$post_after" --arg sha "$FAKE_HEAD" '{version:2,id:$id,repo:"o/r",number:21,sha:$sha,login:"reviewer",mode:"post"}' >"$STATE_DIR/requests/$post_after.json"
ingest_review_requests reviewer
test "$(receipt_of "$post_after")" = $'accepted\t'"$FAKE_HEAD"
test ! -e "$dry_key.dryrun"
post_launches="$(wc -l <"$TMP_DIR/launches")"
consider reviewer o/r 21 "$FAKE_HEAD" url
test "$(wc -l <"$TMP_DIR/launches")" -eq "$((post_launches + 1))"
test "$(tail -1 "$TMP_DIR/launches")" = $'council\t-'
# Private capabilities must not traverse a pre-existing inbox or receipt symlink.
(
  STATE_DIR="$TMP_DIR/linked-state"
  mkdir -p "$STATE_DIR" "$TMP_DIR/linked-inbox"
  ln -s "$TMP_DIR/linked-inbox" "$STATE_DIR/requests"
  if write_review_request_ready me; then echo 'symlink inbox accepted' >&2; exit 1; fi
  test ! -e "$TMP_DIR/linked-inbox/ready"
  request w-00000000000000000000000000000700 700
  ingest_review_requests me
  test -e "$STATE_DIR/requests/w-00000000000000000000000000000700.json"
  test ! -e "$STATE_DIR/requests/w-00000000000000000000000000000700.receipt"
)
printf 'unchanged\n' >"$TMP_DIR/receipt-target"
ln -s "$TMP_DIR/receipt-target" "$STATE_DIR/requests/symlink.receipt"
if review_request_receipt "$STATE_DIR/requests/symlink.receipt" accepted; then echo 'symlink receipt accepted' >&2; exit 1; fi
test "$(cat "$TMP_DIR/receipt-target")" = unchanged
test -L "$STATE_DIR/requests/symlink.receipt"
echo 'all request intake checks passed'
