#!/bin/bash
# Routine run records, contract v1 (docs/routines.md).
#   routine.sh run <name> -- <command...>
#   routine.sh adopt <label> [--name <name>] [--cap <n>] | release <label> | status
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
MANIFEST_MAX_BYTES=8192
PLIST_MAX_BYTES=65536

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
# busy-prune, before-spawn, identity, go, after-go, waited, end.
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
  local dir="$folder/busy" stamp id drop f LC_ALL=C
  /bin/mkdir -p "$dir" 2>/dev/null || return 0
  stamp=$(/usr/bin/perl -MTime::HiRes=gettimeofday -e '($s, $u) = gettimeofday; printf "%010d%06d", $s, $u' 2>/dev/null)
  [ -n "$stamp" ] || stamp=$(/bin/date +%s)000000
  id="$stamp-$$-$RANDOM"
  printf '{"v":1,"name":"%s","kind":"skip","reason":"busy","time":"%s"}\n' "$name" "$(now_iso)" >"$dir/tmp.$id"
  hold busy
  /bin/mv -f "$dir/tmp.$id" "$dir/$id.json"
  set -- "$dir"/*.json
  hold busy-prune
  drop=$(($# - BUSY_KEEP))
  for f; do
    [ "$drop" -gt 0 ] || break
    /bin/rm -f "$f"
    drop=$((drop - 1))
  done
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
  wait_interrupted=1
  sig_sent="$1"
  if [ -n "$cmd_pid" ]; then
    kill -"$1" "$cmd_pid" 2>/dev/null
  else
    pending_signal="$1"
  fi
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
  local name="${1:-}" dir folder lock_st today cap cnt future d r tmp st wait_interrupted pending_signal=""
  if ! valid_name "$name"; then die "invalid routine name: $name"; return 2; fi
  shift
  if [ "${1:-}" != -- ] || [ "$#" -lt 2 ]; then die "usage: routine.sh run <name> -- <command...>"; return 2; fi
  shift
  [ "$name" != "$RESERVED_NAME" ] || { die "$name is reserved for its own writer"; return 2; }

  dir=$(routines_dir)
  folder="$dir/$name"
  if [ -f "$folder/routine.json" ]; then
    manifest_get "$folder/routine.json" --check-writer
    case $? in
      0) ;;
      2) die "$name has a native record writer; the wrapper does not touch it"; return 2 ;;
      *) die "$name: cannot read routine.json; nothing run"; return 74 ;;
    esac
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
  if ! (
    if [ -f "$folder/admitted" ]; then
      while IFS=' ' read -r d r || [ -n "$d" ]; do
        [ -n "$d" ] || continue
        if [[ "$d" > "$today" ]] || [ "$d" = "$today" ]; then printf '%s %s\n' "$d" "$r" || exit 1; fi
      done <"$folder/admitted" || exit 1
    fi
    printf '%s %s\n' "$today" "$run"
  ) >"$tmp" || [ -d "$folder/admitted" ] || ! mvp admitted "$tmp" "$folder/admitted"; then
    /bin/rm -f "$tmp"
    die "$name: cannot update admitted; nothing run"
    return 74
  fi

  write_last running "" "" "" "" "" "" || { die "$name: cannot write last.json"; return 74; }

  export ROUTINE_SUMMARY="$folder/summary.$run"
  sig_sent=""
  cmd_pid=""
  trap 'on_signal TERM' TERM
  trap 'on_signal HUP' HUP
  trap 'on_signal TERM' INT
  hold before-spawn

  # The command's process: a subshell that waits for go.<run>, then execs.
  (
    trap - TERM HUP
    while [ ! -f "$folder/go.$run" ]; do
      [ "$(born_of "$$")" = "$self_born" ] || exit 0
      /bin/sleep 0.1
    done
    exec "$@"
  ) <&0 &
  cmd_pid=$!
  if [ -n "$pending_signal" ]; then kill -"$pending_signal" "$cmd_pid" 2>/dev/null; fi
  hold identity
  cmd_born=$(born_of "$cmd_pid")
  if [ -z "$cmd_born" ]; then
    trap '' TERM HUP INT
    if [ -z "$sig_sent" ]; then
      kill -TERM "$cmd_pid" 2>/dev/null
      wait "$cmd_pid" 2>/dev/null
      st=70
    else
      wait "$cmd_pid" 2>/dev/null
      st=$?
    fi
    finish "$st" "$sig_sent" "$cmd_pid" "" ""
    return $?
  fi
  write_last running "$cmd_pid" "$cmd_born" "" "" "" "" || { kill -TERM "$cmd_pid" 2>/dev/null; wait "$cmd_pid" 2>/dev/null; die "$name: cannot write last.json"; return 74; }
  hold go
  if ! : >"$folder/go.$run"; then
    trap '' TERM HUP INT
    kill -TERM "$cmd_pid" 2>/dev/null
    wait "$cmd_pid" 2>/dev/null
    die "$name: cannot start the command; cannot create go.$run"
    finish 74 "$sig_sent" "$cmd_pid" "$cmd_born" ""
    return $?
  fi
  hold after-go

  while :; do
    wait_interrupted=0
    wait "$cmd_pid"
    st=$?
    hold waited
    [ "$wait_interrupted" = 1 ] || break
  done

  trap '' TERM HUP INT
  hold end
  finish "$st" "$sig_sent" "$cmd_pid" "$cmd_born" "$(read_summary)"
  return $?
}

# --- adoption --------------------------------------------------------------
#   routine.sh adopt <label> [--name <name>] [--cap <n>]
#   routine.sh release <label>
#   routine.sh status
# Exit codes of adopt and release: 0 done; 2 refused with nothing changed (bad
# call, reserved name, a plist outside the supported list, a job running or too
# near a slot, a name or label already bound); 1 failed (the job was put back,
# or a leftover is waiting for the next command, or the restore failed and
# adopt.failed says what to run); 75 another adopt or release holds the lock;
# 74 the lock or the folder cannot be set up.
# The launchd tools are called through ROUTINE_PLISTBUDDY, ROUTINE_PLUTIL and
# ROUTINE_LAUNCHCTL; ROUTINE_LAUNCHAGENTS_DIR, ROUTINE_UID and ROUTINE_TZ
# replace the LaunchAgents folder, the user id and the system time zone.

PB="${ROUTINE_PLISTBUDDY:-/usr/libexec/PlistBuddy}"
PLUTIL="${ROUTINE_PLUTIL:-/usr/bin/plutil}"
LCTL="${ROUTINE_LAUNCHCTL:-/bin/launchctl}"
CMP=/usr/bin/cmp
SLOTS=""
WHY=""
C_PHASE=""
C_CREATED=0
C_SWAP=0
C_PUB_ORIGIN=""
C_PUB_CAP=0

launch_dir() { printf '%s' "${ROUTINE_LAUNCHAGENTS_DIR:-$HOME/Library/LaunchAgents}"; }
user_id() { printf '%s' "${ROUTINE_UID:-$(/usr/bin/id -u)}"; }
new_id() { printf '%s-%s-%s' "$(/bin/date -u +%Y%m%dT%H%M%SZ)" "$$" "$RANDOM"; }

# Test failure points, read only when ROUTINE_TEST_FAIL is set: a comma list of
# mv:<point>, rm:<point>, stage-next and stage-manifest.
tf() { case ",${ROUTINE_TEST_FAIL:-}," in *",$1,"*) return 0 ;; esac; return 1; }
mvp() {
  tf "mv:$1" && return 1
  /bin/mv -f "$2" "$3" || return 1
  hold "moved-$1"
}
rmp() { tf "rm:$1" && return 1; /bin/rm -f "${2:?}"; }

manifest_get() {
  /usr/bin/perl -MJSON::PP -e '
    my ($path, $field, $limit, $reserved) = @ARGV;
    open my $file, "<", $path or exit 74;
    my $size = read $file, my $json, $limit + 1;
    exit 74 if !defined($size) || $size > $limit;
    my $manifest = eval { decode_json($json) };
    exit 74 unless ref($manifest) eq "HASH";
    if ($field eq "--check-writer") {
      exit 2 if ($manifest->{source} // "") eq "native" || ($manifest->{label} // "") eq $reserved;
      exit 0;
    }
    my $value = $manifest->{$field};
    print $value if defined($value) && !ref($value);
  ' "$1" "$2" "$MANIFEST_MAX_BYTES" "$RESERVED_LABEL"
}

# The path of this script, absolute, as it will be written in a plist.
self_path() {
  local d p
  case "$ROUTINE_SELF" in */*) d="${ROUTINE_SELF%/*}" ;; *) d=. ;; esac
  d=$(cd "$d" 2>/dev/null && pwd) || return 1
  p="$d/${ROUTINE_SELF##*/}"
  case "$p" in *\"*|*\'*|*\\*) return 1 ;; esac
  [ "$(printf '%s' "$p" | LC_ALL=C /usr/bin/tr -d '[:cntrl:]')" = "$p" ] || return 1
  printf '%s' "$p"
}

