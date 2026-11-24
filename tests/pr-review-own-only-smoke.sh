#!/usr/bin/env bash
# Own-only mode: the `own-only` file in the watcher state folder. Every entry
# point (discovery, registrations, requests, process_watched, launchers, purge,
# install) must keep another author's PR out, and never post on an own PR.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_ROOT="${OWN_ONLY_SCRIPTS_ROOT:-$ROOT_DIR/claude/scopes/work/scripts}"
SCRIPTS="$SCRIPTS_ROOT/pr-review-watch"
BASE_COMMIT=aa197bea
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-review-own-only.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home" PR_REVIEW_WATCH_STATE_DIR="$TMP_DIR/state"
export FAKE="$TMP_DIR/fake" GH_CALLS="$TMP_DIR/gh.calls" GH_WRITES="$TMP_DIR/gh.writes" COUNCIL_CALLS="$TMP_DIR/council.calls"
export PR_REVIEW_WATCH_LOG="$TMP_DIR/watch.log" PR_REVIEW_WATCH_COUNCIL="$TMP_DIR/council" PR_COUNCIL_CLAUDE="$HOME/.local/bin/claude"
export PR_REVIEW_WATCH_TIMEOUT=60 PR_REVIEW_WATCH_CI_WAIT=0
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME/.local/bin" "$HOME/.claude" "$FAKE"
ln -s "$SCRIPTS_ROOT" "$HOME/.claude/scripts"
export PATH="$HOME/.local/bin:$PATH"
HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
export HEAD

cat >"$HOME/.local/bin/gh" <<'GH'
#!/bin/bash
printf '%s\n' "$*" >>"$GH_CALLS"
for arg in "$@"; do case "$arg" in -f|-F|--input|-X|--method|--field|--raw-field) printf '%s\n' "$*" >>"$GH_WRITES"; break ;; esac; done
case "$1 $2" in 'pr review'|'pr comment'|'pr edit'|'pr merge'|'pr close'|'pr ready') printf '%s\n' "$*" >>"$GH_WRITES" ;; esac
jqf='' prev='' repo=''
for arg in "$@"; do
  [ "$prev" = --jq ] && jqf="$arg"
  [ "$prev" = --repo ] && repo="$arg"
  prev="$arg"
done
emit() { if [ -n "$jqf" ]; then jq -r "$jqf"; else cat; fi; }
case "$1 $2" in
  'api user') echo '{"login":"owner"}' | emit ;;
  'api repos/'*)
    repo_id=1; name="${2#repos/}"
    [ ! -f "$FAKE/repoid.${name//\//_}" ] || repo_id="$(cat "$FAKE/repoid.${name//\//_}")"
    [ "$repo_id" != - ] || exit 1
    echo "{\"id\":$repo_id}" | emit ;;
  'pr view')
    author=someone
    [ ! -f "$FAKE/author.${repo//\//_}_$3" ] || author="$(cat "$FAKE/author.${repo//\//_}_$3")"
    [ "$author" != - ] || exit 1
    requested='[{"login":"owner"}]'; [ "$author" != owner ] || requested='[]'
    jq -cn --arg head "$HEAD" --arg author "$author" --argjson requested "$requested" '($author | if . == "~" then null else {login: .} end) as $who | {
      state: "OPEN", isDraft: false, headRefOid: $head, url: "https://example.test/pr", baseRefName: "main",
      reviewRequests: $requested, latestReviews: [], author: $who,
      changedFiles: 1, additions: 1, deletions: 0, files: [{path: "a.ts", additions: 1, deletions: 0}]}' | emit ;;
  'search prs') if [ -f "$FAKE/search" ]; then echo '[{"repository":{"nameWithOwner":"acme/widgets"},"number":9}]' | emit; else echo '[]' | emit; fi ;;
  'api --paginate') echo '[]' | emit ;;
  *) exit 1 ;;
esac
GH
cat >"$HOME/.local/bin/claude" <<'CLAUDE'
#!/bin/bash
echo '--permission-prompts'
CLAUDE
cat >"$TMP_DIR/council" <<'COUNCIL'
#!/bin/bash
printf 'council %s\n' "$*" >>"$COUNCIL_CALLS"
printf '=== phase B: \n<!-- claudine:v1 {"kind":"run","run":"r","sha":"%s","findings":0,"floor":"should-fix","suppressed":0,"security":"clean","lenses":["done"]} -->\n' "$HEAD"
COUNCIL
cat >"$HOME/.local/bin/launchctl" <<'LAUNCHCTL'
#!/bin/bash
printf '%s\n' "$*" >>"$LAUNCHCTL_CALLS"
if [ "$1" = bootstrap ]; then ls "$PR_REVIEW_WATCH_STATE_DIR/runs" >"$LAUNCHCTL_RUNS" 2>/dev/null || true; fi
LAUNCHCTL
chmod +x "$HOME/.local/bin/gh" "$HOME/.local/bin/claude" "$HOME/.local/bin/launchctl" "$TMP_DIR/council"
export LAUNCHCTL_CALLS="$TMP_DIR/launchctl.calls" LAUNCHCTL_RUNS="$TMP_DIR/launchctl.runs"

. "$SCRIPTS/watch.sh" || true
mkdir -p "$STATE_DIR"
log() { printf '%s\n' "$*" >>"$TMP_DIR/log"; }
notify() { :; }

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok %s\n' "$1"; }

