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
  exit 0
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
assert_eq "$new_due" "$want_930_next" "re-scan replaces due when reset moves"

# --- expiry: entries older than 12h dropped ---------------------------------
reset_case
state_init
printf '%s\n' "$((FIXED_NOW + 3600))|oldpane|claude|s|/tmp/old|$((FIXED_NOW - ENTRY_MAX_AGE_S - 30))|stale" >>"$STATE_FILE"
printf '%s\n' "$((FIXED_NOW + 3600))|newpane|claude|s|/tmp/new|$((FIXED_NOW - 60))|fresh" >>"$STATE_FILE"
expire_entries
assert_eq "$(entry_count)" "1" "expire drops >12h entries"
assert_eq "$(entry_field "$(read_entries)" 2)" "newpane" "expire keeps fresh entry"

# --- fire: live claude → agent prompt ---------------------------------------
reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 'ready (limit window reset)'
mark_pane_alive p1
printf '%s\n' "$((FIXED_NOW - 5))|p1|claude|sess-1|/tmp/proj|$FIXED_NOW|due" >"$STATE_FILE"
fire_due
assert_eq "$(entry_count)" "0" "prompt fire removes entry"
grep -q 'agent prompt p1' "$FAKE_HERDR_DIR/invocations.log" ||
  fail "expected agent prompt on live claude pane"
ok "fire live claude → agent prompt"

# --- fire: agent gone, pane is a shell → claude --continue -------------------
reset_case
printf '%s\n' '{"result":{"agents":[]}}' >"$FAKE_HERDR_DIR/agent-list.json"
set_detection p1 'zsh%'
mark_pane_alive p1
printf '%s\n' "$((FIXED_NOW - 5))|p1|claude|sess-1|/tmp/proj|$FIXED_NOW|due" >"$STATE_FILE"
fire_due
assert_eq "$(entry_count)" "0" "pane-run fire removes entry"
grep -q 'pane run p1 claude --continue' "$FAKE_HERDR_DIR/pane-run.log" ||
  fail "expected pane run claude --continue"
ok "fire shell pane → claude --continue"

# --- fire: pane gone → drop + notification ----------------------------------
reset_case
printf '%s\n' '{"result":{"agents":[]}}' >"$FAKE_HERDR_DIR/agent-list.json"
printf '%s\n' "$((FIXED_NOW - 5))|gone1|claude|sess-x|/tmp/x|$FIXED_NOW|due" >"$STATE_FILE"
fire_due
assert_eq "$(entry_count)" "0" "gone pane drops entry"
grep -qi 'notification show' "$FAKE_HERDR_DIR/notifications.log" ||
  fail "expected notification when pane is gone"
ok "fire pane gone → drop + notification"

# --- fire: still limited, parseable reset → reschedule ----------------------
reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 'usage limit reached until 5pm'
printf '%s\n' "$((FIXED_NOW - 5))|p1|claude|sess-1|/tmp/proj|$FIXED_NOW|due" >"$STATE_FILE"
fire_due
assert_eq "$(entry_count)" "1" "still-limited parseable keeps one entry"
assert_eq "$(entry_field "$(read_entries)" 1)" "$want_5pm" "still-limited due = parsed 5pm"
assert_eq "$(entry_field "$(read_entries)" 7)" "re-probe" "still-limited note = re-probe"
if [[ -f "$FAKE_HERDR_DIR/prompts.log" ]]; then
  fail "still-limited parseable must not agent-prompt"
fi
ok "fire still-limited → reschedule parsed time"

# --- fire: still limited, unparseable → +45m --------------------------------
reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 'usage limit reached'
printf '%s\n' "$((FIXED_NOW - 5))|p1|claude|sess-1|/tmp/proj|$FIXED_NOW|due" >"$STATE_FILE"
fire_due
assert_eq "$(entry_count)" "1" "still-limited unparseable keeps one entry"
assert_eq "$(entry_field "$(read_entries)" 1)" "$((FIXED_NOW + DEFAULT_RETRY_S))" \
  "still-limited unparseable due = now+45m"
if [[ -f "$FAKE_HERDR_DIR/prompts.log" ]]; then
  fail "still-limited unparseable must not agent-prompt"
fi
ok "fire still-limited → reschedule +45m"

# --- event hook: no write when no limit pattern -----------------------------
reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 'idle, nothing limited'
: >"$STATE_FILE"
HERDR_PLUGIN_EVENT_JSON='{"event":"pane.agent_status_changed","pane_id":"p1"}' \
  bash "$ON_EVENT"
assert_eq "$(entry_count)" "0" "event hook no-match writes no state"

# event hook schedules when the pane is limited
set_detection p1 'usage limit reached until 5pm'
HERDR_PLUGIN_EVENT_JSON='{"event":"pane.agent_status_changed","pane_id":"p1"}' \
  bash "$ON_EVENT"
# on-event sources lib.sh in a child (real now_epoch). Just assert it wrote
# exactly one p1 row — due is wall-clock based in the child.
assert_eq "$(entry_count)" "1" "event hook match upserts one entry"
assert_eq "$(entry_field "$(read_entries)" 2)" "p1" "event hook keyed by pane"

# --- check.sh reports via the shim ------------------------------------------
reset_case
set_claude_agent p1 sess-1 /tmp/proj
set_detection p1 'usage limit reached until 5pm'
report="$(bash "$CHECK")"
printf '%s\n' "$report" | grep -q 'pending relaunch' ||
  fail "check.sh should print a pending-relaunch report"
printf '%s\n' "$report" | grep -q 'p1' ||
  fail "check.sh should mention the limited pane"
ok "check.sh scan report"

printf 'herdr-claude-relaunch smoke: ok\n'