system_tz() {
  local t
  if [ -n "${ROUTINE_TZ:-}" ]; then t="$ROUTINE_TZ"
  else
    t=$(/usr/bin/readlink /etc/localtime 2>/dev/null) || return 1
    case "$t" in *zoneinfo/*) t="${t#*zoneinfo/}" ;; *) return 1 ;; esac
  fi
  case "$t" in ''|*[!A-Za-z0-9_+/-]*) return 1 ;; esac
  [ "${#t}" -le 64 ] || return 1
  printf '%s' "$t"
}

# Local weekday, hour and minute; ROUTINE_TEST_CLOCK is a file holding "W H M".
now_parts() {
  local line
  if [ -n "${ROUTINE_TEST_CLOCK:-}" ]; then
    read -r NOW_W NOW_H NOW_M <"$ROUTINE_TEST_CLOCK"
  else
    line=$(/bin/date +'%w %H %M')
    set -- $line
    NOW_W=$1; NOW_H=$((10#$2)); NOW_M=$((10#$3))
  fi
}

# 0 when a slot of $SLOTS comes less than $1 minutes from now (or is due now).
slot_within() {
  local wd h m delta nowmin
  now_parts
  nowmin=$((NOW_W * 1440 + NOW_H * 60 + NOW_M))
  while IFS=' ' read -r wd h m; do
    [ -n "$h" ] || continue
    if [ "$wd" = n ]; then
      delta=$(( ((h * 60 + m) - (NOW_H * 60 + NOW_M) + 1440) % 1440 ))
    else
      delta=$(( ((wd * 1440 + h * 60 + m) - nowmin + 10080) % 10080 ))
    fi
    [ "$delta" -lt "$1" ] && return 0
  done <<EOF
$SLOTS
EOF
  return 1
}

# --- plists ----------------------------------------------------------------

pb() { "$PB" -c "$1" "$2" 2>/dev/null; }

top_keys() { pb Print "$1" | /usr/bin/sed -n 's/^    \([^ ][^ ]*\) = .*$/\1/p'; }

# ProgramArguments of a plist into $PARGS, their number into $PARGC.
read_args() {
  local i=0 v
  PARGS=()
  while v=$(pb "Print :ProgramArguments:$i" "$1"); do
    PARGS[$i]="$v"
    i=$((i + 1))
    [ "$i" -lt 500 ] || break
  done
  PARGC=$i
}

# 0 when the plist starts with /bin/bash <...>/routine.sh run <name> --.
is_wrapped() {
  read_args "$1"
  [ "$PARGC" -ge 5 ] && [ "${PARGS[0]}" = /bin/bash ] && [ "${PARGS[2]}" = run ] \
    && [ "${PARGS[3]}" = "$2" ] && [ "${PARGS[4]}" = -- ] || return 1
  case "${PARGS[1]}" in */routine.sh) return 0 ;; esac
  return 1
}

