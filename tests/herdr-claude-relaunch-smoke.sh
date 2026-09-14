#!/usr/bin/env bash
# Hermetic smoke test for etabli.claude-relaunch.
# Covers parse table, dedup, expiry, fire paths, still-limited reschedule
# via a fake herdr CLI shim (no live herdr / launchd).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
LIB="$ROOT_DIR/herdr/plugins/claude-relaunch/scripts/lib.sh"
ON_EVENT="$ROOT_DIR/herdr/plugins/claude-relaunch/scripts/on-event.sh"
CHECK="$ROOT_DIR/herdr/plugins/claude-relaunch/scripts/check.sh"

if [[ ! -f "$LIB" ]]; then
  printf 'missing %s\n' "$LIB" >&2
  exit 1
fi

if ! command -v perl >/dev/null 2>&1; then
  printf 'perl is required for reset-time parsing\n' >&2
  exit 1
fi

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

export FAKE_HERDR_DIR="$TMP/fake"
export HERDR_CLAUDE_RELAUNCH_STATE_DIR="$TMP/state"
export HERDR_PLUGIN_STATE_DIR="$TMP/state"
export HERDR_BIN_PATH="$TMP/bin/herdr"

mkdir -p "$TMP/bin" "$FAKE_HERDR_DIR" "$HERDR_CLAUDE_RELAUNCH_STATE_DIR"

cat >"$HERDR_BIN_PATH" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
DIR="${FAKE_HERDR_DIR:?}"
mkdir -p "$DIR"
printf '%s\n' "$*" >>"$DIR/invocations.log"

case "${1:-} ${2:-}" in
"agent list")
  cat "$DIR/agent-list.json"
  ;;
"agent get")
  pane="${3:-}"
  if [[ -f "$DIR/agents/${pane}.json" ]]; then
    cat "$DIR/agents/${pane}.json"
  else
    exit 1
  fi
  ;;
"agent read")
  pane="${3:-}"
  if [[ -f "$DIR/detection/${pane}.txt" ]]; then
    cat "$DIR/detection/${pane}.txt"
  else
    exit 1
  fi
  ;;
"agent prompt")
  printf '%s\n' "$*" >>"$DIR/prompts.log"
  exit "${PROMPT_EXIT:-0}"
  ;;
"agent wait")
  exit 0
  ;;
"pane read")
  pane="${3:-}"
  if [[ -f "$DIR/panes/${pane}.alive" ]]; then
    printf 'shell\n'
    exit 0
  fi
  exit 1
  ;;
"pane run")
  printf '%s\n' "$*" >>"$DIR/pane-run.log"
  exit 0
  ;;
"pane list")
  if [[ -f "$DIR/herdr.down" ]]; then
    exit 1
  fi
  printf '[]\n'
  ;;
"notification show")
  printf '%s\n' "$*" >>"$DIR/notifications.log"
  exit 0
  ;;
*)
  printf 'fake-herdr: unknown %s\n' "$*" >&2
  exit 1
  ;;
esac
SHIM
chmod +x "$HERDR_BIN_PATH"

# Source after env is set so HERDR_BIN / STATE_* bind to the shim.
# shellcheck source=../herdr/plugins/claude-relaunch/scripts/lib.sh
source "$LIB"

# Hermetic clock + no real sleeps (fire's claude --continue poll loops 6x10s).
FIXED_NOW="$(perl -MTime::Local -e 'print timelocal(0,0,10,26,7,2026)')"
NOW_OVERRIDE=""
now_epoch() { printf '%s\n' "${NOW_OVERRIDE:-$FIXED_NOW}"; }
sleep() { :; }

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'ok  %s\n' "$*"; }

assert_eq() {
  local got="$1" want="$2" msg="$3"
  [[ "$got" == "$want" ]] || fail "$msg: got '$got' want '$want'"
  ok "$msg"
}

assert_empty() {
  local got="$1" msg="$2"
  [[ -z "$got" ]] || fail "$msg: expected empty, got '$got'"
  ok "$msg"
}