reset() {
  rm -rf "$STATE_DIR" "$FAKE" "$TMP_DIR/log" "$TMP_DIR/base" "$TMP_DIR/launches"
  mkdir -p "$STATE_DIR" "$RUNS" "$REPORTS" "$STATE_DIR/diagnostics" "$FAKE"
  : >"$GH_CALLS"; : >"$GH_WRITES"; : >"$COUNCIL_CALLS"; : >"$TMP_DIR/log"; : >"$WATCHED"
  rm -f "$LAUNCHCTL_CALLS" "$LAUNCHCTL_RUNS"
  chmod 700 "$STATE_DIR" "$RUNS" "$REPORTS"
}
author() { printf '%s\n' "$3" >"$FAKE/author.${1//\//_}_$2"; }
watch() { printf '%s\t%s\n' "$1" "$2" >>"$WATCHED"; }
key_of() { run_key "$1" "$2"; }
first_line() { head -1 "$1" 2>/dev/null || true; }
no_writes() { [ ! -s "$GH_WRITES" ] || fail "$1: gh write: $(cat "$GH_WRITES")"; }
no_council() { [ ! -s "$COUNCIL_CALLS" ] || fail "$1: council started: $(cat "$COUNCIL_CALLS")"; }
own_only_on() { : >"$STATE_DIR/own-only"; }
gone() { local f; for f in "$@"; do [ ! -e "$f" ] && [ ! -L "$f" ] || fail "$f should be gone"; done; }
present() { local f; for f in "$@"; do [ -e "$f" ] || fail "$f should be kept"; done; }
request() {
  local id="w-$1" repo="$2" number="$3" mode="$4"
  mkdir -p "$STATE_DIR/requests"
  if [ "$mode" = version-1 ]; then
    jq -cn --arg id "$id" --arg repo "$repo" --argjson n "$number" --arg sha "$HEAD" '{version:1,id:$id,repo:$repo,number:$n,sha:$sha,login:"owner"}' >"$STATE_DIR/requests/$id.json"
  else
    jq -cn --arg id "$id" --arg repo "$repo" --argjson n "$number" --arg sha "$HEAD" --arg mode "$mode" '{version:2,id:$id,repo:$repo,number:$n,sha:$sha,login:"owner",mode:$mode}' >"$STATE_DIR/requests/$id.json"
  fi
}
receipt() { first_line "$STATE_DIR/requests/w-$1.receipt" | tr '\t' ' '; }
rid() { printf '%032d' "$1"; }
reserve() {
  printf '%s\n' "$3" >"$1.token"
  printf '%s\t%s\trunning\t1\n' "$HEAD" "$2" >"$1.status"
}
launcher() {
  write_launcher "$1" "$TMP_DIR/diagnostic.log" "$SCRIPTS/launch-run.sh" "$2" "$3" "$4" "$HEAD" 1 "$SCRIPTS/review-run.sh" "$4" "$5" "$6" "$HEAD" - https://example.test/pr "$REPORTS/${5//\//_}-$6-aaaaaaaa-$4.md" "$2"
}
tick() { /bin/bash "$SCRIPTS/watch.sh" || true; }
run_launcher() { (cd "$TMP_DIR" && /bin/bash "$1" >/dev/null 2>&1) || true; }
SETTLE_SECONDS=0
launch() { printf '%s\n' "$*" >>"$TMP_DIR/launches"; }
running_count() { echo 0; }
launched_today() { echo 0; }
run_alive() { return 1; }

reset; own_only_on
a="$(key_of acme/widgets 1)"; b="$(key_of acme/widgets 2)"
author acme/widgets 1 owner; author acme/widgets 2 owner
watch acme/widgets 1; watch acme/widgets 2
printf '%s\n' "$HEAD" >"$a.approval-pending"; printf 'body' >"$a.approval-body"; printf '%s\tdryrun\t0\t1\n' "$HEAD" >"$a.status"
printf '%s\towner\n' "$HEAD" >"$b.registered"; printf '%s\n' "$HEAD" >"$b.council-done"
cp "$a.status" "$TMP_DIR/status.before"
purge_foreign owner
gone "$a.approval-pending" "$a.approval-body" "$b.registered" "$b.council-done"
cmp "$a.status" "$TMP_DIR/status.before" || fail 'a dryrun status of an own PR must stay'
[ ! -e "$b.status" ] || fail 'a key without status gets none'
request "$(rid 1)" acme/widgets 1 dry-run; request "$(rid 2)" acme/widgets 2 dry-run
ingest_review_requests owner
[ "$(receipt "$(rid 1)")" = "accepted $HEAD" ] || fail "own key with approval-pending and dryrun status: $(receipt "$(rid 1)")"
[ "$(receipt "$(rid 2)")" = "accepted $HEAD" ] || fail "own key with registered and council-done and no status: $(receipt "$(rid 2)")"
pass 'purge: own keys lose their posting markers, dry-run requests are accepted'