is_int() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; [ "${#1}" -le 2 ]; }

# Fills $SLOTS ("<weekday or n> <hour> <minute>" per line, Weekday 7 stored as
# 0, equal entries merged) and returns 0; else sets $WHY and returns 1.
parse_slots() {
  local f="$1" kind n i path keys k h m wd hasw children line
  SLOTS=""
  kind=$(pb 'Print :StartCalendarInterval' "$f" | /usr/bin/sed -n '1p')
  case "$kind" in
    'Dict {') n=1 ;;
    'Array {')
      children=$(pb 'Print :StartCalendarInterval' "$f" | LC_ALL=C /usr/bin/grep -c '^    [^ }]')
      n=$(pb 'Print :StartCalendarInterval' "$f" | LC_ALL=C /usr/bin/grep -c '^    Dict {$')
      if [ "$children" != "$n" ]; then WHY="StartCalendarInterval holds an entry that is not a dictionary"; return 1; fi
      [ "$n" -gt 0 ] || { WHY="StartCalendarInterval is empty"; return 1; } ;;
    *) WHY="no StartCalendarInterval (only calendar schedules are supported)"; return 1 ;;
  esac
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "$kind" = 'Dict {' ]; then path=":StartCalendarInterval"; else path=":StartCalendarInterval:$i"; fi
    keys=$(pb "Print $path" "$f" | /usr/bin/sed -n 's/^    \([^ ][^ ]*\) = .*$/\1/p')
    hasw=0
    for k in $keys; do
      case "$k" in
        Hour|Minute) ;;
        Weekday) hasw=1 ;;
        *) WHY="StartCalendarInterval key $k is not supported (only Hour, Minute and Weekday)"; return 1 ;;
      esac
    done
    h=$(pb "Print $path:Hour" "$f"); m=$(pb "Print $path:Minute" "$f")
    if ! is_int "$h" || ! is_int "$m"; then WHY="a schedule entry needs an integer Hour and Minute"; return 1; fi
    h=$((10#$h)); m=$((10#$m))
    if [ "$h" -gt 23 ] || [ "$m" -gt 59 ]; then WHY="schedule entry $h:$m is out of range"; return 1; fi
    if [ "$hasw" = 1 ]; then
      wd=$(pb "Print $path:Weekday" "$f")
      if ! is_int "$wd" || [ "$((10#$wd))" -gt 7 ]; then WHY="Weekday must be an integer from 0 to 7"; return 1; fi
      wd=$((10#$wd)); [ "$wd" != 7 ] || wd=0
    else
      wd=n
    fi
    if [ "$h" -eq 1 ] || [ "$h" -eq 2 ]; then
      WHY="schedule entry $(printf '%02d:%02d' "$h" "$m") falls between 01:00 and 02:59 (a daylight-saving change can skip or repeat it)"
      return 1
    fi
    line="$wd $h $m"
    case "
$SLOTS
" in
      *"
$line
"*) ;;
      *) SLOTS="${SLOTS:+$SLOTS
}$line" ;;
    esac
    i=$((i + 1))
  done
  return 0
}

slots_json() {
  local out="" wd h m
  while IFS=' ' read -r wd h m; do
    [ -n "$h" ] || continue
    [ "$wd" != n ] || wd=null
    out="${out:+$out,}{\"weekday\":$wd,\"hour\":$h,\"minute\":$m}"
  done <<EOF
$SLOTS
EOF
  printf '[%s]' "$out"
}

# Most slots on one day, plus two.
default_cap() {
  local d best=0 c wd h m
  for d in 0 1 2 3 4 5 6; do
    c=0
    while IFS=' ' read -r wd h m; do
      [ -n "$h" ] || continue
      if [ "$wd" = n ] || [ "$wd" = "$d" ]; then c=$((c + 1)); fi
    done <<EOF
$SLOTS
EOF
    [ "$c" -le "$best" ] || best=$c
  done
  printf '%s' "$((best + 2))"
}

# 0 when the plist is within the supported list; else $WHY says what is not.
validate_plist() { # file label
  local f="$1" label="$2" keys k bad="" v
  WHY=""
  [ -f "$f" ] || { WHY="no plist at $f"; return 1; }
  "$PLUTIL" -lint "$f" >/dev/null 2>&1 || { WHY="$f is not a valid property list"; return 1; }
  keys=$(top_keys "$f")
  [ -n "$keys" ] || { WHY="cannot read the keys of $f"; return 1; }
  for k in $keys; do
    case " Label ProgramArguments StartCalendarInterval StandardOutPath StandardErrorPath EnvironmentVariables RunAtLoad Nice LowPriorityIO " in
      *" $k "*) ;;
      *) bad="${bad:+$bad }$k" ;;
    esac
  done
  [ -z "$bad" ] || { WHY="unsupported key: $bad"; return 1; }
  v=$(pb 'Print :Label' "$f")
  [ "$v" = "$label" ] || { WHY="Label is '$v', not '$label'"; return 1; }
  pb 'Print :ProgramArguments:0' "$f" >/dev/null || { WHY="no ProgramArguments"; return 1; }
  if printf '%s\n' "$keys" | /usr/bin/grep -qx RunAtLoad; then
    v=$(pb 'Print :RunAtLoad' "$f")
    [ "$v" = false ] || { WHY="RunAtLoad $v is not supported (only false)"; return 1; }
  fi
  parse_slots "$f"
}

