#!/bin/bash
# Routine run records, contract v1 (docs/routines.md).
#   routine.sh run <name> -- <command...>
# bash 3.2 (macOS /bin/bash): no associative arrays, no BASHPID, no wait -n.
# System tools are called by absolute path; the command keeps the caller's PATH.
#
# Exit codes of `run`: the command's own (128+n when a signal ended it); 75 when
# another run holds the lock (busy skip); 0 for an `off` or `cap` skip; 74 when
# the lock or the record cannot be set up (nothing is written); 2 for a
# refused or malformed call.

ROUTINE_SELF="${BASH_SOURCE[0]}"
RESERVED_NAME=fleet-improvement
RESERVED_LABEL=com.tonours.fleet-improvement
JOURNAL_LINES=250
BUSY_KEEP=100

routines_dir() { printf '%s' "${ETABLI_ROUTINES_DIR:-$HOME/.claude/state/routines}"; }

die() { printf 'routine: %s\n' "$*" >&2; }

valid_name() {
  case "$1" in
    ''|*[!a-z0-9-]*) return 1 ;;
  esac
  [ "${#1}" -le 40 ]
}

now_iso() { /bin/date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- processes -------------------------------------------------------------

# The kernel's birth second of a process, as `ps` prints it in UTC with single
# spaces ("Wed Nov 18 01:21:40 2026"); empty when the process is gone.
born_of() {
  local ps out
  ps="${ROUTINE_TEST_PS:-}"
  if [ -z "$ps" ]; then
    ps=/bin/ps
    [ -x "$ps" ] || ps=/usr/bin/ps
  fi
  out=$(LC_ALL=C TZ=UTC "$ps" -o lstart= -p "$1" 2>/dev/null)
  set -- $out
  printf '%s' "$*"
}

# --- kernel lock -----------------------------------------------------------
# A lock on the open file behind descriptor 9, taken with flock(2) through
# Perl, since macOS has no flock command. It belongs to the open file, not to
# the Perl process, so it stays after Perl exits and is shared by every process
# that inherits descriptor 9. Slice 2 reuses both functions for adopt.lock.

# Returns 0 when taken, 75 when another holder has it, 74 for any other cause.
routine_lock_try() {
  local perl="${ROUTINE_TEST_PERL:-/usr/bin/perl}" st
  "$perl" -e 'use Fcntl qw(:flock); open(my $h, ">&=", 9) or exit 74; flock($h, LOCK_EX|LOCK_NB) or exit 75'
  st=$?
  case "$st" in 0|75) return "$st" ;; *) return 74 ;; esac
}

# Drops the lock for every process sharing the open file.
routine_lock_release() {
  /usr/bin/perl -e 'use Fcntl qw(:flock); open(my $h, ">&=", 9) or exit 74; flock($h, LOCK_UN)' 2>/dev/null
}

# --- test hold points ------------------------------------------------------
# ROUTINE_TEST_HOLD=<point>:<file>, read only when set: wait there until the
# file exists, and says it got there with <file>.reached. Points: busy,
# identity, go, after-go, end.
hold() {
  case "${ROUTINE_TEST_HOLD:-}" in
    "$1":*)
      local f="${ROUTINE_TEST_HOLD#*:}"
      : >"$f.reached"
      while [ ! -e "$f" ]; do /bin/sleep 0.1; done
      ;;
  esac
}

# --- records ---------------------------------------------------------------

jq_s() { if [ -n "$1" ]; then printf '"%s"' "$1"; else printf null; fi; }
jq_n() { printf '%s' "${1:-null}"; }

# $folder, $name, $run, $self_born and $started are set by cmd_run.
# write_last <state> <cmd_pid> <cmd_born> <ended> <exit> <signal> <summary>
write_last() {
  local tmp="$folder/last.json.$$.tmp"
  printf '{"v":1,"name":"%s","run":"%s","state":"%s","pid":%s,"pid_born":"%s","started":"%s","cmd_pid":%s,"cmd_born":%s,"ended":%s,"exit":%s,"signal":%s,"summary":"%s"}\n' \
    "$name" "$run" "$1" "$$" "$self_born" "$started" "$(jq_n "$2")" "$(jq_s "$3")" "$(jq_s "$4")" "$(jq_n "$5")" "$(jq_s "$6")" "$7" >"$tmp" \
    && /bin/mv -f "$tmp" "$folder/last.json"
}

# Appends one line to the journal (one write), then rotates it at 250 lines.
# Only the holder of the run lock calls this.
journal_append() {
  printf '%s\n' "$1" >>"$folder/runs.jsonl"
  local n
  n=$(/usr/bin/wc -l <"$folder/runs.jsonl")
  if [ "${n:-0}" -ge "$JOURNAL_LINES" ]; then
    /bin/mv -f "$folder/runs.jsonl" "$folder/runs.1.jsonl"
  fi
}

