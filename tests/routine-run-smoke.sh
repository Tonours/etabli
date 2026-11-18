#!/usr/bin/env bash
# Routine run wrapper: `routine.sh run <name> -- <command...>` and the record
# contract v1 (docs/routines.md). Runs under Linux bash and macOS /bin/bash 3.2;
# jq validates JSON when present.
#
# Test -> the mutation it must catch
#   exit_code_passes_through ............. return 0 instead of the command's status
#   reserved_and_native_refused .......... reserve the name in adopt only (native record overwritten)
#   running_is_on_disk ................... write last.json only at the end
#   arguments_env_stdin_streams .......... re-split, drop, read /dev/null, merge or swap streams
#   off_in_folder_and_parent ............. ignore off in one of the two places
#   skips_leave_last_json ................ a skip overwrites last.json / the first run's end record
#   busy_files_stay_bounded .............. trim only when the lock is free; unbounded growth
#   cap_counts_admitted_runs ............. count journal lines; keep yesterday's lines
#   cap_clock_going_back ................. drop the lines of every other day (six runs on day J)
#   killed_run_leaves_nothing_to_clear ... a lock that is a file to remove; unlink at release
#   dead_wrapper_live_command_keeps_lock  the command does not hold descriptor 9
#   twenty_starts_run_once ............... ignore the status of the lock (all run)
#   background_process_does_not_hold_lock  no unlock at the end
#   lock_failure_runs_nothing ............ run without the lock when Perl fails
#   killed_before_identity / _between_identity_and_go
#                                          the subshell execs without looking at the wrapper
#   killed_right_after_go ................ run the command only while the wrapper lives
#   stopped_subshell_holds_lock .......... the subshell execs without looking at the wrapper
#   reused_wrapper_pid_is_not_the_wrapper  check the wrapper's pid alone
#   stale_go_file_removed ................ keep a go file left by a killed run
#   term/hup/int_reaches_command ......... leave running after a signal
#   command_ignoring_term_is_waited_for .. unlock or exit before the command ended
#   term_during_end_record ............... write the end record in place (truncate)
#   summary_is_valid_json ................ write the summary raw
#   journal_rotates ...................... no rotation past 250 lines
#   busy_record_survives_rotation ........ append the busy record to the journal
#   trap_term_exits_3 / _exits_0 ......... return 143; record failed for a command that exits 0
#   off_skips_stay_bounded ............... journal grows without bound (ROUTINE_TEST_OFF_SKIPS, default 1000)
#   summary_cut_inside_character ......... cut inside the character; iconv's status replaces the exit code
#   invalid_names_refused ................ accept a path as a name
#   defaults_and_unimplemented ........... ignore HOME for the default folder
#   no_model_binary ...................... the wrapper calls a model binary (AC-10)
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$ROOT_DIR/claude/scopes/work/scripts/routine/routine.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/routine-run.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home"
mkdir -p "$HOME"
BIN="$TMP_DIR/bin"
mkdir -p "$BIN"
unset ETABLI_ROUTINES_DIR ROUTINE_TEST_PERL ROUTINE_TEST_HOLD ROUTINE_TEST_PS ROUTINE_TEST_FAIL ROUTINE_SUMMARY

cat >"$BIN/mark.sh" <<'EOF'
#!/bin/bash
echo "$$" >>"$1"
exit "${2:-0}"
EOF
cat >"$BIN/wait.sh" <<'EOF'
#!/bin/bash
echo "$$" >>"$1"
while [ ! -e "$2" ]; do /bin/sleep 0.1; done
exit "${3:-0}"
EOF
chmod +x "$BIN"/*.sh

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

FAILED=0
PIDS=""
CASE=""
FOLDER=""
NAME=r
BGPID=""

fail() { printf '    FAIL: %s\n' "$*" >&2; exit 1; }
eq() { [ "$1" = "$2" ] || fail "$3: got '$1', want '$2'"; }
track() { PIDS="$PIDS $1"; }
cleanup_pids() { local p; for p in $PIDS; do kill -KILL "$p" 2>/dev/null; done; }

new_case() {
  CASE="$(mktemp -d "$TMP_DIR/case.XXXXXX")"
  export ETABLI_ROUTINES_DIR="$CASE/routines"
  mkdir -p "$ETABLI_ROUTINES_DIR"
  NAME=${1:-r}
  FOLDER="$ETABLI_ROUTINES_DIR/$NAME"
}

rw() { /bin/bash "$R" run "$@" </dev/null >/dev/null 2>&1; }

bg() {
  /bin/bash "$R" run "$@" </dev/null >/dev/null 2>&1 &
  BGPID=$!
  track "$BGPID"
}

wait_lock_free() {
  local i=0
  while ! /usr/bin/perl -e 'use Fcntl qw(:flock); open(my $h, ">>", $ARGV[0]) or exit 2; flock($h, LOCK_EX|LOCK_NB) or exit 1' "$1/run.lock"; do
    i=$((i + 1)); [ "$i" -le 300 ] || fail "the lock of $1 is still held"
    /bin/sleep 0.1
  done
}

jf() { sed -nE 's/.*"'"$2"'":(("[^"]*")|[^,}]*).*/\1/p' "$1" | head -n 1 | tr -d '"'; }

valid_json() {
  if [ "$HAVE_JQ" = 1 ]; then jq -e . "$1" >/dev/null 2>&1; else grep -q '^{.*}$' "$1"; fi
}

wait_for() {
  local i=0 max=$((${2:-30} * 10))
  while [ ! -e "$1" ]; do
    i=$((i + 1)); [ "$i" -le "$max" ] || fail "timeout waiting for $1"
    /bin/sleep 0.1
  done
}

wait_gone() {
  local i=0 max=$((${2:-30} * 10))
  while kill -0 "$1" 2>/dev/null; do
    i=$((i + 1)); [ "$i" -le "$max" ] || fail "pid $1 still alive"
    /bin/sleep 0.1
  done
}