# dst = src with the wrapper in front of ProgramArguments, linted and read back.
make_wrapped() { # src dst name
  local src="$1" dst="$2" name="$3" sp="$SELF" before after
  read_args "$src"; before=$PARGC
  case "$sp" in *' '*) sp="\"$sp\"" ;; esac
  /bin/cp "$src" "$dst" || return 1
  pb "Add :ProgramArguments:0 string --" "$dst" >/dev/null || return 1
  pb "Add :ProgramArguments:0 string $name" "$dst" >/dev/null || return 1
  pb "Add :ProgramArguments:0 string run" "$dst" >/dev/null || return 1
  pb "Add :ProgramArguments:0 string $sp" "$dst" >/dev/null || return 1
  pb "Add :ProgramArguments:0 string /bin/bash" "$dst" >/dev/null || return 1
  "$PLUTIL" -lint "$dst" >/dev/null 2>&1 || return 1
  read_args "$dst"; after=$PARGC
  [ "$after" = "$((before + 5))" ] || return 1
  [ "${PARGS[0]}" = /bin/bash ] && [ "${PARGS[1]}" = "$SELF" ] && [ "${PARGS[2]}" = run ] \
    && [ "${PARGS[3]}" = "$name" ] && [ "${PARGS[4]}" = -- ]
}

# --- launchd ---------------------------------------------------------------

# $JOB_LOADED and $JOB_RUNNING from one `launchctl print`. Anything but
# "state = not running" counts as running.
job_state() {
  local state
  JOB_LOADED=0; JOB_RUNNING=0; JOB_OUT=""
  JOB_OUT=$("$LCTL" print "gui/$(user_id)/$1" 2>/dev/null) || return 1
  JOB_LOADED=1
  state=$(printf '%s\n' "$JOB_OUT" | /usr/bin/grep -m 1 $'^\tstate = ')
  [ "$state" = $'\tstate = not running' ] || JOB_RUNNING=1
  return 0
}

# Writes <src> over the label's plist through a temporary name in its folder.
install_plist() { # src label [failure point]
  local dst tmp
  dst="$(launch_dir)/$2.plist"
  tmp="$(launch_dir)/.$2.plist.routine.$$"
  /bin/cp "$1" "$tmp" || return 1
  if [ -n "${3:-}" ]; then
    mvp "$3" "$tmp" "$dst" || { /bin/rm -f "${tmp:?}"; return 1; }
  else
    /bin/mv -f "$tmp" "$dst" || { /bin/rm -f "${tmp:?}"; return 1; }
  fi
}

# Restores and verifies <prev>. Returns 2 when a running job prevents restoration.
restore_prev() { # label prev
  local label="$1" prev="$2" dst
  dst="$(launch_dir)/$label.plist"
  job_state "$label"
  if [ "$JOB_LOADED" = 1 ] && $CMP -s "$prev" "$dst"; then return 0; fi
  [ "$JOB_RUNNING" = 0 ] || return 2
  if [ "$JOB_LOADED" = 1 ]; then "$LCTL" bootout "gui/$(user_id)/$label" >/dev/null 2>&1 || return 1; fi
  install_plist "$prev" "$label" || return 1
  "$LCTL" bootstrap "gui/$(user_id)" "$dst" >/dev/null 2>&1 || return 1
  job_state "$label"
  [ "$JOB_LOADED" = 1 ] && $CMP -s "$prev" "$dst" || return 1
}

# --- the lock of adopt and release -----------------------------------------

# The Perl lock line on a scratch file: 0 when it works here.
lock_selfcheck() {
  local s st
  s=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/routine-lock.XXXXXX") || return 74
  exec 9>"$s/probe"
  routine_lock_try
  st=$?
  exec 9>&-
  /bin/rm -rf "${s:?}"
  return "$st"
}

# The kernel lock on adopt.lock, then the settling of every incomplete folder.
# Sets $dir.
begin_command() {
  local st
  dir=$(routines_dir)
  lock_selfcheck
  st=$?
  if [ "$st" != 0 ]; then die "the lock check failed (status $st); nothing changed"; return 74; fi
  /bin/mkdir -p "$dir" 2>/dev/null || { die "cannot create $dir"; return 74; }
  ( : >>"$dir/adopt.lock" ) 2>/dev/null || { die "cannot open $dir/adopt.lock"; return 74; }
  exec 9>>"$dir/adopt.lock"
  routine_lock_try
  st=$?
  if [ "$st" = 75 ]; then die "another adopt or release is running"; return 75; fi
  [ "$st" = 0 ] || { die "cannot take $dir/adopt.lock (status $st)"; return 74; }
  settle_all
}

# --- cleanup, restore, settling ----------------------------------------------