entry_count() { read_entries | awk 'NF' | wc -l | tr -d '[:space:]'; }

epoch_at() { # epoch_at <h> <m> <d> <mon0> <y>
  perl -MTime::Local -e 'print timelocal(0,$ARGV[1],$ARGV[0],$ARGV[2],$ARGV[3],$ARGV[4])' "$@"
}

reset_case() {
  NOW_OVERRIDE=""
  unset PROMPT_EXIT
  rm -rf "$FAKE_HERDR_DIR" "$HERDR_CLAUDE_RELAUNCH_STATE_DIR"
  mkdir -p "$FAKE_HERDR_DIR/agents" "$FAKE_HERDR_DIR/detection" "$FAKE_HERDR_DIR/panes" \
    "$HERDR_CLAUDE_RELAUNCH_STATE_DIR"
  printf '%s\n' '{"result":{"agents":[]}}' >"$FAKE_HERDR_DIR/agent-list.json"
  : >"$STATE_FILE"
}

set_claude_agent() { # set_claude_agent <pane> <session> <cwd>
  local pane="$1" session="$2" cwd="$3"
  cat >"$FAKE_HERDR_DIR/agent-list.json" <<EOF
{"result":{"agents":[{"agent":"claude","pane_id":"$pane","cwd":"$cwd","agent_session":{"value":"$session"},"agent_status":"idle"}]}}
EOF
  cat >"$FAKE_HERDR_DIR/agents/${pane}.json" <<EOF
{"agent":"claude","pane_id":"$pane"}
EOF
}

set_detection() { # set_detection <pane> <text>
  printf '%s\n' "$2" >"$FAKE_HERDR_DIR/detection/${1}.txt"
}

mark_pane_alive() { : >"$FAKE_HERDR_DIR/panes/${1}.alive"; }

# --- parse table -------------------------------------------------------------
want_5pm="$(epoch_at 17 0 26 7 2026)"
want_930_next="$(epoch_at 9 30 27 7 2026)"
want_tue_7am="$(epoch_at 7 0 1 8 2026)" # next Tue after Wed 2026-08-26
want_tom_8am="$(epoch_at 8 0 27 7 2026)"

assert_eq "$(parse_until_epoch '5pm' "$FIXED_NOW")" "$want_5pm" "parse 5pm"
assert_eq "$(parse_until_epoch '9:30am' "$FIXED_NOW")" "$want_930_next" "parse 9:30am (rolls next day)"
assert_eq "$(parse_until_epoch 'Tue 7am' "$FIXED_NOW")" "$want_tue_7am" "parse Tue 7am"
assert_eq "$(parse_until_epoch 'Tomorrow 8am' "$FIXED_NOW")" "$want_tom_8am" "parse Tomorrow 8am"
assert_empty "$(parse_until_epoch 'someday maybe' "$FIXED_NOW")" "parse unparseable → empty"

assert_eq "$(extract_reset_text 'usage limit reached until 5pm')" "5pm" "extract until 5pm"
assert_eq "$(extract_reset_text 'weekly limit reached. Resets at Tue 7am')" "Tue 7am" "extract Resets at"
assert_eq "$(extract_reset_text 'hit your usage limit until Tomorrow 8am')" "Tomorrow 8am" "extract Tomorrow"

[[ -n "$(detect_limit_lines 'Claude: usage limit reached until 5pm')" ]] ||
  fail "detect: usage limit reached"
[[ -n "$(detect_limit_lines 'weekly limit reached')" ]] ||
  fail "detect: weekly limit reached"
[[ -z "$(detect_limit_lines 'just chatting about rate limits in theory')" ]] ||
  fail "detect: should ignore non-banner chatter"
ok "detect regex (positive + negative)"