wait_cmd_pid() {
  local i=0 v
  while :; do
    v=$(jf "$1" cmd_pid 2>/dev/null)
    [ -z "$v" ] || [ "$v" = null ] || break
    i=$((i + 1)); [ "$i" -le 300 ] || fail "no cmd_pid in $1"
    /bin/sleep 0.1
  done
}

kill_hard() { kill -KILL "$1" 2>/dev/null; wait "$1" 2>/dev/null; return 0; }

kill_run() {
  local w c
  w=$(jf "$1" pid); c=$(jf "$1" cmd_pid)
  kill -KILL "$w" 2>/dev/null; kill -KILL "$c" 2>/dev/null
  wait "$w" 2>/dev/null
  wait_gone "$w"; wait_gone "$c"
  wait_lock_free "$(dirname "$1")"
}

snap() {
  (cd "$1" && find . | LC_ALL=C sort | while IFS= read -r f; do
    if [ -f "$f" ]; then cksum "$f"; else echo "$f"; fi
  done)
}

lines() { if [ -f "$1" ]; then wc -l <"$1" | tr -d ' '; else echo 0; fi; }

day() {
  case "$1" in
    0) date +%Y-%m-%d ;;
    *) date -d "$1 day" +%Y-%m-%d 2>/dev/null || date -v"$(printf '%+d' "$1")"d +%Y-%m-%d ;;
  esac
}

subshell_of() {
  local c comm
  for c in $(pgrep -P "$1"); do
    comm=$(ps -o comm= -p "$c" 2>/dev/null)
    case "$comm" in *bash*) echo "$c"; return 0 ;; esac
  done
  return 1
}

seed_lines() {
  local i=0
  : >"$1"
  while [ "$i" -lt "$2" ]; do echo '{"v":1,"kind":"seed"}' >>"$1"; i=$((i + 1)); done
}

bg_hold() {
  ROUTINE_TEST_HOLD="$1:$CASE/hold" bg $NAME -- "$BIN/mark.sh" "$CASE/a"
  wait_for "$CASE/hold.reached"
}

t_exit_code_passes_through() {
  new_case
  rw $NAME -- "$BIN/mark.sh" "$CASE/m" 3; eq $? 3 "exit code"
  eq "$(jf "$FOLDER/last.json" state)" failed state
  eq "$(jf "$FOLDER/last.json" exit)" 3 exit
  eq "$(lines "$FOLDER/runs.jsonl")" 1 "journal lines"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m" 0; eq $? 0 "exit 0"
  eq "$(jf "$FOLDER/last.json" state)" ok state
  eq "$(lines "$FOLDER/runs.jsonl")" 2 "journal lines"
  valid_json "$FOLDER/last.json" || fail "last.json is not JSON"
  [ "$HAVE_JQ" = 0 ] || jq -e '.v == 1 and .name == "r" and (.pid | type) == "number" and .exit == 0' "$FOLDER/last.json" >/dev/null || fail "last.json fields"
}

t_reserved_and_native_refused() {
  new_case fleet-improvement
  mkdir -p "$FOLDER"
  echo '{"v":1,"name":"fleet-improvement","state":"running"}' >"$FOLDER/last.json"
  local before; before=$(snap "$ETABLI_ROUTINES_DIR")
  rw fleet-improvement -- "$BIN/mark.sh" "$CASE/m"; eq $? 2 "reserved name exit"
  [ ! -e "$CASE/m" ] || fail "reserved name ran the command"
  eq "$(snap "$ETABLI_ROUTINES_DIR")" "$before" "tree after reserved name"

  new_case other
  mkdir -p "$FOLDER"
  echo '{"v":1,"name":"other","label":"com.example.other","source":"native"}' >"$FOLDER/routine.json"
  echo '{"v":1,"name":"other","state":"running"}' >"$FOLDER/last.json"
  before=$(snap "$ETABLI_ROUTINES_DIR")
  rw other -- "$BIN/mark.sh" "$CASE/m"; eq $? 2 "native folder exit"
  [ ! -e "$CASE/m" ] || fail "native folder ran the command"
  eq "$(snap "$ETABLI_ROUTINES_DIR")" "$before" "tree after native folder"

  new_case other2
  mkdir -p "$FOLDER"
  echo '{"v":1,"name":"other2","label":"com.tonours.fleet-improvement","source":"adopt"}' >"$FOLDER/routine.json"
  before=$(snap "$ETABLI_ROUTINES_DIR")
  rw other2 -- "$BIN/mark.sh" "$CASE/m"; eq $? 2 "reserved label exit"
  [ ! -e "$CASE/m" ] || fail "reserved label ran the command"
  eq "$(snap "$ETABLI_ROUTINES_DIR")" "$before" "tree after reserved label"

  printf '{\n  "label": "com.example.other2",\n  "source":\n    "native"\n}\n' >"$FOLDER/routine.json"
  before=$(snap "$ETABLI_ROUTINES_DIR")
  rw other2 -- "$BIN/mark.sh" "$CASE/m"; eq $? 2 "multiline native source exit"
  eq "$(snap "$ETABLI_ROUTINES_DIR")" "$before" "tree after multiline native source"

  printf '{"label":\n"com.tonours.fleet-improvement","source":"adopt"}\n' >"$FOLDER/routine.json"
  before=$(snap "$ETABLI_ROUTINES_DIR")
  rw other2 -- "$BIN/mark.sh" "$CASE/m"; eq $? 2 "multiline reserved label exit"
  [ ! -e "$CASE/m" ] || fail "multiline manifest ran the command"
  eq "$(snap "$ETABLI_ROUTINES_DIR")" "$before" "tree after multiline reserved label"
}