clean_stage() { /bin/rm -f "${1:?}"/*.next "${1:?}/plist.next"; }

save_prev() {
  /bin/cp "$1" "$2/plist.prev.next" || return 1
  hold backup-copied
  /bin/mv -f "$2/plist.prev.next" "$2/plist.prev"
}

# The two commands to run by hand when a plist cannot be put back.
leave_failed() { # folder label prev
  local f="${1:?}/adopt.failed" dst
  dst="$(launch_dir)/$2.plist"
  {
    printf '%s: the job %s could not be put back. Run:\n' "$C_KIND" "$2"
    printf "/bin/cp '%s' '%s'\n" "$3" "$dst"
    printf "%s bootstrap gui/%s '%s'\n" "$LCTL" "$(user_id)" "$dst"
  } >"$f" 2>/dev/null
  /bin/cat "$f" >&2 2>/dev/null
  return 0
}

abort_files() {
  clean_stage "$C_FOLDER"
  /bin/rm -f "${C_FOLDER:?}/plist.prev" "${C_FOLDER:?}/pending"
  [ "$C_CREATED" = 0 ] || /bin/rmdir "$C_FOLDER" 2>/dev/null
  return 0
}

undo_published() {
  if [ -n "$C_PUB_ORIGIN" ] && [ ! -e "$C_FOLDER/$C_PUB_ORIGIN.next" ]; then
    /bin/rm -f "${C_FOLDER:?}/${C_PUB_ORIGIN:?}"
  fi
  if [ "$C_PUB_CAP" = 1 ] && [ ! -e "$C_FOLDER/cap.next" ]; then
    /bin/rm -f "${C_FOLDER:?}/cap"
  fi
  return 0
}

# Staging or last-check failure: nothing was replaced.
stage_fail() { die "$C_KIND $C_LABEL: $1; nothing changed"; abort_files; return 0; }

# A failure after the swap began (or at the commit): back to plist.prev.
rollback() {
  local restore_status
  C_PHASE=rollback
  trap '' TERM INT HUP
  die "$C_KIND $C_LABEL failed: $1"
  if [ "$C_SWAP" = 1 ]; then
    restore_prev "$C_LABEL" "$C_FOLDER/plist.prev"
    restore_status=$?
    case "$restore_status" in
      0) ;;
      2)
        undo_published
        die "$C_LABEL is running; rollback will resume on the next command"
        return 1
        ;;
      *) leave_failed "$C_FOLDER" "$C_LABEL" "$C_FOLDER/plist.prev"; return 1 ;;
    esac
  fi
  undo_published
  abort_files
  return 1
}

on_cmd_signal() {
  trap '' TERM INT HUP
  case "$C_PHASE" in
    staging) abort_files ;;
    swap) rollback "signal" ;;
  esac
  exit "$1"
}

settle_folder() { # folder
  local f="$1" kind="" id="" committed=0 label dst prev="$1/plist.prev" name="${1##*/}" restore_status
  if [ -f "$f/pending" ]; then { IFS= read -r kind; IFS= read -r id; } <"$f/pending"; fi
  case "$kind" in
    adopt) [ -n "$id" ] && [ -f "$f/routine.json" ] && [ "$(manifest_get "$f/routine.json" command)" = "$id" ] && committed=1 ;;
    release) [ ! -e "$f/routine.json" ] && committed=1 ;;
  esac
  C_KIND="${kind:-adopt}"
  if [ -f "$prev" ] && [ "$committed" = 0 ]; then
    label=$(pb 'Print :Label' "$prev")
    [ -n "$label" ] || label=$(manifest_get "$f/routine.json" label)
    if [ -z "$label" ]; then die "$name: incomplete, and the label of plist.prev cannot be read"; return 1; fi
    dst="$(launch_dir)/$label.plist"
    job_state "$label"
    if [ "$JOB_LOADED" = 1 ] && $CMP -s "$prev" "$dst"; then
      :
    else
      if [ "$JOB_LOADED" = 1 ]; then
        # Going back needs a bootout: the guard of every swap.
        if [ "$JOB_RUNNING" = 1 ]; then die "$name: incomplete, and its job is running; nothing changed"; return 2; fi
        if ! parse_slots "$prev" || slot_within 10; then die "$name: incomplete, and a slot of its job is near; nothing changed"; return 2; fi
      fi
      restore_prev "$label" "$prev"
      restore_status=$?
      if [ "$restore_status" = 2 ]; then
        die "$name: incomplete, and its job is running; nothing changed"
        return 2
      elif [ "$restore_status" != 0 ]; then
        die "$name: incomplete, and the job could not be put back"
        leave_failed "$f" "$label" "$prev"
        return 1
      fi
    fi
  fi
  clean_stage "$f" || return 1
  if [ "$committed" = 1 ] && [ "$kind" = adopt ]; then
    rmp released "${f:?}/routine.released.json" || return 1
  fi
  rmp prev "$prev" || return 1
  /bin/rm -f "${f:?}/adopt.failed" || return 1
  rmp pending "$f/pending" || return 1
  /bin/rmdir "$f" 2>/dev/null || true
}

settle_all() {
  local d rc
  for d in "$dir"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    if [ -e "$d/plist.prev" ] || [ -e "$d/pending" ]; then
      settle_folder "$d"
      rc=$?
      [ "$rc" = 0 ] || return "$rc"
    fi
  done
  return 0
}

# --- adopt and release -------------------------------------------------------

# Label of the manifest of a folder, current first, then released.
folder_label() {
  local m
  for m in routine.json routine.released.json; do
    if [ -f "$1/$m" ]; then manifest_get "$1/$m" label; return 0; fi
  done
  return 0
}