journal_skip() { # reason [extra json fields, leading comma]
  journal_append "$(printf '{"v":1,"name":"%s","kind":"skip","reason":"%s","time":"%s"%s}' "$name" "$1" "$(now_iso)" "${2:-}")"
}

# A busy skip is its own file: written under a temporary name, then renamed.
# Written without the run lock, it never touches the journal.
busy_skip() {
  local dir="$folder/busy" stamp id total drop f
  /bin/mkdir -p "$dir" 2>/dev/null || return 0
  stamp=$(/usr/bin/perl -MTime::HiRes=gettimeofday -e '($s, $u) = gettimeofday; printf "%010d%06d", $s, $u' 2>/dev/null)
  [ -n "$stamp" ] || stamp=$(/bin/date +%s)000000
  id="$stamp-$$-$RANDOM"
  printf '{"v":1,"name":"%s","kind":"skip","reason":"busy","time":"%s"}\n' "$name" "$(now_iso)" >"$dir/tmp.$id"
  hold busy
  /bin/mv -f "$dir/tmp.$id" "$dir/$id.json"
  total=$(/bin/ls "$dir" | LC_ALL=C /usr/bin/grep -c '\.json$')
  if [ "${total:-0}" -gt "$BUSY_KEEP" ]; then
    drop=$(/bin/ls "$dir" | LC_ALL=C /usr/bin/grep '\.json$' | LC_ALL=C /usr/bin/sort | /usr/bin/head -n "$((total - BUSY_KEEP))")
    for f in $drop; do /bin/rm -f "$dir/$f"; done
  fi
}

# First line of $ROUTINE_SUMMARY, 200 bytes at most, invalid UTF-8 dropped,
# quotes, backslashes and control characters removed. Never fails the run.
read_summary() {
  local line=""
  [ -f "$ROUTINE_SUMMARY" ] || { printf ''; return 0; }
  IFS= read -r line <"$ROUTINE_SUMMARY" || true
  printf '%s' "$line" | LC_ALL=C /usr/bin/head -c 200 \
    | { /usr/bin/iconv -c -f UTF-8 -t UTF-8 2>/dev/null || true; } \
    | LC_ALL=C /usr/bin/tr -d '"\\[:cntrl:]'
  return 0
}

# --- run -------------------------------------------------------------------

# INT and TERM reach the command as TERM (bash starts a background command with
# INT ignored), HUP as HUP. The wrapper keeps waiting for the command.
on_signal() {
  sig_sent="$1"
  [ -z "$cmd_pid" ] || kill -"$1" "$cmd_pid" 2>/dev/null
}

# finish <exit> <signal> <cmd_pid> <cmd_born> <summary>: the end record, the
# journal line, the unlock. Returns the command's exit code.
finish() {
  local st="$1" sig="$2" state ended
  ended=$(now_iso)
  if [ "$st" = 0 ]; then state=ok; else state=failed; fi
  write_last "$state" "$3" "$4" "$ended" "$st" "$sig" "$5"
  journal_append "$(printf '{"v":1,"name":"%s","kind":"run","run":"%s","state":"%s","started":"%s","ended":"%s","exit":%s,"signal":%s,"summary":"%s"}' \
    "$name" "$run" "$state" "$started" "$ended" "$st" "$(jq_s "$sig")" "$5")"
  /bin/rm -f "$folder/go.$run" "$ROUTINE_SUMMARY"
  routine_lock_release
  exec 9>&-
  return "$st"
}