t_admission_write_failure_runs_nothing() {
  new_case
  mkdir -p "$FOLDER"
  echo 1 >"$FOLDER/cap"
  echo '{"state":"ok"}' >"$FOLDER/last.json"
  cp "$FOLDER/last.json" "$CASE/before"

  ROUTINE_TEST_FAIL=mv:admitted rw "$NAME" -- "$BIN/mark.sh" "$CASE/m"
  eq $? 74 "admission failure exit"
  [ ! -e "$CASE/m" ] && [ ! -e "$FOLDER/admitted" ] && [ ! -e "$FOLDER/runs.jsonl" ] || fail "admission failure ran or recorded the command"
  cmp -s "$CASE/before" "$FOLDER/last.json" || fail "admission failure changed the latest run"
  rw "$NAME" -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "retry exit"
  rw "$NAME" -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "cap skip exit"
  eq "$(lines "$CASE/m")" 1 "exactly one command admitted"
}

t_concurrent_busy_pruning_keeps_the_newest_hundred() {
  new_case
  bg $NAME -- "$BIN/wait.sh" "$CASE/active" "$CASE/done"
  local owner="$BGPID" first i
  wait_for "$CASE/active"
  mkdir -p "$FOLDER/busy"
  for i in $(seq 1 100); do
    printf -v first '0000000000000000-%03d.json' "$i"
    : >"$FOLDER/busy/$first"
  done

  ROUTINE_TEST_HOLD="busy-prune:$CASE/prune" bg $NAME -- "$BIN/mark.sh" "$CASE/m"
  first="$BGPID"
  wait_for "$CASE/prune.reached"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 75 "second busy start"
  touch "$CASE/prune"
  wait "$first"; eq $? 75 "first busy start"
  eq "$(ls "$FOLDER/busy" | wc -l | tr -d ' ')" 100 "busy records kept"
  [ -f "$FOLDER/busy/0000000000000000-003.json" ] || fail "third-oldest record was lost"
  [ ! -e "$CASE/m" ] || fail "a busy start ran the command"
  touch "$CASE/done"
  wait "$owner"; eq $? 0 "lock holder exit"
}

t_running_is_on_disk() {
  new_case
  bg $NAME -- "$BIN/wait.sh" "$CASE/m" "$CASE/rel"
  wait_for "$CASE/m"
  wait_cmd_pid "$FOLDER/last.json"
  eq "$(jf "$FOLDER/last.json" state)" running state
  eq "$(jf "$FOLDER/last.json" pid)" "$BGPID" "wrapper pid"
  eq "$(jf "$FOLDER/last.json" cmd_pid)" "$(cat "$CASE/m")" "cmd_pid is the command's own pid"
  eq "$(jf "$FOLDER/last.json" exit)" null "exit while running"
  valid_json "$FOLDER/last.json" || fail "running record is not JSON"
  touch "$CASE/rel"; wait "$BGPID"; eq $? 0 "exit"
  eq "$(jf "$FOLDER/last.json" state)" ok "final state"
  [ "$(jf "$FOLDER/last.json" ended)" != null ] || fail "no ended time"
}

t_arguments_env_stdin_streams() {
  new_case
  cat >"$BIN/probe.sh" <<'EOF'
#!/bin/bash
printf '%s|' "$@" >"$PROBE/args"
printf '%s' "$FOO" >"$PROBE/env"
cat >"$PROBE/stdin"
echo to-out
echo to-err >&2
exit 0
EOF
  chmod +x "$BIN/probe.sh"
  mkdir -p "$CASE/p"
  printf 'line1\nline2' | PROBE="$CASE/p" FOO='x y' /bin/bash "$R" run $NAME -- "$BIN/probe.sh" 'a b' 'c  d' '' '*' >"$CASE/out" 2>"$CASE/err"
  eq $? 0 "exit"
  eq "$(cat "$CASE/p/args")" 'a b|c  d||*|' args
  eq "$(cat "$CASE/p/env")" 'x y' env
  eq "$(cat "$CASE/p/stdin")" "$(printf 'line1\nline2')" stdin
  eq "$(cat "$CASE/out")" to-out stdout
  eq "$(cat "$CASE/err")" to-err stderr
}

t_off_in_folder_and_parent() {
  new_case
  mkdir -p "$FOLDER"; touch "$FOLDER/off"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "folder off exit"
  [ ! -e "$CASE/m" ] || fail "ran with off in the folder"
  grep -q '"reason":"off"' "$FOLDER/runs.jsonl" || fail "no off record"
  rm "$FOLDER/off"; touch "$ETABLI_ROUTINES_DIR/off"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "parent off exit"
  [ ! -e "$CASE/m" ] || fail "ran with off in the parent"
  eq "$(lines "$FOLDER/runs.jsonl")" 2 "journal lines"
  [ ! -e "$FOLDER/last.json" ] || fail "an off skip wrote last.json"
}

t_skips_leave_last_json() {
  new_case
  rw $NAME -- "$BIN/mark.sh" "$CASE/first"
  local base; base=$(cksum <"$FOLDER/last.json")
  touch "$FOLDER/off"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"
  rm "$FOLDER/off"
  eq "$(cksum <"$FOLDER/last.json")" "$base" "last.json after off"
  echo 1 >"$FOLDER/cap"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "cap exit"
  rm "$FOLDER/cap"
  eq "$(cksum <"$FOLDER/last.json")" "$base" "last.json after cap"
  [ ! -e "$CASE/m" ] || fail "a skip ran the command"
  bg $NAME -- "$BIN/wait.sh" "$CASE/w" "$CASE/rel"
  wait_for "$CASE/w"; wait_cmd_pid "$FOLDER/last.json"
  local running; running=$(cksum <"$FOLDER/last.json")
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 75 "busy exit"
  eq "$(cksum <"$FOLDER/last.json")" "$running" "last.json after busy"
  [ ! -e "$CASE/m" ] || fail "a busy start ran the command"
  touch "$CASE/rel"; wait "$BGPID"
  eq "$(jf "$FOLDER/last.json" state)" ok "the holder's end record landed"
  eq "$(ls "$FOLDER/busy" | wc -l | tr -d ' ')" 1 "busy files"
}