has_manifest() { [ -f "$1/routine.json" ] || [ -f "$1/routine.released.json" ]; }

usage_adopt() { die "usage: routine.sh adopt <label> [--name <name>] [--cap <n>]"; }

cmd_adopt() {
  local label="" name="" cap=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --name) [ "$#" -ge 2 ] || { usage_adopt; return 2; }; name="$2"; shift 2 ;;
      --cap) [ "$#" -ge 2 ] || { usage_adopt; return 2; }; cap="$2"; shift 2 ;;
      -*) usage_adopt; return 2 ;;
      *) [ -z "$label" ] || { usage_adopt; return 2; }; label="$1"; shift ;;
    esac
  done
  case "$label" in ''|*[!A-Za-z0-9._-]*) usage_adopt; return 2 ;; esac
  [ "${#label}" -le 200 ] || { die "label exceeds 200 characters"; return 2; }
  if [ "$label" = "$RESERVED_LABEL" ] || [ "$name" = "$RESERVED_NAME" ]; then
    die "$RESERVED_NAME and $RESERVED_LABEL are reserved for their own writer"
    return 2
  fi
  [ -n "$name" ] || name="${label##*.}"
  if ! valid_name "$name"; then die "invalid routine name '$name' (use --name; [a-z0-9-], 40 at most)"; return 2; fi
  [ "$name" != "$RESERVED_NAME" ] || { die "$RESERVED_NAME is reserved for its own writer"; return 2; }
  case "$cap" in
    '') ;;
    *[!0-9]*|0|0[0-9]*) die "--cap needs a positive integer"; return 2 ;;
  esac
  C_KIND=adopt; C_LABEL="$label"; C_NAME="$name"
  begin_command || return $?
  C_KIND=adopt
  do_adopt "$cap"
}

do_adopt() {
  local want_cap="$1" folder plist d bound cur src mode tzv origin_name adopted manifest_bytes wrapped_plist plist_bytes
  SELF=$(self_path) || { die "cannot use the path of routine.sh (quotes, backslashes or control characters)"; return 2; }
  tzv=$(system_tz) || { die "cannot read the system time zone (set ROUTINE_TZ)"; return 2; }
  plist="$(launch_dir)/$C_LABEL.plist"
  folder="$dir/$C_NAME"
  C_FOLDER="$folder"

  # One name for one label, one label for one name.
  if has_manifest "$folder"; then
    bound=$(folder_label "$folder")
    if [ "$bound" != "$C_LABEL" ]; then die "refused: the name $C_NAME is bound to the label '${bound:-?}'"; return 2; fi
    for cur in routine.json routine.released.json; do [ -f "$folder/$cur" ] && break; done
    src=$(manifest_get "$folder/$cur" source)
    if [ "$src" != adopt ]; then die "refused: $C_NAME belongs to '$src', not to adopt"; return 2; fi
  fi
  for d in "$dir"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    [ "$d" != "$folder" ] || continue
    if has_manifest "$d" && [ "$(folder_label "$d")" = "$C_LABEL" ]; then
      die "refused: the label $C_LABEL is already bound to the name ${d##*/}"
      return 2
    fi
  done

  validate_plist "$plist" "$C_LABEL" || { die "refused: $C_LABEL: $WHY"; return 2; }

  mode=new
  if [ -f "$folder/routine.json" ]; then
    if is_wrapped "$plist" "$C_NAME"; then mode=refresh; else mode=readopt; fi
  fi
  if [ "$mode" != refresh ]; then
    job_state "$C_LABEL"
    [ "$JOB_LOADED" = 1 ] || { die "refused: $C_LABEL is not loaded"; return 2; }
    [ "$JOB_RUNNING" = 0 ] || { die "refused: $C_LABEL is running"; return 2; }
    if slot_within 10; then die "refused: a slot of $C_LABEL comes in less than 10 minutes"; return 2; fi
  fi

  C_ID=$(new_id)
  if [ ! -d "$folder" ]; then
    /bin/mkdir "$folder" 2>/dev/null || { die "cannot create $folder"; return 74; }
    C_CREATED=1
  fi
  C_PHASE=staging
  trap 'on_cmd_signal 143' TERM
  trap 'on_cmd_signal 130' INT
  trap 'on_cmd_signal 129' HUP

  printf 'adopt\n%s\n' "$C_ID" >"$folder/pending" || { stage_fail "cannot write pending"; return 1; }
  if [ "$mode" != refresh ]; then
    save_prev "$plist" "$folder" || { stage_fail "cannot save the plist"; return 1; }
  fi
  hold staging
  wrapped_plist="$plist"
  if [ "$mode" != refresh ]; then
    origin_name="plist.before.$C_ID"
    /bin/cp "$folder/plist.prev" "$folder/$origin_name.next" || { stage_fail "cannot save the origin"; return 1; }
    if tf stage-next || ! make_wrapped "$folder/plist.prev" "$folder/plist.next" "$C_NAME"; then
      stage_fail "cannot write the wrapped plist"; return 1
    fi
    wrapped_plist="$folder/plist.next"
  else
    origin_name=$(manifest_get "$folder/routine.json" origin)
  fi
  plist_bytes=$(/usr/bin/wc -c <"$wrapped_plist") || { stage_fail "cannot size the wrapped plist"; return 1; }
  if [ "$plist_bytes" -gt "$PLIST_MAX_BYTES" ]; then
    stage_fail "wrapped plist exceeds $PLIST_MAX_BYTES bytes"; return 2
  fi
  adopted=""
  if [ "$mode" != new ]; then adopted=$(manifest_get "$folder/routine.json" adopted); fi
  [ -n "$adopted" ] || adopted=$(now_iso)
  if tf stage-manifest || ! printf '{"v":1,"name":"%s","label":"%s","tz":"%s","slots":%s,"adopted":"%s","source":"adopt","origin":"%s","command":"%s"}\n' \
      "$C_NAME" "$C_LABEL" "$tzv" "$(slots_json)" "$adopted" "$origin_name" "$C_ID" >"$folder/routine.json.next"; then
    stage_fail "cannot write the manifest"; return 1
  fi
  manifest_bytes=$(/usr/bin/wc -c <"$folder/routine.json.next") || { stage_fail "cannot size the manifest"; return 1; }
  if [ "$manifest_bytes" -gt "$MANIFEST_MAX_BYTES" ]; then
    stage_fail "manifest exceeds $MANIFEST_MAX_BYTES bytes"; return 2
  fi
  if [ ! -f "$folder/cap" ]; then
    [ -n "$want_cap" ] || want_cap=$(default_cap)
    printf '%s\n' "$want_cap" >"$folder/cap.next" || { stage_fail "cannot write the cap"; return 1; }
  fi
  hold staged

  if [ "$mode" != refresh ]; then
    swap_job "$folder/plist.next" wrapper || return $?
  fi
  publish_and_commit "$origin_name" || return $?
  printf 'adopted %s as %s (%s)\n' "$C_LABEL" "$C_NAME" "$mode"
  return 0
}