# --- scan: one pending entry, sane due --------------------------------------
reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 $'Claude Code\nYou\'ve hit your usage limit. Until 5pm\n'
scan_all >/dev/null
assert_eq "$(entry_count)" "1" "scan creates exactly one entry"
line="$(read_entries)"
assert_eq "$(entry_field "$line" 2)" "p1" "scan keyed by pane"
due="$(entry_field "$line" 1)"
assert_eq "$due" "$want_5pm" "scan due_epoch is parsed 5pm"
((due > FIXED_NOW)) || fail "due not in the future"
((due - FIXED_NOW <= 13 * 3600)) || fail "due > +13h ($((due - FIXED_NOW))s)"
ok "due_epoch future and ≤ +13h"

# unparseable reset at scan time → +45m re-probe
reset_case
set_claude_agent p2 sess-2 /tmp/other
set_detection p2 'usage limit reached (reset time hidden)'
scan_all >/dev/null
assert_eq "$(entry_count)" "1" "scan unparseable still schedules"
due="$(entry_field "$(read_entries)" 1)"
assert_eq "$due" "$((FIXED_NOW + DEFAULT_RETRY_S))" "scan fallback due = now+45m"

# no-match scan writes nothing
reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 'working on PLAN.md, no limits'
before="$(cat "$STATE_FILE")"
scan_all >/dev/null
assert_eq "$(entry_count)" "0" "no-limit scan writes no entry"
assert_eq "$(cat "$STATE_FILE")" "$before" "no-limit scan does not mutate state"

# --- dedup: re-detection never duplicates -----------------------------------
reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 'usage limit reached until 5pm'
scan_all >/dev/null
scan_all >/dev/null
assert_eq "$(entry_count)" "1" "re-scan same pane does not duplicate"
first_due="$(entry_field "$(read_entries)" 1)"
set_detection p1 'usage limit reached until 9:30am'
scan_all >/dev/null
assert_eq "$(entry_count)" "1" "re-scan with new reset still one entry"
new_due="$(entry_field "$(read_entries)" 1)"
assert_eq "$new_due" "$first_due" "scan preserves deadline; firing evaluates a changed banner"

# --- safe automatic continuation --------------------------------------------
seed_due() {
  reset_case
  set_claude_agent p1 sess-1 /tmp/proj
  set_detection p1 'usage limit reached until 5pm'
  scan_all >/dev/null
  NOW_OVERRIDE=$((want_5pm + 60))
}
assert_no_input() {
  [[ ! -f "$FAKE_HERDR_DIR/prompts.log" && ! -f "$FAKE_HERDR_DIR/pane-run.log" ]] || fail "$1"
  ok "$1"
}
assert_paused() {
  [[ "$(entry_field "$(read_entries)" 7)" == paused:* ]] || fail "$1"
  ok "$1"
}

seed_due
scan_all >/dev/null
assert_eq "$(entry_field "$(read_entries)" 1)" "$want_5pm" "expired unchanged banner preserves original deadline"
fire_due
grep -q 'agent prompt p1' "$FAKE_HERDR_DIR/prompts.log" || fail 'due deadline must prompt original idle session'
assert_paused 'successful submission pauses further automation'
fire_due
scan_all >/dev/null
assert_eq "$(wc -l < "$FAKE_HERDR_DIR/prompts.log" | tr -d ' ')" 1 'no duplicate continuation from retained banner'

seed_due
set_claude_agent p1 different-session /tmp/other
fire_due
assert_no_input 'reused pane cannot receive original session prompt'
assert_paused 'missing identity pauses'

for state in blocked working unknown; do
  seed_due
  sed "s/idle/$state/" "$FAKE_HERDR_DIR/agent-list.json" > "$TMP/list.json"
  mv "$TMP/list.json" "$FAKE_HERDR_DIR/agent-list.json"
  fire_due
  assert_no_input "$state agent never receives automatic input"
  assert_paused "$state is surfaced to the user"
done

seed_due
printf '%s\n' '{"result":{"agents":[]}}' > "$FAKE_HERDR_DIR/agent-list.json"
mark_pane_alive p1
fire_due
assert_no_input 'empty shell never receives claude --continue'
assert_paused 'exited agent requires deliberate resume'