t_busy_files_stay_bounded() {
  new_case
  bg $NAME -- "$BIN/wait.sh" "$CASE/w" "$CASE/rel"
  wait_for "$CASE/w"; wait_cmd_pid "$FOLDER/last.json"
  local i=0 first="" before after
  while [ "$i" -lt 150 ]; do
    i=$((i + 1))
    [ "$i" -ne 150 ] || before=$(ls "$FOLDER/busy")
    rw $NAME -- "$BIN/mark.sh" "$CASE/m"
    [ "$i" -ne 1 ] || first=$(ls "$FOLDER/busy" | head -n 1)
  done
  after=$(ls "$FOLDER/busy")
  eq "$(echo "$after" | wc -l | tr -d ' ')" 100 "busy files kept"
  [ ! -e "$FOLDER/busy/$first" ] || fail "the oldest busy file is still there"
  [ "$(printf '%s\n%s\n' "$before" "$after" | sort | uniq -u | wc -l | tr -d ' ')" -ge 1 ] || fail "the newest busy file is missing"
  [ ! -e "$FOLDER/runs.jsonl" ] || fail "busy skips touched the journal"
  ! ls "$FOLDER/busy" | grep -qv '\.json$' || fail "a temporary file was left"
  touch "$CASE/rel"; wait "$BGPID"
}

t_cap_counts_admitted_runs() {
  new_case
  mkdir -p "$FOLDER"; echo 2 >"$FOLDER/cap"
  local y; y=$(day -1)
  printf '%s old-1\n%s old-2\n%s old-3\n%s old-4\n%s old-5\n' $y $y $y $y $y >"$FOLDER/admitted"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "first run"
  bg $NAME -- "$BIN/wait.sh" "$CASE/w" "$CASE/rel"
  wait_for "$CASE/w"; wait_cmd_pid "$FOLDER/last.json"
  kill_run "$FOLDER/last.json"
  eq "$(lines "$FOLDER/runs.jsonl")" 1 "an interrupted run has no journal line"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m3"; eq $? 0 "skip exit"
  [ ! -e "$CASE/m3" ] || fail "the third start ran over the cap"
  eq "$(lines "$CASE/m")" 1 "command runs"
  eq "$(lines "$FOLDER/admitted")" 2 "admitted holds today's two runs only"
  eq "$(grep -c "^$(day 0) " "$FOLDER/admitted")" 2 "admitted lines are dated today"
  grep -q '"reason":"cap"' "$FOLDER/runs.jsonl" || fail "no cap record"
}

t_cap_clock_going_back() {
  new_case
  mkdir -p "$FOLDER"; echo 3 >"$FOLDER/cap"
  local t; t=$(day 0)
  printf '%s a\n%s b\n%s c\n%s d\n' "$t" "$t" "$t" "$(day 1)" >"$FOLDER/admitted"
  local base i=0
  base=$(cksum <"$FOLDER/admitted")
  while [ "$i" -lt 4 ]; do
    i=$((i + 1))
    rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "skip exit"
  done
  [ ! -e "$CASE/m" ] || fail "ran with the clock set back"
  eq "$(cksum <"$FOLDER/admitted")" "$base" "admitted"
  eq "$(grep -c '"reason":"cap".*"clock":true' "$FOLDER/runs.jsonl")" 4 "clock records"
  printf '%s a\n%s b\n%s c\n%s d\n' "$(day -1)" "$(day -1)" "$(day -1)" "$t" >"$FOLDER/admitted"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "run exit"
  eq "$(lines "$CASE/m")" 1 "admitted again once the date catches up"
}

t_killed_run_leaves_nothing_to_clear() {
  new_case
  bg $NAME -- "$BIN/wait.sh" "$CASE/w" "$CASE/rel"
  wait_for "$CASE/w"; wait_cmd_pid "$FOLDER/last.json"
  local inode; inode=$(ls -i "$FOLDER/run.lock" | awk '{print $1}')
  kill_run "$FOLDER/last.json"
  local i=0
  while [ "$i" -lt 10 ]; do
    i=$((i + 1))
    rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "run $i"
  done
  eq "$(lines "$CASE/m")" 10 "commands run"
  eq "$(ls -i "$FOLDER/run.lock" | awk '{print $1}')" "$inode" "run.lock inode"
  { [ -f "$FOLDER/run.lock" ] && [ ! -s "$FOLDER/run.lock" ]; } || fail "run.lock is not an empty regular file"
}

t_dead_wrapper_live_command_keeps_lock() {
  new_case
  bg $NAME -- "$BIN/wait.sh" "$CASE/w" "$CASE/rel"
  wait_for "$CASE/w"; wait_cmd_pid "$FOLDER/last.json"
  local c; c=$(jf "$FOLDER/last.json" cmd_pid)
  kill_hard "$BGPID"
  kill -0 "$c" 2>/dev/null || fail "the command died with the wrapper"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 75 "start while the command lives"
  [ ! -e "$CASE/m" ] || fail "ran while the command lived"
  touch "$CASE/rel"; wait_gone "$c"
  wait_lock_free "$FOLDER"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "start after the command ended"
  eq "$(lines "$CASE/m")" 1 "command runs"
}