# The last check, then bootout, the new plist, bootstrap, verification. On
# failure everything is back (rollback) and the return value is non-zero.
swap_job() { # new plist, what to verify (wrapper|origin)
  local new="$1" want="$2" label="$C_LABEL" uid dst
  uid=$(user_id)
  dst="$(launch_dir)/$label.plist"
  job_state "$label"
  if [ "$JOB_LOADED" != 1 ]; then stage_fail "the job is no longer loaded"; return 2; fi
  if [ "$JOB_RUNNING" = 1 ]; then stage_fail "the job is running"; return 2; fi
  if slot_within 5; then stage_fail "a slot comes in less than 5 minutes"; return 2; fi
  C_PHASE=swap
  C_SWAP=1
  "$LCTL" bootout "gui/$uid/$label" >/dev/null 2>&1 || { rollback "bootout failed"; return 1; }
  hold unloaded
  install_plist "$new" "$label" swap || { rollback "cannot write the plist"; return 1; }
  "$LCTL" bootstrap "gui/$uid" "$dst" >/dev/null 2>&1 || { rollback "bootstrap failed"; return 1; }
  job_state "$label"
  if [ "$JOB_LOADED" != 1 ]; then rollback "the job is not loaded after bootstrap"; return 1; fi
  if [ "$want" = wrapper ]; then
    case "$JOB_OUT" in *"$SELF"*) ;; *) rollback "the job does not run the wrapper"; return 1 ;; esac
  else
    $CMP -s "$new" "$dst" || { rollback "the plist in place is not the origin"; return 1; }
  fi
  return 0
}

# Publishing (adopt), the commit, then the deletions.
publish_and_commit() { # origin name (adopt)
  local f="$C_FOLDER"
  if [ "$C_KIND" = adopt ]; then
    if [ -e "$f/$1.next" ]; then
      C_PUB_ORIGIN="$1"
      mvp origin "$f/$1.next" "$f/$1" || { rollback "cannot publish the origin"; return 1; }
    fi
    if [ -e "$f/cap.next" ]; then
      C_PUB_CAP=1
      mvp cap "$f/cap.next" "$f/cap" || { rollback "cannot publish the cap"; return 1; }
    fi
  fi
  hold verified
  trap '' TERM INT HUP
  C_PHASE=commit
  if [ "$C_KIND" = adopt ]; then
    mvp commit "$f/routine.json.next" "$f/routine.json" || { rollback "cannot commit the manifest"; return 1; }
  else
    mvp commit "$f/routine.json" "$f/routine.released.json" || { rollback "cannot commit the manifest"; return 1; }
  fi
  hold committed
  C_PHASE=post
  clean_stage "$f" || { die "$C_KIND $C_LABEL is done; a leftover stays for the next command"; return 1; }
  if [ "$C_KIND" = adopt ] && [ -e "$f/routine.released.json" ]; then
    rmp released "$f/routine.released.json" || { die "$C_KIND $C_LABEL is done; a leftover stays for the next command"; return 1; }
  fi
  rmp prev "$f/plist.prev" || { die "$C_KIND $C_LABEL is done; a leftover stays for the next command"; return 1; }
  hold prev-deleted
  rmp pending "$f/pending" || { die "$C_KIND $C_LABEL is done; a leftover stays for the next command"; return 1; }
  return 0
}

cmd_release() {
  local label="${1:-}"
  if [ "$#" -ne 1 ]; then die "usage: routine.sh release <label>"; return 2; fi
  case "$label" in ''|*[!A-Za-z0-9._-]*) die "usage: routine.sh release <label>"; return 2 ;; esac
  if [ "$label" = "$RESERVED_LABEL" ] || [ "$label" = "$RESERVED_NAME" ]; then
    die "$RESERVED_NAME and $RESERVED_LABEL are reserved for their own writer"
    return 2
  fi
  C_KIND=release; C_LABEL="$label"
  begin_command || return $?
  C_KIND=release
  do_release
}