reset; own_only_on
c="$(key_of acme/widgets 3)"; author acme/widgets 3 owner; watch acme/widgets 3
printf '%s\towner\n' "$HEAD" >"$c.registered"; printf '%s\n' "$HEAD" >"$c.council-done"
reserve "$c" verify tok3; : >"$c.claimed"; : >"$c.launch"; : >"$c.launch.AbC123"
purge_foreign owner
gone "$c.registered" "$c.council-done" "$c.token" "$c.claimed" "$c.launch" "$c.launch.AbC123"
[ "$(first_line "$c.status")" = 'skipped posting-off' ] || fail "status: $(first_line "$c.status")"
request "$(rid 3)" acme/widgets 3 dry-run
ingest_review_requests owner
[ "$(receipt "$(rid 3)")" = "accepted $HEAD" ] || fail "verify-status own PR: $(receipt "$(rid 3)")"
printf '%s\n' tokdry >"$c.token"; printf '%s\tdryrun\trunning\t1\n' "$HEAD" >"$c.status"
(cd "$TMP_DIR" && /bin/bash "$SCRIPTS/launch-run.sh" "$c" tokdry dryrun "$HEAD" 1 "$SCRIPTS/review-run.sh" dryrun acme/widgets 3 "$HEAD" - https://example.test/pr "$REPORTS/acme_widgets-3-aaaaaaaa-dryrun.md" "$c" >/dev/null 2>&1) || true
[ -f "$REPORTS/acme_widgets-3-aaaaaaaa-findings.json" ] || fail 'the dry-run produced no findings file'
[ "$(jq -r .findings "$REPORTS/acme_widgets-3-aaaaaaaa-findings.json")" = 0 ] || fail 'findings count'
grep -q '^council 3 acme/widgets' "$COUNCIL_CALLS" && ! grep -q -- '--post' "$COUNCIL_CALLS" || fail "dry-run council call: $(cat "$COUNCIL_CALLS")"
no_writes 'own-PR dry-run'
pass 'purge: verify-status own PR accepted as dry-run, findings produced, no write'

reset; own_only_on
c="$(key_of acme/widgets 3)"; f="$(key_of acme/widgets 4)"
author acme/widgets 3 owner; author acme/widgets 4 someone; watch acme/widgets 3; watch acme/widgets 4
printf '%s\towner\n' "$HEAD" >"$c.registered"; reserve "$c" council tok3; : >"$c.launch.AbC123"
printf '%s\tsomeone\n' "$HEAD" >"$f.registered"; reserve "$f" verify tok4; : >"$f.launch"; : >"$f.claimed"
purge_foreign owner
[ "$(first_line "$c.status")" = 'skipped posting-off' ] || fail "own PR status: $(first_line "$c.status")"
[ "$(first_line "$f.status")" = 'skipped own-only' ] || fail "foreign PR status: $(first_line "$f.status")"
[ "$(wc -l <"$c.status" | tr -d ' ')" = 1 ] && [ "$(wc -l <"$f.status" | tr -d ' ')" = 1 ] || fail 'a skip status is one line'
gone "$f.registered" "$f.token" "$f.claimed" "$f.launch"
[ "$(cat "$WATCHED")" = $'acme/widgets\t3' ] || fail "watched: $(cat "$WATCHED")"
pass 'purge: skipped posting-off for an own PR, skipped own-only for a foreign one, foreign entry dropped'

pr_views() { grep -c '^pr view' "$GH_CALLS" || true; }
reset; own_only_on
f="$(key_of acme/widgets 25)"; o="$(key_of acme/widgets 26)"; u="$(key_of acme/widgets 27)"
author acme/widgets 25 someone; author acme/widgets 26 owner; author acme/widgets 27 -; watch acme/widgets 26
printf '%s\tsomeone\n' "$HEAD" >"$f.registered"; printf '%s\tdryrun\t0\t1\n' "$HEAD" >"$o.status"; printf '%s\tsomeone\n' "$HEAD" >"$u.registered"
rc=0; purge_foreign owner || rc=$?
[ "$rc" = 3 ] || fail "first purge with an unreadable author: exit $rc"
: >"$GH_CALLS"
printf '%s\tsomeone\n' "$HEAD" >"$f.registered"
rc=0; purge_foreign owner || rc=$?
[ "$rc" = 3 ] || fail "second purge with an unreadable author: exit $rc"
[ "$(pr_views)" = 1 ] || fail "second purge: $(pr_views) pr view calls, want 1 (the unreadable author only): $(cat "$GH_CALLS")"
gone "$f.registered"
[ "$(first_line "$f.status")" = 'skipped own-only' ] || fail "known foreign key: $(first_line "$f.status")"
[ "$(first_line "$o.status")" = "$(printf '%s\tdryrun\t0\t1' "$HEAD")" ] || fail "known own dry-run key: $(first_line "$o.status")"
[ "$(cat "$WATCHED")" = $'acme/widgets\t26' ] || fail "watched: $(cat "$WATCHED")"
present "$u.registered"
author acme/widgets 27 someone; : >"$GH_CALLS"
purge_foreign owner
[ "$(pr_views)" = 1 ] || fail "author readable again: $(pr_views) pr view calls, want 1"
gone "$u.registered"
[ "$(first_line "$u.status")" = 'skipped own-only' ] || fail "once readable: $(first_line "$u.status")"
: >"$GH_CALLS"; purge_foreign owner
[ "$(pr_views)" = 0 ] || fail "settled purge: $(pr_views) pr view calls, want 0"
pass 'purge: a known author is not asked again, a failed read is, outcomes unchanged'

# A reused repository name: the cached authors of #25 (foreign) and #26 (own) belong to the
# renamed repository; the new one under the same name has another id.
printf '2\n' >"$FAKE/repoid.acme_widgets"
author acme/widgets 25 owner; author acme/widgets 26 someone; watch acme/widgets 25; : >"$GH_CALLS"
printf '%s\tdryrun\t0\t1\n' "$HEAD" >"$f.status"; printf '%s\n' "$HEAD" >"$f.token"; printf '%s\n' "$HEAD" >"$o.token"
purge_foreign owner
[ "$(first_line "$f.status")" = "$(printf '%s\tdryrun\t0\t1' "$HEAD")" ] || fail "reused name, own PR: $(first_line "$f.status")"
present "$f.token"
[ "$(first_line "$o.status")" = 'skipped own-only' ] || fail "reused name, foreign PR: $(first_line "$o.status")"
gone "$o.token"
[ "$(cat "$WATCHED")" = $'acme/widgets\t25' ] || fail "reused name watch list: $(cat "$WATCHED")"
: >"$GH_CALLS"; purge_foreign owner
[ "$(pr_views)" = 0 ] || fail "reused name settled: $(pr_views) pr view calls, want 0"
printf -- '-\n' >"$FAKE/repoid.acme_widgets"; : >"$GH_CALLS"; purge_foreign owner
[ "$(pr_views)" -ge 1 ] || fail "unreadable repository id: the cache was trusted"
awk -F'\t' '$1 !~ /^[0-9]+#[0-9]+$/ {bad = 1} END {exit bad}' "$PR_REVIEW_WATCH_STATE_DIR/authors.owner" || fail "an author was stored without a repository id: $(cat "$PR_REVIEW_WATCH_STATE_DIR/authors.owner")"
rm -f "$FAKE/repoid.acme_widgets"
pass 'purge: authors are cached by repository id, a reused name is read again'

# A login rename: #25 is cached as the old login's PR, then the owner becomes renamed.
printf '2\n' >"$FAKE/repoid.acme_widgets"; purge_foreign owner
author acme/widgets 25 renamed; : >"$GH_CALLS"
purge_foreign renamed
[ "$(first_line "$f.status")" = "$(printf '%s\tdryrun\t0\t1' "$HEAD")" ] || fail "renamed login, own PR: $(first_line "$f.status")"
present "$f.token"
[ "$(cat "$WATCHED")" = $'acme/widgets\t25' ] || fail "renamed login watch list: $(cat "$WATCHED")"
[ "$(pr_views)" -ge 1 ] || fail "renamed login: the old cache was trusted"
rm -f "$FAKE/repoid.acme_widgets"
pass 'purge: a login rename starts a fresh author cache'

reset; own_only_on
c="$(key_of acme/widgets 3)"; f="$(key_of acme/widgets 4)"
author acme/widgets 3 owner; author acme/widgets 4 someone; watch acme/widgets 3; watch acme/widgets 4
printf '%s\towner\n' "$HEAD" >"$c.registered"; printf '%s\n' "$HEAD" >"$c.council-done"; reserve "$c" verify tok3
reserve "$f" council tok4
tick
[ ! -s "$WATCHED" ] || fail "watched after a tick: $(cat "$WATCHED")"
no_council tick; no_writes tick
pass 'tick: own PR without a dry-run request leaves watched.tsv, foreign entry dropped'

for mode in council verify; do
  reset
  c="$(key_of acme/widgets 5)"; author acme/widgets 5 owner; watch acme/widgets 5
  reserve "$c" "$mode" tok5
  launcher "$c.launch.AbC123" "$c" tok5 "$mode" acme/widgets 5
  own_only_on
  run_launcher "$c.launch.AbC123"
  no_council "$mode launcher"; no_writes "$mode launcher"
  gone "$c.claimed"
  [ "$(first_line "$c.status")" = "$(printf '%s\t%s\trunning\t1' "$HEAD" "$mode")" ] || fail "$mode launcher touched the status"
  purge_foreign owner
  gone "$c.token" "$c.launch.AbC123"
done
pass 'launchers: own PR in council or verify mode exits before any work; purge removes the reservation'

reset; own_only_on; : >"$FAKE/search"; author acme/widgets 9 someone
tick
if grep -q '^search prs' "$GH_CALLS"; then fail 'discovery ran'; fi
pass 'tick: discovery skipped'

reset; own_only_on
author acme/widgets 6 someone; author acme/widgets 7 owner; watch acme/widgets 6; watch acme/widgets 7
process_watched owner
[ ! -e "$TMP_DIR/launches" ] || fail "launched: $(cat "$TMP_DIR/launches")"
if grep -q 'acme/widgets	6' "$WATCHED"; then fail 'foreign entry kept'; fi
for unreadable in - '~'; do
  reset; own_only_on; author acme/widgets 6 "$unreadable"; watch acme/widgets 6
  process_watched owner
  [ "$(cat "$WATCHED")" = $'acme/widgets\t6' ] || fail "unreadable entry ($unreadable) must be kept"
  [ ! -e "$TMP_DIR/launches" ] || fail "unreadable entry ($unreadable) ran"
done
reset; own_only_on
c="$(key_of acme/widgets 7)"; author acme/widgets 7 owner; watch acme/widgets 7
printf '%s\towner\n' "$HEAD" >"$c.registered"
process_watched owner
[ ! -e "$TMP_DIR/launches" ] || fail "own PR in a posting flow launched: $(cat "$TMP_DIR/launches")"
pass 'process_watched: foreign entry dropped, unreadable one kept, neither runs'

reset; own_only_on
author acme/widgets 10 someone; author acme/widgets 11 owner
request "$(rid 10)" acme/widgets 10 version-1
request "$(rid 11)" acme/widgets 10 post
request "$(rid 12)" acme/widgets 10 dry-run
request "$(rid 13)" acme/widgets 11 post
request "$(rid 14)" acme/widgets 11 version-1
request "$(rid 15)" acme/widgets 11 dry-run
ingest_review_requests owner
for n in 10 11 12 13 14; do [ "$(receipt "$(rid "$n")")" = 'rejected own-only' ] || fail "request $n: $(receipt "$(rid "$n")")"; done
[ "$(receipt "$(rid 15)")" = "accepted $HEAD" ] || fail "own dry-run request: $(receipt "$(rid 15)")"
[ "$(cat "$WATCHED")" = $'acme/widgets\t11' ] || fail "watched: $(cat "$WATCHED")"
gone "$(key_of acme/widgets 10).requested" "$(key_of acme/widgets 10).registered"
pass 'requests: only an own-PR dry-run is accepted, the rest is rejected own-only'

reset; author acme/widgets 12 someone
mkdir -p "$STATE_DIR/register"
printf '=== phase B: \n<!-- claudine:v1 {"kind":"run","run":"r","sha":"%s","findings":0,"floor":"should-fix","suppressed":0,"security":"clean","lenses":["done"]} -->\n' "$HEAD" >"$TMP_DIR/council.md"
write_watch_heartbeat owner
out="$(submit_council_registration acme/widgets 12 "$HEAD" owner "$TMP_DIR/council.md" approve)"
[[ "$out" == "=== watcher: submitted"* ]] || fail "registration not submitted: $out"
own_only_on
ingest_council_registrations owner
k="$(key_of acme/widgets 12)"
gone "$k.registered" "$k.council-done" "$k.approval-pending" "$k.approval-body"
[ ! -s "$WATCHED" ] || fail 'registration put the PR on the watch list'
[ -z "$(ls "$STATE_DIR/register")" ] || fail 'registration kept'
grep -q 'registration rejected: acme/widgets#12 own-only' "$TMP_DIR/log" || fail 'refusal not logged'
pass 'registration: foreign approve registration refused, logged, no approval pending'
write_watch_heartbeat owner
out="$(submit_council_registration acme/widgets 12 "$HEAD" owner "$TMP_DIR/council.md" approve)"
[ "$out" = '=== watcher: not queued (the watcher is in own-only mode)' ] || fail "producer under own-only: $out"
[ -z "$(ls "$STATE_DIR/register")" ] || fail 'producer under own-only wrote a registration'
pass 'registration: the producer reports own-only instead of a queued approval'

reset; own_only_on
f="$(key_of acme/widgets 13)"; author acme/widgets 13 someone; watch acme/widgets 13
printf '%s\n' "$HEAD" >"$f.approval-pending"; printf 'body' >"$f.approval-body"; printf '%s\tsomeone\n' "$HEAD" >"$f.registered"; printf '%s\n' "$HEAD" >"$f.council-done"
printf '%s\tcouncil\t0\t1\n' "$HEAD" >"$f.status"
(cd "$TMP_DIR" && /bin/bash "$SCRIPTS/review-run.sh" approve acme/widgets 13 "$HEAD" - https://example.test/pr "$REPORTS/acme_widgets-13-aaaaaaaa-approve.md" "$f" >/dev/null 2>&1) || true
no_writes 'direct approve'
present "$f.approval-pending" "$f.approval-body"
tick
gone "$f.approval-pending" "$f.approval-body" "$f.registered" "$f.council-done"
no_writes 'tick'; no_council tick
[ "$(first_line "$f.status")" = 'skipped own-only' ] || fail "status: $(first_line "$f.status")"
pass 'pending approval of a foreign key: nothing posted, files purged'

for mode in approve council; do
  reset; own_only_on
  f="$(key_of acme/widgets 20)"; author acme/widgets 20 someone; watch acme/widgets 20
  printf '%s\n' "$HEAD" >"$f.approval-pending"; printf 'body' >"$f.approval-body"; printf '%s\n' "$HEAD" >"$f.council-done"
  printf '%s\t%s\trunning\t1\n' "$HEAD" "$mode" >"$f.status"
  (
    # The subshell's pid without BASHPID (macOS bash 3.2): the parent of a child it forks.
    sh -c 'echo $PPID' >"$TMP_DIR/subshell.pid"; me="$(cat "$TMP_DIR/subshell.pid")"
    mkdir -p "$f.execution"; printf '%s\n' "$me" >"$f.execution/pid"; printf 'tok20\n' >"$f.execution/token"
    export PR_REVIEW_WATCH_SUPERVISOR="$me" PR_REVIEW_WATCH_RUN_KEY="$f" PR_REVIEW_WATCH_RUN_TOKEN=tok20
    rc=0; cd "$TMP_DIR" && /bin/bash "$SCRIPTS/review-run.sh" "$mode" acme/widgets 20 "$HEAD" - https://example.test/pr "$REPORTS/acme_widgets-20-aaaaaaaa-$mode.md" "$f" >/dev/null 2>&1 || rc=$?
    printf '%s\n' "$rc" >"$TMP_DIR/supervised.rc"
  ) || true
  [ "$(cat "$TMP_DIR/supervised.rc")" = 1 ] || fail "supervised $mode child: exit $(cat "$TMP_DIR/supervised.rc")"
  no_writes "supervised $mode child"; no_council "supervised $mode child"
done
pass 'a supervised runner child entering after the switch posts nothing (its own guard)'

reset; own_only_on
f="$(key_of acme/widgets 21)"; author acme/widgets 21 -; watch acme/widgets 21
printf '%s\tdryrun\trunning\t2\n' "$HEAD" >"$f.status"
(
  # The subshell's pid without BASHPID (macOS bash 3.2): the parent of a child it forks.
  sh -c 'echo $PPID' >"$TMP_DIR/subshell.pid"; me="$(cat "$TMP_DIR/subshell.pid")"
  mkdir -p "$f.execution"; printf '%s\n' "$me" >"$f.execution/pid"; printf 'tok21\n' >"$f.execution/token"
  export PR_REVIEW_WATCH_SUPERVISOR="$me" PR_REVIEW_WATCH_RUN_KEY="$f" PR_REVIEW_WATCH_RUN_TOKEN=tok21
  rc=0; cd "$TMP_DIR" && /bin/bash "$SCRIPTS/review-run.sh" dryrun acme/widgets 21 "$HEAD" - https://example.test/pr "$REPORTS/acme_widgets-21-aaaaaaaa-dryrun.md" "$f" >/dev/null 2>&1 || rc=$?
  printf '%s\n' "$rc" >"$TMP_DIR/supervised.rc"
) || true
[ "$(cat "$TMP_DIR/supervised.rc")" = 75 ] || fail "unreadable author in the runner: exit $(cat "$TMP_DIR/supervised.rc"), want 75"
[ "$(first_line "$f.paused")" = "$(printf '%s\t2' "$HEAD")" ] || fail 'unreadable author in the runner: not deferred at the same attempt'
no_writes 'runner unreadable author'; no_council 'runner unreadable author'
pass 'a supervised dry-run child with an unreadable author defers at the same attempt'

for name in launch launch.AbC123; do
  reset
  f="$(key_of acme/widgets 14)"; author acme/widgets 14 someone; watch acme/widgets 14
  reserve "$f" council tok14
  launcher "$f.$name" "$f" tok14 council acme/widgets 14
  if grep -q OWN_ONLY "$f.$name"; then fail 'the launcher carries an own-only variable'; fi
  own_only_on
  run_launcher "$f.$name"
  no_council "launcher $name"; no_writes "launcher $name"
  gone "$f.claimed"
  [ "$(first_line "$f.status")" = "$(printf '%s\tcouncil\trunning\t1' "$HEAD")" ] || fail "launcher $name touched the status"
done
pass 'launchers: a foreign reservation delivered after the switch starts nothing, both name forms'

reset; touch "$STATE_DIR/off"
author acme/widgets 6 someone; author acme/widgets 7 owner; watch acme/widgets 6; watch acme/widgets 7
rc=0; /bin/bash "$SCRIPTS/watch.sh" --purge-foreign >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "purge exit $rc"
[ "$(cat "$WATCHED")" = $'acme/widgets\t7' ] || fail "watched: $(cat "$WATCHED")"
no_council purge
[ -f "$STATE_DIR/off" ] || fail 'purge removed off'
pass '--purge-foreign: foreign entry removed, own kept, off respected, nothing started'

reset; own_only_on; touch "$STATE_DIR/off"
f="$(key_of acme/widgets 6)"; author acme/widgets 6 someone; reserve "$f" council tok6; printf '%s\n' "$HEAD" >"$f.approval-pending"
tick
gone "$f.token" "$f.approval-pending"
[ "$(first_line "$f.status")" = 'skipped own-only' ] || fail 'tick under off must purge'
pass 'tick: the purge runs under off'

reset; own_only_on
u="$(key_of acme/widgets 15)"; author acme/widgets 15 -; watch acme/widgets 15
printf '%s\tsomeone\n' "$HEAD" >"$u.registered"; reserve "$u" verify tok15
rc=0; /bin/bash "$SCRIPTS/watch.sh" --purge-foreign >/dev/null 2>&1 || rc=$?
[ "$rc" = 3 ] || fail "unread key exit $rc"
present "$u.registered" "$u.token" "$u.status"
[ "$(first_line "$u.status")" = "$(printf '%s\tverify\trunning\t1' "$HEAD")" ] || fail 'unread key status touched'
reserve "$u" dryrun tok15
launcher "$u.launch.AbC123" "$u" tok15 dryrun acme/widgets 15
run_launcher "$u.launch.AbC123"
no_council unread; no_writes unread
[ "$(first_line "$u.paused")" = "$(printf '%s\t1' "$HEAD")" ] || fail 'unread author: dry-run not deferred at the same attempt'
[ "$(first_line "$u.status")" = "$(printf '%s\tdryrun\t75\t1' "$HEAD")" ] || fail "unread author: status $(first_line "$u.status")"
pass 'unreadable author: key untouched, launcher deferred at the same attempt, purge reports it'

install_fixture() {
  reset
  export TZ=UTC
  mkdir -p "$HOME/Library/LaunchAgents"
  rm -f "$HOME/Library/LaunchAgents/"*.plist
}
install_fixture
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
[ "$rc" != 0 ] || fail 'install --own-only without off must refuse'
[ ! -e "$STATE_DIR/own-only" ] || fail 'install --own-only without off created the file'
[ ! -e "$LAUNCHCTL_CALLS" ] || fail 'install --own-only without off loaded a job'
pass 'install --own-only refuses without the off switch'

install_fixture; touch "$STATE_DIR/off"
f="$(key_of acme/widgets 16)"; author acme/widgets 16 someone; reserve "$f" council tok16; printf '%s\n' "$HEAD" >"$f.approval-pending"
o="$(key_of acme/widgets 17)"; author acme/widgets 17 owner; printf '%s\towner\n' "$HEAD" >"$o.registered"
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "install --own-only exit $rc"
[ -f "$STATE_DIR/off" ] && [ -e "$STATE_DIR/own-only" ] || fail 'off must stay, own-only must exist'
grep -q '^bootstrap' "$LAUNCHCTL_CALLS" || fail 'job not loaded'
grep -A1 '<key>PR_REVIEW_WATCH_STATE_DIR</key>' "$HOME/Library/LaunchAgents/com.aguimard.pr-review-watch.plist" | grep -qF "<string>$STATE_DIR</string>" || fail 'the plist does not carry the state folder own-only was set in'
if grep -qE 'acme_widgets_16\.(token|claimed|launch|approval)' "$LAUNCHCTL_RUNS"; then fail "foreign reservation still present when the job was loaded: $(cat "$LAUNCHCTL_RUNS")"; fi
if grep -qE 'acme_widgets_17\.registered' "$LAUNCHCTL_RUNS"; then fail "own posting marker still present when the job was loaded: $(cat "$LAUNCHCTL_RUNS")"; fi
pass 'install --own-only: purge before the job is loaded, off kept, file created'

install_fixture; touch "$STATE_DIR/off"
l="$(key_of acme/widgets 19)"; author acme/widgets 19 someone; reserve "$l" council tok19
mkdir -p "$TMP_DIR/live"; printf 'sleep 300\n' >"$TMP_DIR/live/review-run.sh"
/bin/bash "$TMP_DIR/live/review-run.sh" "$l" & live=$!
printf '%s\n' "$live" >"$l.pid"
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "install --own-only with a live run exit $rc"
sleep 1
if kill -0 "$live" 2>/dev/null; then kill "$live"; fail 'install --own-only left a live foreign review running'; fi
pass 'install --own-only stops a review already running before the purge'

install_fixture; touch "$STATE_DIR/off"
l="$(key_of acme/widgets 22)"; author acme/widgets 22 someone; reserve "$l" council tok22
mkdir -p "$TMP_DIR/stubborn"; printf "trap '' TERM\nsleep 300\n" >"$TMP_DIR/stubborn/review-run.sh"
/bin/bash "$TMP_DIR/stubborn/review-run.sh" "$l" & live=$!
printf '%s\n' "$live" >"$l.pid"
sleep 1
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "install --own-only with a run ignoring TERM exit $rc"
if kill -0 "$live" 2>/dev/null; then kill -KILL "$live"; fail 'install --own-only left a run that ignores TERM alive'; fi
pass 'install --own-only kills a review that ignores TERM before the purge'

install_fixture; touch "$STATE_DIR/off"
l="$(key_of acme/widgets 23)"; author acme/widgets 23 someone; reserve "$l" council tok23
mkdir -p "$TMP_DIR/worker"
printf '( trap "" TERM; exec sleep 300 ) &\necho $! >"%s"\nwait\n' "$TMP_DIR/worker/child" >"$TMP_DIR/worker/review-run.sh"
/bin/bash "$TMP_DIR/worker/review-run.sh" "$l" & live=$!
printf '%s\n' "$live" >"$l.pid"
sleep 1; child="$(cat "$TMP_DIR/worker/child")"
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "install --own-only with a worker ignoring TERM exit $rc"
sleep 1
if ps -p "$child" -o stat= 2>/dev/null | grep -qv Z; then kill -KILL "$child"; fail 'install --own-only left a descendant that ignores TERM alive'; fi
pass 'install --own-only kills a descendant that ignores TERM after its runner exits'

install_fixture; touch "$STATE_DIR/off"
l="$(key_of acme/widgets 24)"; author acme/widgets 24 someone; reserve "$l" council tok24
mkdir -p "$TMP_DIR/late"
printf 'trap '"'"'( trap "" TERM; exec sleep 300 ) & echo $! >"%s"; exit 0'"'"' TERM\nwhile :; do sleep 1; done\n' "$TMP_DIR/late/child" >"$TMP_DIR/late/review-run.sh"
printf 'trap '"'"'kill -TERM $c; wait $c; exit 143'"'"' TERM\n/bin/bash "%s" "$1" & c=$!\necho $c >"%s"\nwait\n' "$TMP_DIR/late/review-run.sh" "$TMP_DIR/late/runner" >"$TMP_DIR/late/launch-run.sh"
# As in production: the supervisor leads the group, the runner is its child and not a leader.
perl -e 'setpgrp(0, 0); exec @ARGV' /bin/bash "$TMP_DIR/late/launch-run.sh" "$l" & supervisor=$!
sleep 1
printf '%s\n' "$(cat "$TMP_DIR/late/runner")" >"$l.pid"
mkdir -p "$l.execution"; printf '%s\n' "$supervisor" >"$l.execution/pid"
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
child="$(cat "$TMP_DIR/late/child" 2>/dev/null || true)"; [ -n "$child" ] || fail 'the TERM handler started no child'
sleep 1
# Either stop proved the child the run's and killed it, or it refused to report success.
if ps -p "$child" -o stat= 2>/dev/null | grep -qv Z; then
  [ "$rc" != 0 ] || { kill -KILL "$child"; fail 'install --own-only succeeded with a child started by the TERM handler alive'; }
  [ ! -e "$LAUNCHCTL_CALLS" ] || { kill -KILL "$child"; fail 'job loaded while a stopped run left a process'; }
  # A retry, from another time zone, still refuses while that process lives, then succeeds once it is gone.
  rc=0; TZ=Pacific/Kiritimati /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
  [ "$rc" != 0 ] && [ ! -e "$LAUNCHCTL_CALLS" ] || { kill -KILL "$child"; fail 'a retried install forgot the survivor of the first stop'; }
  kill -KILL "$child"; sleep 1
  rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
  [ "$rc" = 0 ] || fail "install --own-only still refused once the survivor was gone (exit $rc)"
  echo 'note: the late child outlived its leader; the retry path ran'
fi
pass 'install --own-only never succeeds while a child the runner starts on TERM lives'

install_fixture; touch "$STATE_DIR/off"
l="$(key_of acme/widgets 27)"; author acme/widgets 27 someone; reserve "$l" council tok27
mkdir -p "$TMP_DIR/gone"
printf '( trap "" TERM; exec sleep 300 ) &\necho $! >"%s"\nexit 0\n' "$TMP_DIR/gone/child" >"$TMP_DIR/gone/body.sh"
printf 'trap "" TERM\n/bin/bash "%s"\nsleep 300\n' "$TMP_DIR/gone/body.sh" >"$TMP_DIR/gone/launch-run.sh"
perl -e 'setpgrp(0, 0); exec @ARGV' /bin/bash "$TMP_DIR/gone/launch-run.sh" "$l" & supervisor=$!
sleep 1
mkdir -p "$l.execution"; printf '%s\n' "$supervisor" >"$l.execution/pid"
stray="$(cat "$TMP_DIR/gone/child")"
# The leader dies on its own: the group it leaves holds a process no recorded pid proves.
( sleep 2; kill -KILL "$supervisor" ) &
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
alive=0; ps -p "$stray" -o stat= 2>/dev/null | grep -qv Z && alive=1
kill -KILL "$stray" 2>/dev/null || true
# Seen in the group while its leader lived, the stray is the run's and is killed by its own pid.
[ "$alive" = 0 ] && [ "$rc" = 0 ] || fail "a stray seen in the run's group survived its leader (rc $rc, alive $alive)"
pass 'stop kills a process seen in the run group after the leader dies'

install_fixture; touch "$STATE_DIR/off"
l="$(key_of acme/widgets 25)"; author acme/widgets 25 someone; reserve "$l" council tok25
sleep 300 & innocent=$!
mkdir -p "$TMP_DIR/stale"; printf 'sleep 300\n' >"$TMP_DIR/stale/launch-run.sh"
/bin/bash "$TMP_DIR/stale/launch-run.sh" "$l" & supervisor=$!
printf '%s\n' "$innocent" >"$l.pid"
mkdir -p "$l.execution"; printf '%s\n' "$supervisor" >"$l.execution/pid"
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "install --own-only with a stale run pid exit $rc"
kill -0 "$innocent" 2>/dev/null || fail 'stop signalled a process that is not a run of this key'
sleep 1
if kill -0 "$supervisor" 2>/dev/null; then kill "$supervisor"; fail 'stop left the supervisor of the key alive'; fi
kill "$innocent"; wait "$innocent" 2>/dev/null || true
pass 'stop signals the run of the key, not a stale pid'

install_fixture; touch "$STATE_DIR/off"
l="$(key_of acme/widgets 26)"; author acme/widgets 26 someone; reserve "$l" council tok26
mkdir -p "$TMP_DIR/early"; printf 'sleep 300\n' >"$TMP_DIR/early/launch-run.sh"
/bin/bash "$TMP_DIR/early/launch-run.sh" "$l" & supervisor=$!
mkdir -p "$l.execution"; printf '%s\n' "$supervisor" >"$l.execution/pid"
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "install --own-only with a supervisor before its pid file exit $rc"
sleep 1
if kill -0 "$supervisor" 2>/dev/null; then kill "$supervisor"; fail 'stop missed a supervisor that has not published its pid file yet'; fi
pass 'stop reaches a supervisor holding its execution folder before the pid file'

install_fixture; touch "$STATE_DIR/off"
u="$(key_of acme/widgets 18)"; author acme/widgets 18 -; reserve "$u" council tok18
rc=0; /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
[ "$rc" != 0 ] || fail 'install --own-only with an unread key must not succeed'
[ ! -e "$LAUNCHCTL_CALLS" ] || fail "job loaded with an unread key: $(cat "$LAUNCHCTL_CALLS")"
[ -e "$STATE_DIR/own-only" ] && [ -f "$STATE_DIR/off" ] || fail 'own-only must exist and off stay'
pass 'install --own-only: an unread key keeps the job unloaded'

install_fixture; touch "$STATE_DIR/off"
rc=0; PR_REVIEW_WATCH_NO_LOAD=1 /bin/bash "$SCRIPTS/install.sh" --own-only >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && [ -e "$STATE_DIR/own-only" ] || fail 'PR_REVIEW_WATCH_NO_LOAD must still create own-only'
[ ! -e "$LAUNCHCTL_CALLS" ] || fail 'NO_LOAD loaded'
pass 'install --own-only under NO_LOAD creates the file'

install_fixture; own_only_on; touch "$STATE_DIR/off"
rc=0; PR_REVIEW_WATCH_NO_LOAD=1 /bin/bash "$SCRIPTS/install.sh" 300 >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && [ -e "$STATE_DIR/own-only" ] && [ -f "$STATE_DIR/off" ] || fail 'install without the flag must leave own-only and off'
pass 'install without the flag leaves an existing own-only file'

reset; : >"$FAKE/search"
author acme/widgets 9 someone; author acme/widgets 6 someone; watch acme/widgets 6
request "$(rid 20)" acme/widgets 6 version-1
ingest_review_requests owner
[ "$(receipt "$(rid 20)")" = "accepted $HEAD" ] || fail "default: foreign v1 request: $(receipt "$(rid 20)")"
process_watched owner
[ -s "$TMP_DIR/launches" ] || fail 'default: a requested foreign PR must be considered'
tick
grep -q '^search prs' "$GH_CALLS" || fail 'default: discovery must run'
reset
author acme/widgets 12 someone; write_watch_heartbeat owner
printf '=== phase B: \n<!-- claudine:v1 {"kind":"run","run":"r","sha":"%s","findings":0,"floor":"should-fix","suppressed":0,"security":"clean","lenses":["done"]} -->\n' "$HEAD" >"$TMP_DIR/council.md"
submit_council_registration acme/widgets 12 "$HEAD" owner "$TMP_DIR/council.md" approve >/dev/null
ingest_council_registrations owner
[ -f "$(key_of acme/widgets 12).approval-pending" ] || fail 'default: foreign approve registration must be ingested'
pass 'default mode without the file is unchanged'

if ! git -C "$ROOT_DIR" cat-file -e "$BASE_COMMIT^{commit}" 2>/dev/null; then
  printf 'skip transition: commit %s not available\n' "$BASE_COMMIT"
else
  extract_base() {
    local meta path rel out="$TMP_DIR/base"
    rm -rf "$out"
    while IFS=$'\t' read -r meta path; do
      rel="${path#claude/scopes/work/scripts/}"
      mkdir -p "$out/$(dirname "$rel")"
      git -C "$ROOT_DIR" show "$BASE_COMMIT:$path" >"$out/$rel"
      case "$meta" in 100755*) chmod +x "$out/$rel" ;; esac
    done < <(git -C "$ROOT_DIR" ls-tree -r "$BASE_COMMIT" -- claude/scopes/work/scripts)
  }
  base_launcher() {
    ( . "$TMP_DIR/base/pr-review-watch/watch.sh" || true
      write_launcher "$1.launch.AbC123" "$TMP_DIR/diagnostic.log" "$TMP_DIR/base/pr-review-watch/launch-run.sh" "$1" "$2" council "$HEAD" 1 \
        "$TMP_DIR/base/pr-review-watch/review-run.sh" council acme/widgets 21 "$HEAD" - https://example.test/pr "$REPORTS/acme_widgets-21-aaaaaaaa-council.md" "$1" )
  }
  reset; extract_base; own_only_on; touch "$STATE_DIR/off"
  f="$(key_of acme/widgets 21)"; author acme/widgets 21 someone; reserve "$f" council tok21
  base_launcher "$f" tok21
  run_launcher "$f.launch.AbC123"
  no_council 'base scripts under off'
  cp -R "$SCRIPTS_ROOT/." "$TMP_DIR/base/"
  rm -f "$STATE_DIR/off" "$f.claimed" "$f.paused"; reserve "$f" council tok21
  run_launcher "$f.launch.AbC123"
  no_council 'replaced scripts'; no_writes 'replaced scripts'; gone "$f.claimed"
  [ "$(first_line "$f.status")" = "$(printf '%s\tcouncil\trunning\t1' "$HEAD")" ] || fail 'replaced scripts touched the status'
  reset; extract_base; own_only_on
  f="$(key_of acme/widgets 21)"; author acme/widgets 21 someone; reserve "$f" council tok21
  base_launcher "$f" tok21
  run_launcher "$f.launch.AbC123"
  grep -q '^council 21 acme/widgets' "$COUNCIL_CALLS" || fail 'control: the base scripts must start the foreign run without off'
  pass 'transition: base scripts pause under off, new scripts refuse, base scripts run without off'
fi
printf 'ok own-only: discovery, registrations, requests, process_watched, launchers, purge, install\n'