t_twenty_starts_run_once() {
  new_case
  local round i p pids
  for round in 1 2; do
    rm -rf "$CASE/ex" "$CASE/rel" "$CASE/c"; mkdir -p "$CASE/ex"
    if [ "$round" = 2 ]; then
      bg $NAME -- "$BIN/wait.sh" "$CASE/h" "$CASE/never"
      wait_for "$CASE/h"; wait_cmd_pid "$FOLDER/last.json"
      kill_run "$FOLDER/last.json"
    fi
    pids=""
    i=0
    while [ "$i" -lt 20 ]; do
      i=$((i + 1))
      ( /bin/bash "$R" run $NAME -- "$BIN/wait.sh" "$CASE/c" "$CASE/rel" </dev/null >/dev/null 2>&1; echo $? >"$CASE/ex/$i" ) &
      pids="$pids $!"; track $!
    done
    i=0
    while [ "$(ls "$CASE/ex" | wc -l | tr -d ' ')" -lt 19 ]; do
      i=$((i + 1)); [ "$i" -le 600 ] || fail "round $round: the other starts did not return"
      /bin/sleep 0.1
    done
    touch "$CASE/rel"
    for p in $pids; do wait "$p"; done
    eq "$(lines "$CASE/c")" 1 "round $round: command runs"
    eq "$(cat "$CASE/ex"/* | grep -c '^75$')" 19 "round $round: busy exits"
  done
}

t_background_process_does_not_hold_lock() {
  new_case
  cat >"$BIN/leave.sh" <<'EOF'
#!/bin/bash
/bin/sleep 60 </dev/null >/dev/null 2>&1 &
echo $! >"$1"
exit 0
EOF
  chmod +x "$BIN/leave.sh"
  rw $NAME -- "$BIN/leave.sh" "$CASE/bgpid"; eq $? 0 "first run"
  track "$(cat "$CASE/bgpid")"
  kill -0 "$(cat "$CASE/bgpid")" 2>/dev/null || fail "the background process did not outlive the run"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 0 "next start"
  eq "$(lines "$CASE/m")" 1 "next start runs"
}

t_lock_failure_runs_nothing() {
  new_case
  rw $NAME -- "$BIN/mark.sh" "$CASE/first"
  local before j
  before=$(cksum <"$FOLDER/last.json"); j=$(cksum <"$FOLDER/runs.jsonl")
  printf '#!/bin/bash\nexit 1\n' >"$BIN/perl-stub"; chmod +x "$BIN/perl-stub"
  ROUTINE_TEST_PERL="$BIN/perl-stub" rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 74 "exit"
  [ ! -e "$CASE/m" ] || fail "ran without the lock"
  eq "$(cksum <"$FOLDER/last.json")" "$before" "last.json"
  eq "$(cksum <"$FOLDER/runs.jsonl")" "$j" "journal"
  [ ! -e "$FOLDER/busy" ] || fail "a failed lock was recorded as busy"
}

hold_kill_case() {
  new_case
  bg_hold "$1"
  local sub; sub=$(subshell_of "$BGPID") || fail "no subshell at the hold point"
  track "$sub"
  kill_hard "$BGPID"
  wait_gone "$sub" 10
  wait_lock_free "$FOLDER"
  [ ! -e "$CASE/a" ] || fail "the command ran"
  rw $NAME -- "$BIN/mark.sh" "$CASE/b"; eq $? 0 "second start"
  eq "$(lines "$CASE/b")" 1 "second start runs once"
  [ ! -e "$CASE/a" ] || fail "the first command ran"
}
t_killed_before_identity() { hold_kill_case identity; }
t_killed_between_identity_and_go() { hold_kill_case go; }

t_killed_right_after_go() {
  new_case
  ROUTINE_TEST_HOLD="after-go:$CASE/hold" bg $NAME -- "$BIN/wait.sh" "$CASE/a" "$CASE/rel"
  wait_for "$CASE/hold.reached"
  kill_hard "$BGPID"
  wait_for "$CASE/a"
  rw $NAME -- "$BIN/mark.sh" "$CASE/b"; eq $? 75 "start during the command"
  [ ! -e "$CASE/b" ] || fail "ran during the command"
  touch "$CASE/rel"; wait_gone "$(cat "$CASE/a")"
  wait_lock_free "$FOLDER"
  rw $NAME -- "$BIN/mark.sh" "$CASE/b"; eq $? 0 "start after the command"
  eq "$(lines "$CASE/b")" 1 "runs once"
}

t_stopped_subshell_holds_lock() {
  new_case
  bg_hold identity
  local sub; sub=$(subshell_of "$BGPID") || fail "no subshell"
  track "$sub"
  kill -STOP "$sub"
  kill_hard "$BGPID"
  rw $NAME -- "$BIN/mark.sh" "$CASE/b"; eq $? 75 "start while the subshell is stopped"
  /bin/sleep 1
  rw $NAME -- "$BIN/mark.sh" "$CASE/b"; eq $? 75 "still busy a second later"
  kill -CONT "$sub"
  wait_gone "$sub" 10
  wait_lock_free "$FOLDER"
  [ ! -e "$CASE/a" ] || fail "the continued subshell ran the command"
  rw $NAME -- "$BIN/mark.sh" "$CASE/b"; eq $? 0 "start after the subshell left"
  eq "$(lines "$CASE/b")" 1 "runs once"
}