do_release() {
  local folder="" d origin plist src
  SELF=$(self_path) || SELF=""
  plist="$(launch_dir)/$C_LABEL.plist"
  for d in "$dir"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    if [ -f "$d/routine.json" ] && [ "$(manifest_get "$d/routine.json" label)" = "$C_LABEL" ]; then folder="$d"; break; fi
  done
  if [ -z "$folder" ]; then die "refused: no adopted routine has the label $C_LABEL"; return 2; fi
  C_FOLDER="$folder"; C_NAME="${folder##*/}"
  src=$(manifest_get "$folder/routine.json" source)
  if [ "$src" != adopt ]; then die "refused: $C_NAME belongs to '$src', not to adopt"; return 2; fi
  origin=$(manifest_get "$folder/routine.json" origin)
  case "$origin" in plist.before.*) ;; *) die "refused: the manifest of $C_NAME names no saved plist"; return 2 ;; esac
  case "$origin" in */*) die "refused: the manifest of $C_NAME names no saved plist"; return 2 ;; esac
  [ -f "$folder/$origin" ] || { die "refused: the saved plist $origin of $C_NAME is gone"; return 2; }
  [ -f "$plist" ] || { die "refused: no plist at $plist"; return 2; }
  if ! is_wrapped "$plist" "$C_NAME"; then die "refused: $C_NAME is unwrapped (the plist lost the wrapper); run adopt $C_LABEL again first, so the hand-written plist becomes the new origin"; return 2; fi
  parse_slots "$plist" || { die "refused: $C_LABEL: $WHY"; return 2; }
  job_state "$C_LABEL"
  [ "$JOB_LOADED" = 1 ] || { die "refused: $C_LABEL is not loaded"; return 2; }
  [ "$JOB_RUNNING" = 0 ] || { die "refused: $C_LABEL is running"; return 2; }
  if slot_within 10; then die "refused: a slot of $C_LABEL comes in less than 10 minutes"; return 2; fi

  C_ID=$(new_id)
  C_PHASE=staging
  trap 'on_cmd_signal 143' TERM
  trap 'on_cmd_signal 130' INT
  trap 'on_cmd_signal 129' HUP
  printf 'release\n%s\n' "$C_ID" >"$folder/pending" || { stage_fail "cannot write pending"; return 1; }
  save_prev "$plist" "$folder" || { stage_fail "cannot save the plist"; return 1; }
  hold staging
  if tf stage-next || ! /bin/cp "$folder/$origin" "$folder/plist.next"; then stage_fail "cannot stage the origin"; return 1; fi
  hold staged
  swap_job "$folder/plist.next" origin || return $?
  publish_and_commit "" || return $?
  printf 'released %s (%s)\n' "$C_LABEL" "$C_NAME"
  return 0
}

# --- status ------------------------------------------------------------------

status_line() { # folder
  local d="$1" name="${1##*/}" cur="" label state detail="" kind="" plist
  if [ -f "$d/routine.json" ]; then cur=routine.json
  elif [ -f "$d/routine.released.json" ]; then cur=routine.released.json; fi
  label=""
  [ -z "$cur" ] || label=$(manifest_get "$d/$cur" label)
  if [ -e "$d/plist.prev" ] || [ -e "$d/pending" ] || [ -e "$d/adopt.failed" ]; then
    [ ! -f "$d/pending" ] || { IFS= read -r kind; } <"$d/pending"
    if [ -f "$d/plist.prev" ]; then
      label=$(pb 'Print :Label' "$d/plist.prev")
    fi
    if [ -e "$d/adopt.failed" ]; then state=broken; else state=incomplete; fi
    detail="${kind:-unknown command}"
    if [ -n "$label" ]; then
      job_state "$label"
      [ "$JOB_LOADED" = 1 ] || detail="$detail, job not loaded"
    fi
  elif [ "$cur" = routine.json ]; then
    if [ "$(manifest_get "$d/$cur" source)" = native ]; then
      state=native
    else
      plist="$(launch_dir)/$label.plist"
      if [ ! -f "$plist" ]; then state=unwrapped; detail="plist missing"
      elif is_wrapped "$plist" "$name"; then
        state=adopted
        job_state "$label"
        if [ "$JOB_LOADED" != 1 ]; then detail="not loaded"
        elif [ "$JOB_RUNNING" = 1 ]; then detail="running"
        else detail="loaded"; fi
      else
        state=unwrapped; detail="the plist lost the wrapper; adopt it again"
      fi
    fi
  elif [ "$cur" = routine.released.json ]; then
    state=released
  else
    return 0
  fi
  printf '%s %s %s%s\n' "$name" "$state" "${label:-?}" "${detail:+ ($detail)}"
}

cmd_status() {
  local d st
  dir=$(routines_dir)
  C_KIND=status
  for d in "$dir"/*/; do
    [ -d "$d" ] || continue
    status_line "${d%/}"
  done
  lock_selfcheck
  st=$?
  if [ "$st" = 0 ]; then
    printf 'lock: ok\n'
  else
    printf 'lock: failing (the Perl flock line exits %s: no routine can run)\n' "$st"
    return 74
  fi
}

# --- dispatch --------------------------------------------------------------

main() {
  local sub="${1:-}"
  [ "$#" -eq 0 ] || shift
  case "$sub" in
    run) cmd_run "$@" ;;
    adopt) cmd_adopt "$@" ;;
    release) cmd_release "$@" ;;
    status) cmd_status "$@" ;;
    *) die "usage: routine.sh run|adopt|release|status ..."; return 2 ;;
  esac
}

main "$@"
exit $?