seed_due
set_claude_agent p2 sess-1 /tmp/proj
set_detection p2 'ready'
fire_due
grep -q 'agent prompt p2' "$FAKE_HERDR_DIR/prompts.log" || fail 'same native session should resolve after pane move'
set_detection p2 'usage limit reached until 5pm'
scan_all >/dev/null
assert_eq "$(entry_count)" 1 'pane move does not duplicate native session entry'

seed_due
export PROMPT_EXIT=1
fire_due
assert_paused 'uncertain prompt result is not retried'
fire_due
assert_eq "$(wc -l < "$FAKE_HERDR_DIR/prompts.log" | tr -d ' ')" 1 'timeout cannot duplicate a possibly submitted turn'

seed_due
set_detection p1 'usage limit reached until 7pm'
fire_due
assert_eq "$(entry_field "$(read_entries)" 1)" "$(epoch_at 19 0 26 7 2026)" 'new reset banner changes deadline at due time'
assert_no_input 'new future deadline does not prompt'

seed_due
printf 'invalid json\n' > "$FAKE_HERDR_DIR/agent-list.json"
for i in 1 2 3 4; do
  fire_due
  NOW_OVERRIDE=$((NOW_OVERRIDE + RETRY_UNREACHABLE_S))
done
assert_paused 'unreadable server is capped'
assert_no_input 'failed server queries never cause shell input'
set_claude_agent p1 sess-1 /tmp/proj
scan_all >/dev/null
assert_paused 'scan cannot rearm a capped entry'

seed_due
printf '%s\n' "$((NOW_OVERRIDE - 5))|p1|claude||/tmp/proj|$NOW_OVERRIDE|legacy" > "$STATE_FILE"
fire_due
assert_paused 'legacy entry without native identity fails closed'
assert_no_input 'legacy entry cannot resume latest unrelated conversation'

seed_due
NOW_OVERRIDE=$((FIXED_NOW + ENTRY_MAX_AGE_S + 1))
expire_entries
assert_paused 'expired entry stays paused rather than being recreated by scans'

reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 'usage limit reached until 5pm'
HERDR_PLUGIN_EVENT_JSON='{"event":"pane.agent_status_changed","pane_id":"p1"}' bash "$ON_EVENT"
assert_eq "$(entry_field "$(read_entries)" 4)" sess-1 'event hook captures native session identity'
report="$(bash "$CHECK")"
[[ "$report" == *'pending relaunch'* ]] || fail 'check report missing'
ok 'check action reports state'

reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 'usage limit reached until later'
NOW_OVERRIDE=$FIXED_NOW
scan_all >/dev/null
for i in 1 2 3 4; do
  NOW_OVERRIDE=$((NOW_OVERRIDE + DEFAULT_RETRY_S))
  fire_due
done
assert_paused 'unparseable reset is a bounded re-probe, not permission to send'
assert_no_input 'unresolved reset never submits a continuation'

seed_due
printf '{"result":{}}\n' > "$FAKE_HERDR_DIR/agent-list.json"
if scan_all >/dev/null; then fail 'missing agents array must fail scan'; fi
ok 'malformed server response fails visibly'

printf '%s\n' '/tmp/original-herdr.sock' > "$SOCKET_FILE"
if HERDR_SOCKET_PATH=/tmp/other-herdr.sock bash -c 'source "$1"' _ "$LIB" 2>/dev/null; then
  fail 'conflicting socket binding accepted'
fi
ok 'conflicting session socket rejected'
assert_eq "$(env -u HERDR_SOCKET_PATH bash -c 'source "$1"; printf "%s" "$HERDR_SOCKET_PATH"' _ "$LIB")" /tmp/original-herdr.sock 'background process recovers saved socket'
rm "$SOCKET_FILE"

seed_due
(
  # A filesystem write failure must remain fatal even under fire_due's || guard.
  write_entries() { return 1; }
  fire_due
)
assert_no_input 'failed state persistence prevents prompt submission'

printf 'herdr-claude-relaunch smoke: ok\n'