t_reused_wrapper_pid_is_not_the_wrapper() {
  new_case
  local real=/bin/ps
  [ -x "$real" ] || real=/usr/bin/ps
  cat >"$BIN/ps-stub" <<EOF
#!/bin/bash
if [ -e "\$STUB_DIR/killed" ] && [ "\$*" = "-o lstart= -p \$(cat "\$STUB_DIR/wpid")" ]; then
  echo "Mon Jan  1 00:00:00 2001"
  exit 0
fi
exec $real "\$@"
EOF
  chmod +x "$BIN/ps-stub"
  mkdir -p "$CASE/stub"
  export STUB_DIR="$CASE/stub"
  ROUTINE_TEST_PS="$BIN/ps-stub" ROUTINE_TEST_HOLD="identity:$CASE/hold" bg $NAME -- "$BIN/mark.sh" "$CASE/a"
  echo "$BGPID" >"$CASE/stub/wpid"
  wait_for "$CASE/hold.reached"
  local sub; sub=$(subshell_of "$BGPID") || fail "no subshell"
  track "$sub"
  kill_hard "$BGPID"
  touch "$CASE/stub/killed"
  wait_gone "$sub" 15
  wait_lock_free "$FOLDER"
  [ ! -e "$CASE/a" ] || fail "the command ran"
  rw $NAME -- "$BIN/mark.sh" "$CASE/b"; eq $? 0 "start after the subshell left"
  eq "$(lines "$CASE/b")" 1 "runs once"
}

t_stale_go_file_removed() {
  new_case
  mkdir -p "$FOLDER"; touch "$FOLDER/go.old-run" "$FOLDER/go.other"
  cat >"$BIN/golist.sh" <<'EOF'
#!/bin/bash
ls "$1" | grep '^go\.' >"$2"
EOF
  chmod +x "$BIN/golist.sh"
  rw $NAME -- "$BIN/golist.sh" "$FOLDER" "$CASE/during"; eq $? 0 "exit"
  eq "$(wc -l <"$CASE/during" | tr -d ' ')" 1 "go files while the command runs (its own)"
  ! grep -q 'old-run\|other' "$CASE/during" || fail "a stale go file was kept"
  ! ls "$FOLDER" | grep -q '^go\.' || fail "a go file is left after the run"
}

signal_case() {
  new_case
  /usr/bin/perl -e '$SIG{INT} = "DEFAULT"; exec @ARGV' /bin/bash "$R" run $NAME -- "$BIN/wait.sh" "$CASE/w" "$CASE/never" </dev/null >/dev/null 2>&1 &
  BGPID=$!; track "$BGPID"
  wait_for "$CASE/w"; wait_cmd_pid "$FOLDER/last.json"
  kill -"$1" "$BGPID"
  wait "$BGPID"; eq $? "$2" "exit after $1"
  eq "$(jf "$FOLDER/last.json" state)" failed "state after $1"
  eq "$(jf "$FOLDER/last.json" signal)" "$3" "signal after $1"
  eq "$(jf "$FOLDER/last.json" exit)" "$2" "exit field after $1"
  grep -q '"state":"failed"' "$FOLDER/runs.jsonl" || fail "no journal line"
}
t_term_reaches_command() { signal_case TERM 143 TERM; }
t_hup_reaches_command() { signal_case HUP 129 HUP; }
t_int_reaches_command_as_term() { signal_case INT 143 TERM; }

t_command_ignoring_term_is_waited_for() {
  new_case
  cat >"$BIN/stubborn.sh" <<'EOF'
#!/bin/bash
trap '' TERM
echo $$ >"$1"
while [ ! -e "$2" ]; do /bin/sleep 0.1; done
exit 0
EOF
  chmod +x "$BIN/stubborn.sh"
  bg $NAME -- "$BIN/stubborn.sh" "$CASE/w" "$CASE/rel"
  wait_for "$CASE/w"; wait_cmd_pid "$FOLDER/last.json"
  kill -TERM "$BGPID"
  /bin/sleep 1
  kill -0 "$BGPID" 2>/dev/null || fail "the wrapper left while its command lived"
  eq "$(jf "$FOLDER/last.json" state)" running "state while the command lives"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"; eq $? 75 "start while the command lives"
  touch "$CASE/rel"; wait "$BGPID"; eq $? 0 "exit"
  eq "$(jf "$FOLDER/last.json" state)" ok "state"
  eq "$(jf "$FOLDER/last.json" signal)" TERM "signal passed on"
}

t_term_during_end_record() {
  new_case
  ROUTINE_TEST_HOLD="end:$CASE/hold" bg $NAME -- "$BIN/wait.sh" "$CASE/w" "$CASE/rel"
  wait_for "$CASE/w"; touch "$CASE/rel"
  wait_for "$CASE/hold.reached"
  kill -TERM "$BGPID"
  /bin/sleep 0.5
  kill -0 "$BGPID" 2>/dev/null || fail "TERM stopped the wrapper while it writes the end record"
  valid_json "$FOLDER/last.json" || fail "last.json is not valid JSON"
  touch "$CASE/hold"; wait "$BGPID"; eq $? 0 "exit"
  valid_json "$FOLDER/last.json" || fail "final last.json is not valid JSON"
  eq "$(jf "$FOLDER/last.json" state)" ok state
}

t_summary_is_valid_json() {
  new_case
  cat >"$BIN/summ.sh" <<'EOF'
#!/bin/bash
printf 'said "hi" \\ back\tx\nsecond line\n' >"$ROUTINE_SUMMARY"
exit 0
EOF
  chmod +x "$BIN/summ.sh"
  rw $NAME -- "$BIN/summ.sh"; eq $? 0 "exit"
  valid_json "$FOLDER/last.json" || fail "last.json is not JSON"
  [ "$HAVE_JQ" = 0 ] || jq -e . "$FOLDER/runs.jsonl" >/dev/null || fail "journal line is not JSON"
  eq "$(jf "$FOLDER/last.json" summary)" 'said hi  backx' summary
  ! ls "$FOLDER" | grep -q '^summary\.' || fail "summary file left behind"
}

t_journal_rotates() {
  new_case
  mkdir -p "$FOLDER"; seed_lines "$FOLDER/runs.jsonl" 249
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"
  eq "$(lines "$FOLDER/runs.1.jsonl")" 250 "rotated journal"
  eq "$(lines "$FOLDER/runs.jsonl")" 0 "fresh journal"
  rw $NAME -- "$BIN/mark.sh" "$CASE/m"
  eq "$(lines "$FOLDER/runs.jsonl")" 1 "journal restarts"
}

