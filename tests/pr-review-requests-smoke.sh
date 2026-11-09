#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-review-requests.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home" PR_REVIEW_WATCH_STATE_DIR="$TMP_DIR/state"
mkdir -p "$HOME/.local/bin"
export FAKE_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa FAKE_AUTHOR=other FAKE_STATE=OPEN FAKE_DRAFT=false
cat >"$HOME/.local/bin/gh" <<'GH'
#!/bin/bash
[ "$1 $2" = 'pr view' ] || exit 1
jq -cn --arg head "$FAKE_HEAD" --arg author "$FAKE_AUTHOR" --arg state "$FAKE_STATE" --argjson draft "$FAKE_DRAFT" '{headRefOid:$head,author:{login:$author},state:$state,isDraft:$draft}'
GH
chmod +x "$HOME/.local/bin/gh"
. "$ROOT_DIR/claude/scopes/work/scripts/pr-review-watch/watch.sh" || true
mkdir -p "$RUNS" "$REPORTS"
: >"$WATCHED"
log() { printf '%s\n' "$*" >>"$TMP_DIR/log"; }
write_review_request_ready Me
test "$(cut -f1-2 "$STATE_DIR/requests/ready")" = $'1\tme'
test "$(perl -e 'printf "%o",(stat shift)[2]&0777' "$STATE_DIR/requests/ready")" = 600
test "$(perl -e 'printf "%o",(stat shift)[2]&0777' "$STATE_DIR/requests")" = 700
stamp="$(cut -f3 "$STATE_DIR/requests/ready")"
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
seen_age() { echo 120; }
diff_scope() { echo 1; }
running_count() { echo 0; }
launched_today() { echo 0; }
launch() { printf '%s\t%s\n' "$5" "$6" >>"$TMP_DIR/launches"; }
consider me o/r 7 "$FAKE_HEAD" url
test ! -e "$TMP_DIR/launches"
fresh=w-00000000000000000000000000000010
request "$fresh" 10
ingest_review_requests me
consider me o/r 10 "$FAKE_HEAD" url
test "$(cat "$TMP_DIR/launches")" = $'council\t-'
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
for number in $(seq 100 164); do
  id="$(printf 'w-%032x' "$number")"
  request "$id" "$number"
done
ingest_review_requests me
test "$(find "$STATE_DIR/requests" -name '*.json' | wc -l | tr -d ' ')" = 1
ingest_review_requests me
test "$(find "$STATE_DIR/requests" -name '*.json' | wc -l | tr -d ' ')" = 0
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