cmd_run() {
  local name="${1:-}" dir folder lock_st today cap cnt future d r tmp
  if ! valid_name "$name"; then die "invalid routine name: $name"; return 2; fi
  shift
  if [ "${1:-}" != -- ] || [ "$#" -lt 2 ]; then die "usage: routine.sh run <name> -- <command...>"; return 2; fi
  shift
  [ "$name" != "$RESERVED_NAME" ] || { die "$name is reserved for its own writer"; return 2; }

  dir=$(routines_dir)
  folder="$dir/$name"
  if [ -f "$folder/routine.json" ] && /usr/bin/grep -Eq '"source"[[:space:]]*:[[:space:]]*"native"|"label"[[:space:]]*:[[:space:]]*"'"$RESERVED_LABEL"'"' "$folder/routine.json"; then
    die "$name has a native record writer; the wrapper does not touch it"
    return 2
  fi

  /bin/mkdir -p "$folder" 2>/dev/null || { die "cannot create $folder"; return 74; }
  ( : >>"$folder/run.lock" ) 2>/dev/null || { die "cannot open $folder/run.lock"; return 74; }
  exec 9>>"$folder/run.lock"

  routine_lock_try
  lock_st=$?
  if [ "$lock_st" = 75 ]; then
    busy_skip
    die "$name: busy"
    return 75
  elif [ "$lock_st" != 0 ]; then
    die "$name: cannot take the run lock (status $lock_st); nothing run, nothing recorded"
    return 74
  fi

  # From here on this process is the holder: the only writer of the records.
  /bin/rm -f "$folder"/go.* "$folder"/summary.* 2>/dev/null

  if [ -e "$folder/off" ] || [ -e "$dir/off" ]; then
    journal_skip off
    die "$name: off"
    return 0
  fi

  today=$(/bin/date +%Y-%m-%d)
  cap=""
  if [ -f "$folder/cap" ]; then
    IFS= read -r cap <"$folder/cap" || true
    case "$cap" in ''|*[!0-9]*) cap="" ;; esac
  fi
  cnt=0
  future=0
  if [ -f "$folder/admitted" ]; then
    while IFS=' ' read -r d r || [ -n "$d" ]; do
      [ -n "$d" ] || continue
      if [[ "$d" > "$today" ]]; then future=1
      elif [ "$d" = "$today" ]; then cnt=$((cnt + 1)); fi
    done <"$folder/admitted"
  fi
  if [ -n "$cap" ]; then
    if [ "$future" = 1 ]; then
      journal_skip cap ',"clock":true'
      die "$name: cap (clock went back)"
      return 0
    elif [ "$cnt" -ge "$cap" ]; then
      journal_skip cap
      die "$name: cap"
      return 0
    fi
  fi

  self_born=$(born_of "$$")
  if [ -z "$self_born" ]; then die "$name: cannot read the wrapper's birth; nothing run"; return 74; fi
  started=$(now_iso)
  run="$(/bin/date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"

  # admitted: today's line and later ones stay, earlier days are dropped.
  tmp="$folder/admitted.$$.tmp"
  {
    if [ -f "$folder/admitted" ]; then
      while IFS=' ' read -r d r || [ -n "$d" ]; do
        [ -n "$d" ] || continue
        if [[ "$d" > "$today" ]] || [ "$d" = "$today" ]; then printf '%s %s\n' "$d" "$r"; fi
      done <"$folder/admitted"
    fi
    printf '%s %s\n' "$today" "$run"
  } >"$tmp" && /bin/mv -f "$tmp" "$folder/admitted"

  write_last running "" "" "" "" "" "" || { die "$name: cannot write last.json"; return 74; }

  export ROUTINE_SUMMARY="$folder/summary.$run"
  sig_sent=""
  cmd_pid=""
  trap 'on_signal TERM' TERM
  trap 'on_signal HUP' HUP
  trap 'on_signal TERM' INT

  # The command's process: a subshell that waits for go.<run>, then execs.
  (
    trap - TERM HUP
    while [ ! -e "$folder/go.$run" ]; do
      [ "$(born_of "$$")" = "$self_born" ] || exit 0
      /bin/sleep 0.1
    done
    exec "$@"
  ) <&0 &
  cmd_pid=$!
  hold identity
  cmd_born=$(born_of "$cmd_pid")
  if [ -z "$cmd_born" ]; then
    kill -TERM "$cmd_pid" 2>/dev/null
    wait "$cmd_pid" 2>/dev/null
    finish 70 "" "$cmd_pid" "" ""
    return $?
  fi
  write_last running "$cmd_pid" "$cmd_born" "" "" "" "" || { kill -TERM "$cmd_pid" 2>/dev/null; wait "$cmd_pid" 2>/dev/null; die "$name: cannot write last.json"; return 74; }
  hold go
  : >"$folder/go.$run"
  hold after-go
  [ -z "$sig_sent" ] || kill -TERM "$cmd_pid" 2>/dev/null

  local st
  while :; do
    wait "$cmd_pid"
    st=$?
    kill -0 "$cmd_pid" 2>/dev/null || break
    [ "$st" != 127 ] || break
  done

  trap '' TERM HUP INT
  hold end
  finish "$st" "$sig_sent" "$cmd_pid" "$cmd_born" "$(read_summary)"
  return $?
}

# --- dispatch --------------------------------------------------------------

main() {
  local sub="${1:-}"
  [ "$#" -eq 0 ] || shift
  case "$sub" in
    run) cmd_run "$@" ;;
    adopt|release|status) die "$sub: not implemented"; return 2 ;;
    *) die "usage: routine.sh run <name> -- <command...>"; return 2 ;;
  esac
}

main "$@"
exit $?