t_busy_record_survives_rotation() {
  new_case
  mkdir -p "$FOLDER"; seed_lines "$FOLDER/runs.jsonl" 249
  bg $NAME -- "$BIN/wait.sh" "$CASE/w" "$CASE/rel"
  wait_for "$CASE/w"; wait_cmd_pid "$FOLDER/last.json"
  local holder=$BGPID busy
  ROUTINE_TEST_HOLD="busy:$CASE/hold" bg $NAME -- "$BIN/mark.sh" "$CASE/m"
  busy=$BGPID
  wait_for "$CASE/hold.reached"
  touch "$CASE/rel"; wait "$holder"
  seed_lines "$FOLDER/runs.jsonl" 249
  rw $NAME -- "$BIN/mark.sh" "$CASE/m2"
  touch "$CASE/hold"; wait "$busy"; eq $? 75 "busy exit"
  eq "$(ls "$FOLDER/busy" | wc -l | tr -d ' ')" 1 "busy files"
  ls "$FOLDER/busy" | grep -q '\.json$' || fail "the busy record was not renamed into place"
  ! grep -qs 'busy' "$FOLDER"/runs*.jsonl || fail "the busy record is in the journal"
  [ ! -e "$CASE/m" ] || fail "the busy start ran the command"
}

trap_case() {
  new_case
  cat >"$BIN/trapper.sh" <<'EOF'
#!/bin/bash
trap 'exit '"$3" TERM
echo $$ >"$1"
while [ ! -e "$2" ]; do /bin/sleep 0.1; done
exit 0
EOF
  chmod +x "$BIN/trapper.sh"
  bg $NAME -- "$BIN/trapper.sh" "$CASE/w" "$CASE/never" "$1"
  wait_for "$CASE/w"; /bin/sleep 0.5; wait_cmd_pid "$FOLDER/last.json"
  kill -TERM "$BGPID"
  wait "$BGPID"; eq $? "$1" "exit"
  eq "$(jf "$FOLDER/last.json" state)" "$2" state
  eq "$(jf "$FOLDER/last.json" signal)" TERM signal
  eq "$(jf "$FOLDER/last.json" exit)" "$1" "exit field"
}
t_trap_term_exits_3() { trap_case 3 failed; }
t_trap_term_exits_0() { trap_case 0 ok; }

t_interrupted_wait_retrieves_already_exited_child() {
  new_case
  cat >"$BIN/delayed-trap.sh" <<'EOF'
#!/bin/bash
trap 'while [ ! -e "$3" ]; do /bin/sleep 0.1; done; exit 3' TERM
echo $$ >"$1"
while [ ! -e "$2" ]; do /bin/sleep 0.1; done
EOF
  chmod +x "$BIN/delayed-trap.sh"
  ROUTINE_TEST_HOLD="waited:$CASE/waited" bg $NAME -- "$BIN/delayed-trap.sh" "$CASE/child" "$CASE/never" "$CASE/exit-now"
  wait_for "$CASE/child"
  kill -TERM "$BGPID"
  wait_for "$CASE/waited.reached"
  touch "$CASE/exit-now"
  wait_gone "$(cat "$CASE/child")"
  touch "$CASE/waited"
  wait "$BGPID"; eq $? 3 "wrapper exit after interrupted wait"
  eq "$(jf "$FOLDER/last.json" exit)" 3 "recorded child exit"
  eq "$(jf "$FOLDER/last.json" signal)" TERM "forwarded signal"
}

t_failed_go_publication_releases_the_lock() {
  new_case
  bg_hold go
  local cmd run
  wait_cmd_pid "$FOLDER/last.json"
  cmd=$(jf "$FOLDER/last.json" cmd_pid)
  track "$cmd"
  run=$(jf "$FOLDER/last.json" run)
  mkdir "$FOLDER/go.$run"
  touch "$CASE/hold"
  wait_gone "$BGPID"
  wait "$BGPID"; eq $? 74 "failed go publication"
  wait_lock_free "$FOLDER"
  [ ! -e "$CASE/a" ] || fail "command started without the gate"
  eq "$(jf "$FOLDER/last.json" state)" failed "latest state"
  eq "$(jf "$FOLDER/last.json" exit)" 74 "latest exit"
}

t_hup_during_startup_is_not_followed_by_term() {
  new_case
  cat >"$BIN/startup-signals.sh" <<'EOF'
#!/bin/bash
trap 'touch "$2"' HUP
trap 'exit 77' TERM
touch "$1"
while [ ! -e "$3" ]; do /bin/sleep 0.1; done
EOF
  chmod +x "$BIN/startup-signals.sh"
  ROUTINE_TEST_HOLD="after-go:$CASE/hold" bg "$NAME" -- "$BIN/startup-signals.sh" "$CASE/child" "$CASE/hup" "$CASE/end"
  wait_for "$CASE/hold.reached"
  wait_for "$CASE/child"
  kill -HUP "$BGPID"
  wait_for "$CASE/hup"
  touch "$CASE/hold"
  /bin/sleep 0.5
  touch "$CASE/end"
  wait "$BGPID"; eq $? 0 "HUP was handled"
  eq "$(jf "$FOLDER/last.json" signal)" HUP "forwarded signal"
}

t_signal_before_identity_is_recorded() {
  new_case
  bg_hold identity
  local cmd
  cmd=$(subshell_of "$BGPID") || fail "no waiting subshell"
  track "$cmd"
  kill -HUP "$BGPID"
  wait_gone "$cmd"
  touch "$CASE/hold"
  wait "$BGPID"; eq $? 129 "signalled subshell exit"
  eq "$(jf "$FOLDER/last.json" signal)" HUP "forwarded signal"
  [ ! -e "$CASE/a" ] || fail "the command ran before identity"
}

t_pending_signal_is_delivered_even_when_birth_lookup_fails() {
  new_case
  cat >"$BIN/ps-failure" <<'EOF'
#!/bin/bash
if [ -f "$BIRTH_FAILURE" ] && [ "$4" != "$(cat "$WRAPPER_ID")" ]; then exit 1; fi
exec /bin/ps "$@"
EOF
  chmod +x "$BIN/ps-failure"
  export BIRTH_FAILURE="$CASE/birth-failure" WRAPPER_ID="$CASE/wrapper-id"
  ROUTINE_TEST_PS="$BIN/ps-failure" ROUTINE_TEST_HOLD="before-spawn:$CASE/hold" bg "$NAME" -- "$BIN/mark.sh" "$CASE/a"
  wait_for "$CASE/hold.reached"
  printf '%s\n' "$BGPID" >"$WRAPPER_ID"
  kill -HUP "$BGPID"
  touch "$BIRTH_FAILURE" "$CASE/hold"
  wait_gone "$BGPID"
  wait "$BGPID"; eq $? 129 "pending HUP exit"
  eq "$(jf "$FOLDER/last.json" signal)" HUP "forwarded signal"
  [ ! -e "$CASE/a" ] || fail "the command ran without identity"
}

t_off_skips_stay_bounded() {
  new_case
  mkdir -p "$FOLDER"; touch "$FOLDER/off"
  local i=0 n1 n2
  while [ "$i" -lt "${ROUTINE_TEST_OFF_SKIPS:-1000}" ]; do
    i=$((i + 1))
    /bin/bash "$R" run $NAME -- "$BIN/mark.sh" "$CASE/m" </dev/null >/dev/null 2>&1
  done
  n1=$(lines "$FOLDER/runs.jsonl"); n2=$(lines "$FOLDER/runs.1.jsonl")
  { [ "$n1" -le 250 ] && [ "$n2" -le 250 ]; } || fail "journal files over 250 lines ($n1, $n2)"
  [ "$n2" -eq 250 ] || fail "no rotation: runs.1.jsonl has $n2 lines"
  [ ! -e "$FOLDER/runs.2.jsonl" ] || fail "a third journal file"
  [ ! -e "$CASE/m" ] || fail "an off skip ran the command"
}

t_summary_cut_inside_character() {
  new_case
  cat >"$BIN/cut.sh" <<'EOF'
#!/bin/bash
{ printf 'a%.0s' $(seq 1 199); printf '\xc3\xa9\n'; } >"$ROUTINE_SUMMARY"
exit 3
EOF
  chmod +x "$BIN/cut.sh"
  rw $NAME -- "$BIN/cut.sh"; eq $? 3 "exit code"
  local want; want=$(printf 'a%.0s' $(seq 1 199))
  valid_json "$FOLDER/last.json" || fail "last.json is not JSON"
  eq "$(jf "$FOLDER/last.json" summary)" "$want" "summary"
  eq "$(jf "$FOLDER/last.json" state)" failed state
  eq "$(jf "$FOLDER/runs.jsonl" summary)" "$want" "journal summary"
  eq "$(jf "$FOLDER/runs.jsonl" state)" failed "journal state"
}

t_invalid_names_refused() {
  new_case
  local n
  for n in '../x' 'a/b' 'A' '' '.' 'a b' 'é' 'x_y' "$(printf 'a%.0s' $(seq 1 41))"; do
    rw "$n" -- "$BIN/mark.sh" "$CASE/m"; eq $? 2 "name '$n'"
  done
  [ ! -e "$CASE/m" ] || fail "a refused name ran the command"
  [ ! -e "$CASE/x" ] || fail "a path was created"
  eq "$(ls "$ETABLI_ROUTINES_DIR" | wc -l | tr -d ' ')" 0 "routines folder"
  rw "$(printf 'a%.0s' $(seq 1 40))" -- "$BIN/mark.sh" "$CASE/ok"; eq $? 0 "40 characters is valid"
  rw $NAME "$BIN/mark.sh"; eq $? 2 "missing --"
  rw $NAME --; eq $? 2 "missing command"
}

t_defaults_and_unimplemented() {
  new_case
  unset ETABLI_ROUTINES_DIR
  /bin/bash "$R" run dflt -- "$BIN/mark.sh" "$CASE/m" </dev/null >/dev/null 2>&1; eq $? 0 "exit"
  [ -f "$HOME/.claude/state/routines/dflt/last.json" ] || fail "default folder not used"
  local s
  for s in adopt release nothing; do
    /bin/bash "$R" $s </dev/null >/dev/null 2>&1; eq $? 2 "$s"
  done
  /bin/bash "$R" status </dev/null >/dev/null 2>&1; eq $? 0 "status"
}

t_no_model_binary() {
  ! grep -Eq '(^|[[:space:]|;(])(claude|codex|gemini|pi|llm)[[:space:]]+(-|[a-z])' "$R" || fail "the wrapper calls a model binary"
  ! grep -Eq 'claude-bin|anthropic|openai' "$R" || fail "the wrapper names a model provider"
}

run_test() {
  local out rc
  out=$( ( PIDS=""; trap cleanup_pids EXIT; "$1" ) 2>&1 )
  rc=$?
  if [ "$rc" = 0 ]; then printf 'PASS %s\n' "$1"; else printf 'FAIL %s\n%s\n' "$1" "$out"; FAILED=$((FAILED + 1)); fi
}

TESTS=$(declare -F | awk '{print $3}' | grep '^t_')
for t in $TESTS; do
  case " ${*:-$t} " in *" ${t#t_} "*|*" $t "*) run_test "$t" ;; esac
done

if [ "$FAILED" -ne 0 ]; then printf '%s test(s) failed\n' "$FAILED"; exit 1; fi
printf 'routine run smoke: ok\n'
