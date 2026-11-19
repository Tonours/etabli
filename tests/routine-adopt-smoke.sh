#!/usr/bin/env bash
# Routine adoption: `routine.sh adopt | release | status` (docs/routines.md).
# Runs under Linux bash and macOS /bin/bash 3.2 with a fake PlistBuddy, plutil
# and launchctl: nothing here touches a real LaunchAgents folder or job.
# ROUTINE_ADOPT_REAL_PLIST=1 (macOS only) uses the real PlistBuddy and plutil
# on copies of the fixtures in a temporary folder; launchctl stays fake.
#
# The fake launchctl keeps loaded plists as files under $FAKE_LCTL_DIR. Tests set
#   FAKE_LCTL_FAIL="verb:n verb:*"   fail the nth call of a verb (or all of them)
#   FAKE_LCTL_HOLD=bootout:<file>    wait inside that verb until the file exists
#   FAKE_LCTL_RUN_FROM=n             report running from the nth print of a label
# and touch $FAKE_LCTL_DIR/running/<label> to make a job run. The script's own
# test points: ROUTINE_TEST_HOLD (staging, staged, unloaded, verified, committed,
# prev-deleted), ROUTINE_TEST_FAIL (mv:swap, mv:origin, mv:cap, mv:commit,
# rm:released, rm:prev, rm:pending, stage-next, stage-manifest) and
# ROUTINE_TEST_CLOCK (a file holding "weekday hour minute").
# core_snap lists a folder without cap and plist.before.*: a killed command can
# leave a cap (the default the routine would get anyway) and an origin file
# (named by no manifest, read by nothing).
#
# Test -> the mutation it must catch
#   adopt_release_roundtrip ............... lose a key; regenerate the origin instead of copying it
#   unwrapped_readopt_keeps_both_origins .. go back to P0, lose it, or leave P1 as the origin on failure
#   kill_in_bootout_holds_the_lock ........ a lock tied to the shell's pid (settling beside a live launchctl)
#   refused_before_the_swap ............... stage under the final names; bootout before the last check
#   release_refused_at_the_last_check ..... boot out a job seen running
#   mv_failures_at_each_rename ............ leave a half-published folder; delete plist.prev before the commit
#   kill_matrix_adopt / _release .......... leave the job unloaded; read a .next file as the manifest; go
#                                           back from a committed command; decide from a marker written
#                                           after the fact; take any current manifest for the commit
#                                           (caught at `unloaded` from an unwrapped start)
#   kill_then_the_other_command ........... settle only for the same command
#   kill_after_commit_then_unloaded ....... read the commit from the loaded job
#   rm_failures_after_commit .............. go back after the commit; show pending alone as settled
#   running_job_is_not_stopped_by_settling  boot out a running job; no margin in the settling
#   three_commands_after_a_kill ........... settle twice
#   reserved_names_refused ................ check the folder only (accepted while it is empty)
#   adopt_release_adopt_by_hand ........... keep only the folder's first origin; leave the new origin on failure
#   adopt_twice_wraps_once ................ double prefix
#   name_and_label_binding ................ share the folder; check current manifests only
#   slot_margins .......................... check the margin once; no margin
#   running_at_the_second_read ............ boot out a job seen running at the last check
#   concurrent_adopts_one_wins ............ check then write without a lock
#   running_or_unloaded_refused ........... reload it
#   plists_outside_the_list_refused ....... accept (AC-9 cases and the fleet-improvement fixture)
#   schedule_shapes_and_cap ............... keep the first, keep 7, keep both; count entries not days
#   failures_restore ...................... leave the job unloaded
#   failed_restore_is_broken .............. delete the backup
#   status_states ......................... show an unwrapped, incomplete or broken folder as fine
#   lock_check_refuses .................... skip the Perl check
#   release_needs_a_saved_plist ........... delete the manifest
#   release_refuses_unwrapped ............. release restores the origin and the hand-written plist is lost
#   tz_from_the_system .................... ignore /etc/localtime
#   bash32_and_no_jq ...................... associative arrays, BASHPID, jq in the script
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$ROOT_DIR/claude/scopes/work/scripts/routine/routine.sh"
FIXT="$ROOT_DIR/tests/fixtures/routine"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/routine-adopt.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home"
mkdir -p "$HOME"
BIN="$TMP_DIR/bin"
mkdir -p "$BIN"
unset ETABLI_ROUTINES_DIR ROUTINE_TEST_PERL ROUTINE_TEST_HOLD ROUTINE_TEST_PS ROUTINE_TEST_FAIL ROUTINE_TEST_CLOCK \
  FAKE_LCTL_FAIL FAKE_LCTL_HOLD FAKE_LCTL_RUN_FROM

cat >"$BIN/plistfake.pl" <<'EOF'
use strict; use warnings;
my $mode = shift @ARGV;
sub slurp { my $f = shift; open(my $h, '<', $f) or return undef; local $/; my $c = <$h>; close $h; return $c; }
sub unesc { my $s = shift; $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&apos;/'/g; $s =~ s/&amp;/&/g; return $s; }
sub esc { my $s = shift; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; return $s; }
sub parse_node {
  my $r = shift;
  $$r =~ s/^\s+//;
  if ($$r =~ s{^<dict>}{}) {
    my @e;
    while (1) {
      $$r =~ s/^\s+//;
      last if $$r =~ s{^</dict>}{};
      $$r =~ s{^<key>(.*?)</key>}{}s or die "bad dict\n";
      my $k = unesc($1);
      push @e, [$k, parse_node($r)];
    }
    return ['dict', \@e];
  }
  return ['dict', []] if $$r =~ s{^<dict/>}{};
  if ($$r =~ s{^<array>}{}) {
    my @a;
    while (1) { $$r =~ s/^\s+//; last if $$r =~ s{^</array>}{}; push @a, parse_node($r); }
    return ['array', \@a];
  }
  return ['array', []] if $$r =~ s{^<array/>}{};
  return [$1, unesc($2)] if $$r =~ s{^<(string|integer)>(.*?)</\1>}{}s;
  return ['string', ''] if $$r =~ s{^<string/>}{};
  return ['bool', $1] if $$r =~ s{^<(true|false)/>}{};
  die "unsupported element\n";
}
sub load_plist {
  my $x = slurp($_[0]);
  defined $x or die "cannot read $_[0]\n";
  $x =~ s/<\?xml.*?\?>//s; $x =~ s/<!DOCTYPE.*?>//s;
  $x =~ m{<plist[^>]*>(.*)</plist>}s or die "not a plist\n";
  my $b = $1;
  my $n = parse_node(\$b);
  $b =~ s/^\s+//;
  die "trailing data\n" if length $b;
  return $n;
}
sub emit {
  my ($n, $ind) = @_;
  my $t = "\t" x $ind; my $k = $n->[0];
  if ($k eq 'dict') {
    return "$t<dict/>\n" unless @{$n->[1]};
    my $o = "$t<dict>\n";
    $o .= "$t\t<key>" . esc($_->[0]) . "</key>\n" . emit($_->[1], $ind + 1) for @{$n->[1]};
    return $o . "$t</dict>\n";
  }
  if ($k eq 'array') {
    return "$t<array/>\n" unless @{$n->[1]};
    my $o = "$t<array>\n";
    $o .= emit($_, $ind + 1) for @{$n->[1]};
    return $o . "$t</array>\n";
  }
  return "$t<$n->[1]/>\n" if $k eq 'bool';
  return "$t<$k>" . esc($n->[1]) . "</$k>\n";
}
sub save {
  my ($f, $root) = @_;
  my $out = qq{<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n} . emit($root, 0) . "</plist>\n";
  my $tmp = "$f.fake$$";
  open(my $h, '>', $tmp) or die "cannot write\n";
  print $h $out; close $h;
  rename $tmp, $f or die "cannot rename\n";
}
sub fmt {
  my ($n, $ind) = @_;
  my $t = $n->[0];
  if ($t eq 'dict') {
    my $o = "Dict {\n";
    $o .= (' ' x ($ind + 4)) . $_->[0] . ' = ' . fmt($_->[1], $ind + 4) . "\n" for @{$n->[1]};
    return $o . (' ' x $ind) . '}';
  }
  if ($t eq 'array') {
    my $o = "Array {\n";
    $o .= (' ' x ($ind + 4)) . fmt($_, $ind + 4) . "\n" for @{$n->[1]};
    return $o . (' ' x $ind) . '}';
  }
  return $n->[1];
}
sub steps { return grep { length } split /:/, $_[0]; }
sub walk {
  my ($root, @c) = @_;
  my $n = $root;
  for my $c (@c) {
    if ($n->[0] eq 'dict') { my ($e) = grep { $_->[0] eq $c } @{$n->[1]}; return undef unless $e; $n = $e->[1]; }
    elsif ($n->[0] eq 'array') { return undef unless $c =~ /^\d+$/ && $c < @{$n->[1]}; $n = $n->[1][$c]; }
    else { return undef; }
  }
  return $n;
}
sub tokens {
  my $s = shift; my @t;
  while ($s =~ /\G\s*(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|(\S+))/gc) { push @t, defined $1 ? $1 : defined $2 ? $2 : $3; }
  return @t;
}
sub newnode {
  my ($type, @v) = @_;
  return ['string', join(' ', @v)] if $type eq 'string';
  return ['integer', $v[0]] if $type eq 'integer';
  return ['bool', ($v[0] // '') eq 'true' ? 'true' : 'false'] if $type eq 'bool';
  return ['dict', []] if $type eq 'dict';
  return ['array', []] if $type eq 'array';
  die "unsupported type $type\n";
}
if ($mode eq 'events') {
  my $plist = load_plist($ARGV[0]);
  if (my $env = walk($plist, 'EnvironmentVariables')) {
    print "\tenvironment = {\n";
    printf "\t\t%s => %s\n", $_->[0], $_->[1][1] for @{$env->[1]};
    print "\t}\n";
  }
  my $cal = walk($plist, 'StartCalendarInterval') or exit;
  my $label = walk($plist, 'Label')->[1];
  my $i = 0;
  print "\tevent triggers = {\n";
  for my $slot ($cal->[0] eq 'array' ? @{$cal->[1]} : $cal) {
    next unless $slot->[0] eq 'dict';
    print "\t\t$label.", ++$i, " => {\n\t\t\tservice = $label\n",
          "\t\t\tstream = com.apple.launchd.calendarinterval\n\t\t\tdescriptor = {\n";
    printf "\t\t\t\t\"%s\" => %s\n", $_->[0], $_->[1][1] for @{$slot->[1]};
    print "\t\t\t}\n\t\t}\n";
  }
  print "\t}\n";
  exit;
}
if ($mode eq 'plutil') {
  my ($flag, $file) = @ARGV;
  exit 64 unless defined $flag && $flag eq '-lint';
  eval { load_plist($file) };
  if ($@) { print "$file: Property List error: $@"; exit 1; }
  print "$file: OK\n"; exit 0;
}
my ($flag, $cmd, $file) = @ARGV;
exit 64 unless defined $flag && $flag eq '-c' && defined $file;
my $root = eval { load_plist($file) };
if ($@) { print STDERR "Error Reading File: $file\n"; exit 1; }
my @t = tokens($cmd);
my $verb = shift @t;
if ($verb eq 'Print') {
  my $path = defined $t[0] ? $t[0] : ':';
  my $n = walk($root, steps($path));
  unless ($n) { print STDERR "Print: Entry, \"$path\", Does Not Exist\n"; exit 1; }
  print fmt($n, 0), "\n"; exit 0;
}
if ($verb eq 'Add') {
  my ($path, $type, @v) = @t;
  my @c = steps($path); my $last = pop @c;
  my $p = walk($root, @c);
  unless ($p) { print STDERR "Add: Entry, \"$path\", Does Not Exist\n"; exit 1; }
  my $new = newnode($type, @v);
  if ($p->[0] eq 'dict') {
    if (grep { $_->[0] eq $last } @{$p->[1]}) { print STDERR "Add: \"$path\" Entry Already Exists\n"; exit 1; }
    push @{$p->[1]}, [$last, $new];
  } elsif ($p->[0] eq 'array') {
    if ($last =~ /^\d+$/ && $last <= @{$p->[1]}) { splice @{$p->[1]}, $last, 0, $new; } else { push @{$p->[1]}, $new; }
  } else { print STDERR "Add: parent is not a container\n"; exit 1; }
  save($file, $root); exit 0;
}
if ($verb eq 'Set') {
  my ($path, @v) = @t;
  my $n = walk($root, steps($path));
  unless ($n && $n->[0] !~ /^(dict|array)$/) { print STDERR "Set: Entry, \"$path\", Does Not Exist\n"; exit 1; }
  $n->[1] = $n->[0] eq 'bool' ? ($v[0] eq 'true' ? 'true' : 'false') : join(' ', @v);
  save($file, $root); exit 0;
}
if ($verb eq 'Delete') {
  my ($path) = @t;
  my @c = steps($path); my $last = pop @c;
  my $p = walk($root, @c);
  unless ($p) { print STDERR "Delete: Entry, \"$path\", Does Not Exist\n"; exit 1; }
  if ($p->[0] eq 'dict') { $p->[1] = [grep { $_->[0] ne $last } @{$p->[1]}]; }
  else { splice @{$p->[1]}, $last, 1; }
  save($file, $root); exit 0;
}
print STDERR "Unrecognized Command\n"; exit 1;
EOF
cat >"$BIN/PlistBuddy.fake" <<EOF
#!/bin/bash
exec /usr/bin/perl "$BIN/plistfake.pl" plistbuddy "\$@"
EOF
cat >"$BIN/plutil.fake" <<EOF
#!/bin/bash
exec /usr/bin/perl "$BIN/plistfake.pl" plutil "\$@"
EOF

cat >"$BIN/launchctl" <<'EOF'
#!/bin/bash
D="$FAKE_LCTL_DIR"
mkdir -p "$D/loaded" "$D/running" "$D/paths"
verb="${1:-}"; shift
echo "$verb $*" >>"$D/calls"
n=0; [ -f "$D/count.$verb" ] && n=$(cat "$D/count.$verb")
n=$((n + 1)); echo "$n" >"$D/count.$verb"
for f in ${FAKE_LCTL_FAIL:-}; do
  case "$f" in "$verb:$n"|"$verb:*") echo "fake launchctl: $verb failed" >&2; exit 5 ;; esac
done
case "${FAKE_LCTL_HOLD:-}" in
  "$verb":*) h="${FAKE_LCTL_HOLD#*:}"; : >"$h.reached"; while [ ! -e "$h" ]; do /bin/sleep 0.1; done ;;
esac
case "$verb" in
  print)
    if [ "$1" = gui/501 ]; then
      printf '%s = {\n\tinherited environment = {\n' "$1"
      if [ -f "$D/domain-env" ]; then cat "$D/domain-env"; else cat "$D/inherited"; fi
      printf '\t}\n}\n'
      exit 0
    fi
    label="${1##*/}"
    [ -f "$D/loaded/$label" ] || { echo "Could not find service \"$label\"" >&2; exit 113; }
    pc=0; [ -f "$D/prints.$label" ] && pc=$(cat "$D/prints.$label")
    pc=$((pc + 1)); echo "$pc" >"$D/prints.$label"
    state="not running"
    [ ! -e "$D/running/$label" ] || state=running
    if [ -n "${FAKE_LCTL_RUN_FROM:-}" ] && [ "$pc" -ge "$FAKE_LCTL_RUN_FROM" ]; then state=running; fi
    args=$(/usr/bin/perl -0777 -ne 'if (m{<key>ProgramArguments</key>\s*<array>(.*?)</array>}s) { for my $a ($1 =~ m{<string>(.*?)</string>}gs) { $a =~ s/&amp;/&/g; print "\t\t$a\n" } }' "$D/loaded/$label")
    first=$(printf '%s\n' "$args" | /usr/bin/sed -n '1s/^\t\t//p')
    printf '%s = {\n\tstate = %s\n\tpath = %s\n\n\tprogram = %s\n\targuments = {\n%s\n\t}\n' "$1" "$state" "$(cat "$D/paths/$label")" "$first" "$args"
    printf '\tinherited environment = {\n'
    cat "$D/inherited"
    printf '\t}\n'
    /usr/bin/perl "${0%/*}/plistfake.pl" events "$D/loaded/$label"
    echo '}'
    ;;
  bootout)
    label="${1##*/}"
    [ -f "$D/loaded/$label" ] || { echo "No such process" >&2; exit 3; }
    rm -f "$D/loaded/$label" "$D/running/$label"
    ;;
  bootstrap)
    label=$(/usr/bin/perl -0777 -ne 'print $1 if m{<key>Label</key>\s*<string>(.*?)</string>}s' "$2")
    [ -n "$label" ] || { echo "Bootstrap failed: bad plist" >&2; exit 5; }
    [ ! -f "$D/loaded/$label" ] || { echo "Bootstrap failed: 5: Input/output error" >&2; exit 5; }
    echo "$2" >"$D/paths/$label"
    cp "$2" "$D/loaded/$label"
    ;;
  *) echo "fake launchctl: unsupported $verb" >&2; exit 64 ;;
esac
EOF
chmod +x "$BIN"/launchctl "$BIN"/*.fake

REAL=0
if [ "${ROUTINE_ADOPT_REAL_PLIST:-0}" = 1 ]; then
  [ "$(uname -s)" = Darwin ] || { echo "ROUTINE_ADOPT_REAL_PLIST=1 needs macOS" >&2; exit 1; }
  REAL=1
  export ROUTINE_PLISTBUDDY=/usr/libexec/PlistBuddy ROUTINE_PLUTIL=/usr/bin/plutil
else
  export ROUTINE_PLISTBUDDY="$BIN/PlistBuddy.fake" ROUTINE_PLUTIL="$BIN/plutil.fake"
fi
export ROUTINE_LAUNCHCTL="$BIN/launchctl" ROUTINE_UID=501 ROUTINE_TZ=Europe/Paris

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

FAILED=0
PIDS=""
CASE=""
BGPID=""
AG=""
FK=""
RD=""
LAB=""
L=""
NAME=""
M=""

fail() { printf '    FAIL: %s\n' "$*" >&2; exit 1; }
eq() { [ "$1" = "$2" ] || fail "$3: got '$1', want '$2'"; }
track() { PIDS="$PIDS $1"; }
cleanup_pids() { local p; for p in $PIDS; do kill -KILL "$p" 2>/dev/null; done; }

wait_for() {
  local i=0 max=$((${2:-30} * 10))
  while [ ! -e "$1" ]; do
    i=$((i + 1)); [ "$i" -le "$max" ] || fail "timeout waiting for $1"
    /bin/sleep 0.1
  done
}

kill_hard() { kill -KILL "$1" 2>/dev/null; wait "$1" 2>/dev/null; return 0; }

snap() {
  (cd "$1" && find . | LC_ALL=C sort | while IFS= read -r f; do
    if [ -f "$f" ]; then cksum "$f"; else echo "$f"; fi
  done)
}
snap_or_absent() { if [ -d "$1" ]; then snap "$1"; else echo absent; fi; }

core_snap() {
  [ -d "$1" ] || return 0
  (cd "$1" && find . -type f | LC_ALL=C sort | grep -v -e '^\./cap$' -e '^\./plist\.before\.' | while IFS= read -r f; do cksum "$f"; done)
}

new_case() {
  CASE="$(mktemp -d "$TMP_DIR/case.XXXXXX")"
  AG="$CASE/agents"; FK="$CASE/fake"
  export ETABLI_ROUTINES_DIR="$CASE/routines" ROUTINE_LAUNCHAGENTS_DIR="$AG" FAKE_LCTL_DIR="$FK" ROUTINE_TEST_CLOCK="$CASE/clock"
  RD="$ETABLI_ROUTINES_DIR"
  mkdir -p "$AG" "$FK"
  printf '\t\tETABLI_ROUTINES_DIR => %s\n' "$RD" >"$FK/inherited"
  echo "1 12 0" >"$CASE/clock"
  unset FAKE_LCTL_FAIL FAKE_LCTL_HOLD FAKE_LCTL_RUN_FROM ROUTINE_TEST_FAIL ROUTINE_TEST_HOLD ROUTINE_TEST_PERL
}

lctl() { "$ROUTINE_LAUNCHCTL" "$@"; }
pbt() { "$ROUTINE_PLISTBUDDY" -c "$1" "$2"; }
A() { /bin/bash "$R" adopt "$@" </dev/null >"$CASE/out" 2>"$CASE/err"; }
Rl() { /bin/bash "$R" release "$@" </dev/null >"$CASE/out" 2>"$CASE/err"; }
S() { /bin/bash "$R" status </dev/null >"$CASE/status" 2>&1; }
run_kind() { if [ "$1" = adopt ]; then A "$2"; else Rl "$2"; fi; }

label_of() { case "$1" in fleet-improvement) echo com.tonours.fleet-improvement ;; *) echo "com.example.$1" ;; esac; }

put() {
  LAB="$(label_of "$1")"
  cp "$FIXT/$1.plist" "$AG/$LAB.plist"
  cp "$FIXT/$1.plist" "$CASE/orig.$LAB"
  lctl bootstrap gui/501 "$AG/$LAB.plist" || fail "cannot load the fixture $1"
}

reset_calls() { : >"$FK/calls"; rm -f "$FK"/prints.*; }
ncalls() { if [ -f "$FK/calls" ]; then wc -l <"$FK/calls" | tr -d ' '; else echo 0; fi; }
fail_next() { local c=0; [ -f "$FK/count.$1" ] && c=$(cat "$FK/count.$1"); echo "$1:$((c + 1))"; }

untouched() {
  if grep -Eq "^(bootout|bootstrap) .*$1" "$FK/calls" 2>/dev/null; then fail "$2: launchd was told to change $1"; fi
}

plist_is() {
  cmp -s "$AG/$1.plist" "$2" || fail "$3: the plist of $1 is not the expected one"
  cmp -s "$FK/loaded/$1" "$2" || fail "$3: the loaded job of $1 is not the expected one"
}

mval() { sed -n 's/.*"'"$2"'":"\([^"]*\)".*/\1/p' "$1" | head -n 1; }

hand_rewrite() {
  cp "$CASE/orig.$1" "$AG/$1.plist"
  pbt 'Add :Nice integer 5' "$AG/$1.plist" || fail "cannot rewrite the plist"
  lctl bootout "gui/501/$1" >/dev/null 2>&1
  lctl bootstrap gui/501 "$AG/$1.plist" || fail "cannot reload the rewritten plist"
}

make_start() {
  put brain-cron; L=$LAB; NAME=brain-cron
  case "$1" in
    new) ;;
    adopted) A "$L" || fail "setup: adopt" ;;
    released) A "$L" || fail "setup: adopt"; Rl "$L" || fail "setup: release"; hand_rewrite "$L" ;;
    unwrapped) A "$L" || fail "setup: adopt"; hand_rewrite "$L" ;;
  esac
}

held() {
  local point="$1"; shift
  rm -f "$CASE/h" "$CASE/h.reached"
  ROUTINE_TEST_HOLD="$point:$CASE/h" /bin/bash "$R" "$@" </dev/null >"$CASE/out.h" 2>&1 &
  BGPID=$!
  track "$BGPID"
  wait_for "$CASE/h.reached"
}

wait_adopt_free() {
  local i=0
  while ! /usr/bin/perl -e 'use Fcntl qw(:flock); open(my $h, ">>", $ARGV[0]) or exit 2; flock($h, LOCK_EX|LOCK_NB) or exit 1' "$RD/adopt.lock"; do
    i=$((i + 1)); [ "$i" -le 300 ] || fail "adopt.lock is still held"
    /bin/sleep 0.1
  done
}

kill_held() { kill_hard "$BGPID"; wait_adopt_free; }

wrapped_ok() {
  eq "$(pbt 'Print :ProgramArguments:0' "$AG/$1.plist")" /bin/bash "$1: program"
  eq "$(pbt 'Print :ProgramArguments:1' "$AG/$1.plist")" "$R" "$1: routine.sh"
  eq "$(pbt 'Print :ProgramArguments:2' "$AG/$1.plist")" run "$1: run"
  eq "$(pbt 'Print :ProgramArguments:3' "$AG/$1.plist")" "$2" "$1: name"
  eq "$(pbt 'Print :ProgramArguments:4' "$AG/$1.plist")" -- "$1: --"
  eq "$(pbt 'Print :ProgramArguments:5' "$AG/$1.plist")" "$(pbt 'Print :ProgramArguments:0' "$CASE/orig.$1")" "$1: original command"
}

has() { grep -qF -- "$2" "$1" || fail "$3: '$2' not in $1: $(cat "$1" 2>/dev/null)"; }

t_adopt_release_roundtrip() {
  new_case
  local fx lab f slots cap
  for fx in brain-consolidate brain-cron docs-pr-sync mac-cleanup; do
    put "$fx"; lab=$LAB; f="$RD/$fx"
    A "$lab"; eq $? 0 "adopt $fx"
    wrapped_ok "$lab" "$fx"
    cmp -s "$FK/loaded/$lab" "$AG/$lab.plist" || fail "$fx: the job is not loaded with the wrapped plist"
    case "$fx" in
      brain-consolidate) slots='[{"weekday":null,"hour":3,"minute":0}]'; cap=3 ;;
      brain-cron) slots='[{"weekday":null,"hour":18,"minute":0}]'; cap=3 ;;
      docs-pr-sync) slots='[{"weekday":3,"hour":9,"minute":0}]'; cap=3 ;;
      mac-cleanup) slots='[{"weekday":null,"hour":8,"minute":0},{"weekday":null,"hour":13,"minute":0}]'; cap=4 ;;
    esac
    has "$f/routine.json" '"v":1' "$fx manifest"
    has "$f/routine.json" "\"name\":\"$fx\"" "$fx manifest"
    has "$f/routine.json" "\"label\":\"$lab\"" "$fx manifest"
    has "$f/routine.json" '"tz":"Europe/Paris"' "$fx manifest"
    has "$f/routine.json" "\"slots\":$slots" "$fx manifest"
    has "$f/routine.json" '"source":"adopt"' "$fx manifest"
    grep -q '"adopted":"[0-9][0-9-]*T[0-9:]*Z"' "$f/routine.json" || fail "$fx: adopted"
    grep -q '"origin":"plist.before.[^"]*"' "$f/routine.json" || fail "$fx: origin"
    grep -q '"command":"[^"]*"' "$f/routine.json" || fail "$fx: command"
    [ "$HAVE_JQ" = 0 ] || jq -e . "$f/routine.json" >/dev/null || fail "$fx: the manifest is not JSON"
    eq "$(cat "$f/cap")" "$cap" "$fx default cap"
    [ -f "$f/$(mval "$f/routine.json" origin)" ] || fail "$fx: the origin file is missing"
    [ ! -e "$f/pending" ] && [ ! -e "$f/plist.prev" ] && [ ! -e "$f/plist.next" ] && [ ! -e "$f/routine.json.next" ] || fail "$fx: leftovers"
    Rl "$lab"; eq $? 0 "release $fx"
    cmp -s "$AG/$lab.plist" "$CASE/orig.$lab" || fail "$fx: the plist is not byte-identical after release"
    plist_is "$lab" "$CASE/orig.$lab" "$fx released"
    [ -f "$f/routine.released.json" ] && [ ! -e "$f/routine.json" ] || fail "$fx: manifest after release"
    [ ! -e "$f/pending" ] && [ ! -e "$f/plist.prev" ] && [ ! -e "$f/plist.next" ] || fail "$fx: leftovers after release"
  done
  A com.example.brain-cron --cap 9; eq $? 0 "adopt again after a release"
  eq "$(cat "$RD/brain-cron/cap")" 3 "an existing cap is kept"
  new_case
  put brain-cron
  A "$LAB" --cap 9 --name my-cron; eq $? 0 "adopt with --name and --cap"
  eq "$(cat "$RD/my-cron/cap")" 9 "--cap"
  has "$RD/my-cron/routine.json" '"name":"my-cron"' "--name"
}

t_unwrapped_readopt_keeps_both_origins() {
  new_case
  put brain-cron; local lab=$LAB f="$RD/brain-cron" o1 o2 s0
  cp "$CASE/orig.$lab" "$CASE/P0"
  A "$lab"; eq $? 0 "adopt P0"
  o1=$(mval "$f/routine.json" origin)
  cmp -s "$f/$o1" "$CASE/P0" || fail "the first origin is not P0"
  hand_rewrite "$lab"
  cp "$AG/$lab.plist" "$CASE/P1"
  S; grep -q "^brain-cron unwrapped " "$CASE/status" || fail "status does not say unwrapped: $(cat "$CASE/status")"
  A "$lab"; eq $? 0 "adopt P1"
  o2=$(mval "$f/routine.json" origin)
  [ "$o1" != "$o2" ] || fail "the origin was overwritten"
  cmp -s "$f/$o1" "$CASE/P0" || fail "P0 is not kept under its dated name"
  cmp -s "$f/$o2" "$CASE/P1" || fail "the new origin is not P1"
  eq "$(pbt 'Print :ProgramArguments:2' "$AG/$lab.plist")" run "wrapped again"
  Rl "$lab"; eq $? 0 "release"
  cmp -s "$AG/$lab.plist" "$CASE/P1" || fail "the plist put back is not P1"
  plist_is "$lab" "$CASE/P1" "released"
  cmp -s "$f/$o1" "$CASE/P0" || fail "P0 was lost at release"
  new_case
  put brain-cron; lab=$LAB; f="$RD/brain-cron"
  cp "$CASE/orig.$lab" "$CASE/P0"
  A "$lab" || fail "setup"
  o1=$(mval "$f/routine.json" origin)
  hand_rewrite "$lab"
  cp "$AG/$lab.plist" "$CASE/P1"
  s0=$(snap "$f")
  FAKE_LCTL_FAIL="$(fail_next bootstrap)" A "$lab"; eq $? 1 "adopt with a failing bootstrap"
  plist_is "$lab" "$CASE/P1" "after the failure"
  eq "$(mval "$f/routine.json" origin)" "$o1" "the origin in force"
  cmp -s "$f/$o1" "$CASE/P0" || fail "plist.before is not P0 again"
  eq "$(snap "$f")" "$s0" "the folder after the failure"
}

t_kill_in_bootout_holds_the_lock() {
  new_case
  put brain-cron; local lab=$LAB m pid
  put mac-cleanup; m=$LAB
  cp "$AG/$lab.plist" "$CASE/before.plist"
  FAKE_LCTL_HOLD="bootout:$CASE/lh" /bin/bash "$R" adopt "$lab" </dev/null >/dev/null 2>&1 &
  pid=$!; track "$pid"
  wait_for "$CASE/lh.reached"
  kill_hard "$pid"
  A "$m"; eq $? 75 "a new command while launchctl is still at work"
  /bin/sleep 0.3
  A "$m"; eq $? 75 "still refused"
  : >"$CASE/lh"
  wait_adopt_free
  A "$m"; eq $? 0 "admitted once launchctl has ended"
  plist_is "$lab" "$CASE/before.plist" "the killed adoption was settled"
  [ -z "$(core_snap "$RD/brain-cron")" ] || fail "the killed folder was not cleared"
}

t_refused_before_the_swap() {
  local variant start lab f s0
  for variant in lastcheck stage-next stage-manifest; do for start in new released; do
    new_case
    put brain-cron; lab=$LAB; f="$RD/brain-cron"
    if [ "$start" = released ]; then A "$lab" || fail "setup"; Rl "$lab" || fail "setup"; hand_rewrite "$lab"; fi
    cp "$AG/$lab.plist" "$CASE/before.plist"
    s0=$(snap_or_absent "$f")
    reset_calls
    case "$variant" in
      lastcheck) FAKE_LCTL_RUN_FROM=2 A "$lab" ;;
      *) ROUTINE_TEST_FAIL="$variant" A "$lab" ;;
    esac
    [ $? -ne 0 ] || fail "$variant/$start: the adoption went through"
    untouched "$lab" "$variant/$start"
    plist_is "$lab" "$CASE/before.plist" "$variant/$start"
    eq "$(snap_or_absent "$f")" "$s0" "$variant/$start: the folder"
  done; done
}

t_release_refused_at_the_last_check() {
  new_case
  put brain-cron; local lab=$LAB f="$RD/brain-cron" s0
  A "$lab" || fail "setup"
  cp "$AG/$lab.plist" "$CASE/before.plist"
  s0=$(snap "$f")
  reset_calls
  FAKE_LCTL_RUN_FROM=2 Rl "$lab"; [ $? -ne 0 ] || fail "released a job seen running"
  untouched "$lab" "release"
  plist_is "$lab" "$CASE/before.plist" "release"
  eq "$(snap "$f")" "$s0" "the folder"
}

t_mv_failures_at_each_rename() {
  local pt s0 f lab
  for pt in origin cap commit; do
    new_case
    put brain-cron; lab=$LAB
    cp "$AG/$lab.plist" "$CASE/before.plist"
    ROUTINE_TEST_FAIL="mv:$pt" A "$lab"; eq $? 1 "adopt, mv:$pt from a new folder"
    plist_is "$lab" "$CASE/before.plist" "adopt/new/$pt"
    [ ! -e "$RD/brain-cron" ] || fail "adopt/new/$pt: the folder is left: $(ls -A "$RD/brain-cron")"
  done
  for pt in origin commit; do
    new_case
    put brain-cron; lab=$LAB; f="$RD/brain-cron"
    A "$lab" || fail "setup"; Rl "$lab" || fail "setup"; hand_rewrite "$lab"
    cp "$AG/$lab.plist" "$CASE/before.plist"
    s0=$(snap "$f")
    ROUTINE_TEST_FAIL="mv:$pt" A "$lab"; eq $? 1 "adopt, mv:$pt from a released folder"
    plist_is "$lab" "$CASE/before.plist" "adopt/released/$pt"
    eq "$(snap "$f")" "$s0" "adopt/released/$pt: the folder"
  done
  new_case
  put brain-cron; lab=$LAB; f="$RD/brain-cron"
  A "$lab" || fail "setup"
  cp "$AG/$lab.plist" "$CASE/before.plist"
  s0=$(snap "$f")
  ROUTINE_TEST_FAIL="mv:commit" Rl "$lab"; eq $? 1 "release, mv:commit"
  plist_is "$lab" "$CASE/before.plist" "release/commit"
  eq "$(snap "$f")" "$s0" "release/commit: the folder"
}

kill_matrix() {
  local kind="$1" starts st pt core0 origin_file="" f left
  if [ "$kind" = adopt ]; then starts="new released unwrapped"; else starts="adopted"; fi
  for st in $starts; do for pt in staging staged unloaded verified committed; do
    new_case
    make_start "$st"
    put mac-cleanup; M=$LAB
    if [ "$kind" = release ]; then A "$M" || fail "setup: follow-up job"; fi
    cp "$AG/$L.plist" "$CASE/before.plist"
    f="$RD/$NAME"
    core0=$(core_snap "$f")
    if [ "$kind" = release ]; then origin_file="$f/$(mval "$f/routine.json" origin)"; fi
    held "$pt" "$kind" "$L"
    kill_held
    S; grep -q "^$NAME incomplete " "$CASE/status" || fail "$kind/$st/$pt: status does not say incomplete: $(cat "$CASE/status")"
    run_kind "$kind" "$M"; eq $? 0 "$kind/$st/$pt: the next command"
    if [ "$pt" != committed ]; then
      plist_is "$L" "$CASE/before.plist" "$kind/$st/$pt"
      eq "$(core_snap "$f")" "$core0" "$kind/$st/$pt: the folder"
    elif [ "$kind" = adopt ]; then
      [ -f "$f/routine.json" ] || fail "$kind/$st/$pt: the adoption does not stand"
      [ ! -e "$f/routine.released.json" ] || fail "$kind/$st/$pt: released manifest left"
      wrapped_ok "$L" "$NAME"
      cmp -s "$FK/loaded/$L" "$AG/$L.plist" || fail "$kind/$st/$pt: the wrapped job is not loaded"
    else
      [ -f "$f/routine.released.json" ] && [ ! -e "$f/routine.json" ] || fail "$kind/$st/$pt: the release does not stand"
      plist_is "$L" "$origin_file" "$kind/$st/$pt"
    fi
    left=$(ls -A "$f" 2>/dev/null | grep -E '^(pending|plist\.prev|plist\.next|adopt\.failed)$|\.next$' || true)
    [ -z "$left" ] || fail "$kind/$st/$pt: leftovers: $left"
  done; done
}
t_kill_matrix_adopt() { kill_matrix adopt; }
t_kill_matrix_release() { kill_matrix release; }

t_kill_then_the_other_command() {
  local kind other
  for kind in adopt release; do
    new_case
    if [ "$kind" = adopt ]; then other=release; make_start new; else other=adopt; make_start adopted; fi
    put mac-cleanup; M=$LAB
    if [ "$kind" = adopt ]; then A "$M" || fail "setup"; fi
    cp "$AG/$L.plist" "$CASE/before.plist"
    held verified "$kind" "$L"
    kill_held
    run_kind "$other" "$M"; eq $? 0 "$kind killed, then $other of the other job"
    plist_is "$L" "$CASE/before.plist" "$kind killed, then $other"
  done
}

t_kill_after_commit_then_unloaded() {
  local kind
  for kind in adopt release; do
    new_case
    if [ "$kind" = adopt ]; then make_start new; else make_start adopted; fi
    put mac-cleanup; M=$LAB
    held committed "$kind" "$L"
    kill_held
    cp "$AG/$L.plist" "$CASE/after.plist"
    lctl bootout "gui/501/$L" || fail "cannot boot the job out"
    reset_calls
    A "$M"; rc=$?; [ $rc = 0 ] || cat "$CASE/err" >&2; eq $rc 0 "$kind: the next command"
    untouched "$L" "$kind"
    cmp -s "$AG/$L.plist" "$CASE/after.plist" || fail "$kind: the settling put a plist back"
    [ ! -e "$FK/loaded/$L" ] || fail "$kind: the settling loaded a job"
    if [ "$kind" = adopt ]; then [ -f "$RD/$NAME/routine.json" ] || fail "adopt does not stand"
    else [ -f "$RD/$NAME/routine.released.json" ] && [ ! -e "$RD/$NAME/routine.json" ] || fail "release does not stand"; fi
  done
}

t_rm_failures_after_commit() {
  local kind pt f
  for kind in adopt release; do
    for pt in released prev pending kill; do
      [ "$kind$pt" != releasereleased ] || continue
      new_case
      if [ "$kind" = adopt ]; then
        if [ "$pt" = released ]; then make_start released; else make_start new; fi
      else
        make_start adopted
      fi
      put mac-cleanup; M=$LAB
      f="$RD/$NAME"
      if [ "$pt" = kill ]; then
        held prev-deleted "$kind" "$L"
        kill_held
      else
        ROUTINE_TEST_FAIL="rm:$pt" run_kind "$kind" "$L"; eq $? 1 "$kind: rm:$pt"
      fi
      S; grep -q "^$NAME incomplete " "$CASE/status" || fail "$kind/$pt: status does not say incomplete: $(cat "$CASE/status")"
      if [ "$kind" = adopt ]; then [ -f "$f/routine.json" ] || fail "$kind/$pt: the adoption does not stand"
      else [ -f "$f/routine.released.json" ] && [ ! -e "$f/routine.json" ] || fail "$kind/$pt: the release does not stand"; fi
      cp "$AG/$L.plist" "$CASE/after.plist"
      reset_calls
      A "$M"; eq $? 0 "$kind/$pt: the next command"
      untouched "$L" "$kind/$pt"
      cmp -s "$AG/$L.plist" "$CASE/after.plist" || fail "$kind/$pt: a plist was put back"
      [ ! -e "$f/pending" ] || fail "$kind/$pt: pending is left"
      [ ! -e "$f/plist.prev" ] || fail "$kind/$pt: plist.prev is left"
      if [ "$kind" = adopt ]; then [ ! -e "$f/routine.released.json" ] || fail "$kind/$pt: the released manifest is left"; fi
      S; ! grep -q "^$NAME incomplete " "$CASE/status" || fail "$kind/$pt: still incomplete"
    done
  done
}

t_settle_failure_preserves_commit() {
  local kind f
  for kind in adopt release; do
    new_case
    if [ "$kind" = adopt ]; then make_start new; else make_start adopted; fi
    put mac-cleanup; M=$LAB
    f="$RD/$NAME"
    held committed "$kind" "$L"
    kill_held
    cp "$AG/$L.plist" "$CASE/after.plist"
    reset_calls

    ROUTINE_TEST_FAIL=rm:prev A "$M"; eq $? 1 "$kind: failed settling"
    [ -f "$f/pending" ] && [ -f "$f/plist.prev" ] || fail "$kind: commit evidence was lost"
    untouched "$L" "$kind: failed settling"

    A "$M"; eq $? 0 "$kind: successful settling"
    untouched "$L" "$kind: successful settling"
    plist_is "$L" "$CASE/after.plist" "$kind: commit still stands"
    [ ! -e "$f/pending" ] && [ ! -e "$f/plist.prev" ] || fail "$kind: leftovers after retry"
  done
}

t_running_job_is_not_stopped_by_signal_rollback() {
  local kind
  for kind in adopt release; do
    new_case
    if [ "$kind" = adopt ]; then make_start new; else make_start adopted; fi
    put mac-cleanup; M=$LAB
    cp "$AG/$L.plist" "$CASE/before.plist"
    held verified "$kind" "$L"
    cp "$AG/$L.plist" "$CASE/during.plist"
    : >"$FK/running/$L"
    reset_calls

    kill -TERM "$BGPID"
    wait "$BGPID"; eq $? 143 "$kind: signalled command"
    untouched "$L" "$kind: rollback while running"
    plist_is "$L" "$CASE/during.plist" "$kind: rollback deferred"
    [ -e "$RD/$NAME/pending" ] && [ -e "$RD/$NAME/plist.prev" ] || fail "$kind: recovery files lost"
    if [ "$kind" = adopt ]; then
      [ ! -e "$RD/$NAME/cap" ] || fail "the aborted adoption left a cap"
      [ -z "$(find "$RD/$NAME" -name 'plist.before.*' -print)" ] || fail "the aborted adoption left an origin"
    fi

    rm -f "$FK/running/$L"
    A "$M"; eq $? 0 "$kind: next command after the job ended"
    plist_is "$L" "$CASE/before.plist" "$kind: settled"
  done
}

t_partial_backup_is_discarded_without_restoration() {
  local kind f
  for kind in adopt release; do
    new_case
    if [ "$kind" = adopt ]; then make_start new; else make_start adopted; fi
    put mac-cleanup; M=$LAB
    f="$RD/$NAME"
    held backup-copied "$kind" "$L"
    [ -f "$f/plist.prev.next" ] && [ ! -e "$f/plist.prev" ] || fail "$kind: copy published before rename"
    printf '<plist' >"$f/plist.prev.next"
    kill_held
    cp "$AG/$L.plist" "$CASE/before.plist"
    reset_calls

    A "$M"; eq $? 0 "$kind: settling an interrupted copy"
    untouched "$L" "$kind: incomplete backup"
    plist_is "$L" "$CASE/before.plist" "$kind: job kept"
    [ ! -e "$f/pending" ] && [ ! -e "$f/plist.prev.next" ] || fail "$kind: leftovers after settling"
  done
}

t_signal_after_publication_removes_the_uncommitted_files() {
  local phase
  for phase in moved-origin moved-cap; do
    new_case
    make_start new
    held "$phase" adopt "$L"
    kill -TERM "$BGPID"
    wait "$BGPID"; eq $? 143 "$phase: signalled adoption"
    plist_is "$L" "$CASE/orig.$L" "$phase: original restored"
    [ ! -e "$RD/$NAME" ] || fail "$phase: aborted adoption left a folder"
  done
}

t_idle_text_in_arguments_does_not_hide_running_job() {
  new_case
  put mac-cleanup
  local lab="$LAB"
  lctl bootout "gui/501/$lab" || fail "cannot unload fixture"
  pbt 'Add :ProgramArguments:1 string "state = not running"' "$AG/$lab.plist" || fail "cannot add argument"
  lctl bootstrap gui/501 "$AG/$lab.plist" || fail "cannot reload fixture"
  : >"$FK/running/$lab"
  cp "$AG/$lab.plist" "$CASE/before.plist"
  reset_calls
  A "$lab"; eq $? 2 "running despite argument"
  untouched "$lab" "running despite argument"
  plist_is "$lab" "$CASE/before.plist" "running job kept"
}

t_multiline_manifest_keeps_the_label_bound() {
  new_case
  put mac-cleanup
  local lab="$LAB"
  mkdir -p "$RD/other"
  printf '{"label":\n"%s","source":"install"}\n' "$lab" >"$RD/other/routine.json"
  reset_calls
  A "$lab"; eq $? 2 "label already bound"
  has "$CASE/err" "already bound to the name other" "label binding"
  untouched "$lab" "label already bound"
}

t_running_job_is_not_stopped_by_settling() {
  local kind
  for kind in adopt release; do
    new_case
    if [ "$kind" = adopt ]; then make_start new; else make_start adopted; fi
    put mac-cleanup; M=$LAB
    cp "$AG/$L.plist" "$CASE/before.plist"
    held verified "$kind" "$L"
    kill_held
    cp "$AG/$L.plist" "$CASE/during.plist"
    : >"$FK/running/$L"
    reset_calls
    A "$M"; eq $? 2 "$kind: the next command, with the job running"
    untouched "$L" "$kind"
    [ -e "$FK/running/$L" ] || fail "$kind: the running job was stopped"
    cmp -s "$AG/$L.plist" "$CASE/during.plist" || fail "$kind: the plist was changed"
    S; grep -q "^$NAME incomplete " "$CASE/status" || fail "$kind: not incomplete any more"
    rm -f "$FK/running/$L"
    echo "1 17 55" >"$CASE/clock"
    A "$M"; eq $? 2 "$kind: with a slot near"
    untouched "$L" "$kind/slot"
    echo "1 12 0" >"$CASE/clock"
    reset_calls
    FAKE_LCTL_RUN_FROM=2 A "$M"; eq $? 2 "$kind: job starts between the two state reads"
    untouched "$L" "$kind: settling recheck"
    plist_is "$L" "$CASE/during.plist" "$kind: settling deferred"
    A "$M"; eq $? 0 "$kind: once the job has ended"
    plist_is "$L" "$CASE/before.plist" "$kind: settled"
  done
}

t_oversized_manifest_is_refused_before_swap() {
  new_case
  put mac-cleanup
  local lab="$LAB"
  /usr/bin/perl -0777 -pe '
    $slots = join "", map {
      sprintf "<dict><key>Hour</key><integer>%d</integer><key>Minute</key><integer>%d</integer></dict>", int($_ / 60), $_ % 60
    } 180..429;
    s{(<key>StartCalendarInterval</key>\s*<array>).*?(</array>)}{$1$slots$2}s;
  ' "$FIXT/mac-cleanup.plist" >"$AG/$lab.plist" || fail "cannot generate large schedule"
  lctl bootout "gui/501/$lab" || fail "cannot unload original schedule"
  lctl bootstrap gui/501 "$AG/$lab.plist" || fail "cannot load large schedule"
  cp "$AG/$lab.plist" "$CASE/before.plist"
  reset_calls
  A "$lab"; eq $? 2 "large schedule exit"
  has "$CASE/err" "manifest exceeds" "large schedule reason"
  untouched "$lab" "large schedule"
  plist_is "$lab" "$CASE/before.plist" "large schedule"
  [ ! -e "$RD/mac-cleanup/routine.json" ] || fail "oversized manifest published"
}

t_three_commands_after_a_kill() {
  new_case
  make_start new
  local m1 m2 m3 p1 p2 p3 p rc n0=0 n75=0
  put brain-consolidate; m1=$LAB
  put docs-pr-sync; m2=$LAB
  put mac-cleanup; m3=$LAB
  cp "$AG/$L.plist" "$CASE/before.plist"
  held verified adopt "$L"
  kill_held
  export FAKE_LCTL_HOLD="bootout:$CASE/lh"
  /bin/bash "$R" adopt "$m1" </dev/null >/dev/null 2>&1 & p1=$!; track "$p1"
  /bin/bash "$R" adopt "$m2" </dev/null >/dev/null 2>&1 & p2=$!; track "$p2"
  /bin/bash "$R" adopt "$m3" </dev/null >/dev/null 2>&1 & p3=$!; track "$p3"
  unset FAKE_LCTL_HOLD
  wait_for "$CASE/lh.reached"
  /bin/sleep 0.5
  : >"$CASE/lh"
  for p in $p1 $p2 $p3; do
    wait "$p"; rc=$?
    case "$rc" in 0) n0=$((n0 + 1)) ;; 75) n75=$((n75 + 1)) ;; *) fail "unexpected exit $rc" ;; esac
  done
  eq "$n0 $n75" "1 2" "one settles and runs, two are refused"
  plist_is "$L" "$CASE/before.plist" "the killed adoption was settled once"
}

t_reserved_names_refused() {
  new_case
  put fleet-improvement; local reserved=$LAB
  put brain-cron
  local a0 n0 args
  a0=$(snap "$AG"); n0=$(ncalls)
  for args in "adopt com.example.brain-cron --name fleet-improvement" "adopt com.tonours.fleet-improvement" \
              "adopt com.tonours.fleet-improvement --name other" "release com.tonours.fleet-improvement" "release fleet-improvement"; do
    /bin/bash "$R" $args </dev/null >/dev/null 2>&1; eq $? 2 "$args"
  done
  [ ! -e "$RD" ] || fail "the routines folder was created: $(ls -A "$RD")"
  eq "$(snap "$AG")" "$a0" "LaunchAgents"
  eq "$(ncalls)" "$n0" "launchctl calls"
  cmp -s "$AG/$reserved.plist" "$CASE/orig.$reserved" || fail "the reserved plist was touched"
  mkdir -p "$RD"
  for args in "adopt com.example.brain-cron --name fleet-improvement" "adopt com.tonours.fleet-improvement" "release fleet-improvement"; do
    /bin/bash "$R" $args </dev/null >/dev/null 2>&1; eq $? 2 "$args, folder present and empty"
  done
  eq "$(snap "$RD")" "." "the empty routines folder"
}

t_adopt_release_adopt_by_hand() {
  new_case
  put brain-cron; local lab=$LAB f="$RD/brain-cron" o1 o2 s0
  cp "$CASE/orig.$lab" "$CASE/P0"
  A "$lab" || fail "adopt"
  o1=$(mval "$f/routine.json" origin)
  Rl "$lab" || fail "release"
  hand_rewrite "$lab"
  cp "$AG/$lab.plist" "$CASE/P1"
  A "$lab"; eq $? 0 "adopt the hand-written plist"
  o2=$(mval "$f/routine.json" origin)
  [ "$o1" != "$o2" ] || fail "the first origin was kept for the new period"
  Rl "$lab"; eq $? 0 "release"
  cmp -s "$AG/$lab.plist" "$CASE/P1" || fail "the plist put back is not the hand-written one"
  plist_is "$lab" "$CASE/P1" "released"
  cmp -s "$f/$o1" "$CASE/P0" || fail "the first origin is not kept under its dated name"
  cmp -s "$f/$o2" "$CASE/P1" || fail "the second origin is not P1"
  s0=$(snap "$f")
  FAKE_LCTL_FAIL="$(fail_next bootstrap)" A "$lab"; eq $? 1 "the failing adoption"
  plist_is "$lab" "$CASE/P1" "after the failure"
  eq "$(snap "$f")" "$s0" "the folder after the failure"
}

t_adopt_twice_wraps_once() {
  new_case
  put mac-cleanup; local lab=$LAB f="$RD/mac-cleanup" m0
  A "$lab" || fail "first adopt"
  cp "$AG/$lab.plist" "$CASE/once.plist"
  m0="$f/m0.json"
  cp "$f/routine.json" "$m0"
  reset_calls
  A "$lab"; eq $? 0 "second adopt"
  cmp -s "$AG/$lab.plist" "$CASE/once.plist" || fail "the plist changed"
  eq "$(pbt 'Print :ProgramArguments:5' "$AG/$lab.plist")" /Users/me/.local/bin/mac-cleanup "wrapped once"
  untouched "$lab" "second adopt"
  eq "$(mval "$f/routine.json" adopted)" "$(mval "$m0" adopted)" "adopted is kept by a refresh"
  eq "$(mval "$f/routine.json" origin)" "$(mval "$m0" origin)" "origin is kept by a refresh"
  eq "$(ls "$f" | grep -c '^plist\.before\.')" 1 "one origin"
  [ ! -e "$f/pending" ] || fail "pending left"
}

t_name_and_label_binding() {
  new_case
  put brain-cron; local a=$LAB
  put brain-consolidate; local b=$LAB s0 f="$RD/shared"
  A "$a" --name shared || fail "first adoption"
  cp "$AG/$a.plist" "$CASE/a.plist"; cp "$AG/$b.plist" "$CASE/b.plist"
  s0=$(snap "$f")
  A "$b" --name shared; eq $? 2 "a second label under a bound name"
  cmp -s "$AG/$b.plist" "$CASE/b.plist" || fail "the second plist was touched"
  eq "$(snap "$f")" "$s0" "the first folder"
  A "$a" --name other; eq $? 2 "a label under a second name"
  [ ! -e "$RD/other" ] || fail "a folder was created for the second name"
  cmp -s "$AG/$a.plist" "$CASE/a.plist" || fail "the first plist was touched"
  Rl "$a"; eq $? 0 "release of the first"
  cmp -s "$AG/$a.plist" "$CASE/orig.$a" || fail "release did not restore the first plist"
  A "$b" --name shared; eq $? 2 "adopt B under a name bound to the released label A"
  [ ! -e "$RD/shared/routine.json" ] || fail "B was adopted under A's name"
  cmp -s "$AG/$b.plist" "$CASE/b.plist" || fail "B's plist was touched"
}

t_slot_margins() {
  new_case
  put brain-cron; local lab=$LAB f="$RD/brain-cron" kind s0
  echo "1 17 51" >"$CASE/clock"
  reset_calls
  A "$lab"; eq $? 2 "a slot in 9 minutes"
  untouched "$lab" "9 minutes"
  [ ! -e "$f" ] || fail "a folder was created"
  echo "1 17 49" >"$CASE/clock"
  A "$lab"; eq $? 0 "a slot in 11 minutes"
  echo "1 17 51" >"$CASE/clock"
  reset_calls
  Rl "$lab"; eq $? 2 "release with a slot in 9 minutes"
  untouched "$lab" "release 9 minutes"
  echo "1 17 49" >"$CASE/clock"
  Rl "$lab"; eq $? 0 "release with a slot in 11 minutes"
  for kind in adopt release; do
    new_case
    put brain-cron; lab=$LAB; f="$RD/brain-cron"
    if [ "$kind" = release ]; then A "$lab" || fail "setup"; fi
    cp "$AG/$lab.plist" "$CASE/before.plist"
    s0=$(snap_or_absent "$f")
    echo "1 17 40" >"$CASE/clock"
    reset_calls
    held staged "$kind" "$lab"
    echo "1 17 56" >"$CASE/clock"
    : >"$CASE/h"
    wait "$BGPID"; eq $? 2 "$kind: a slot 4 minutes away at the last check"
    untouched "$lab" "$kind staged"
    plist_is "$lab" "$CASE/before.plist" "$kind staged"
    eq "$(snap_or_absent "$f")" "$s0" "$kind staged: the folder"
  done
}

t_running_at_the_second_read() {
  new_case
  put brain-cron; local lab=$LAB
  cp "$AG/$lab.plist" "$CASE/before.plist"
  reset_calls
  FAKE_LCTL_RUN_FROM=2 A "$lab"; eq $? 2 "adopt, running at the second read"
  untouched "$lab" "adopt"
  plist_is "$lab" "$CASE/before.plist" "adopt"
  [ ! -e "$RD/brain-cron" ] || fail "a folder was left"
}

t_concurrent_adopts_one_wins() {
  new_case
  put brain-cron; local a=$LAB p n
  put brain-consolidate; local b=$LAB
  FAKE_LCTL_HOLD="bootout:$CASE/lh" /bin/bash "$R" adopt "$a" --name one </dev/null >/dev/null 2>&1 &
  p=$!; track "$p"
  wait_for "$CASE/lh.reached"
  A "$a" --name two; eq $? 75 "one label under a second name, while the first is in its swap"
  A "$b" --name one; eq $? 75 "a second label under one name, while the first is in its swap"
  : >"$CASE/lh"
  wait "$p"; eq $? 0 "the first adoption"
  n=$(find "$RD" -name 'routine.json' | wc -l | tr -d ' ')
  eq "$n" 1 "manifests"
  [ ! -e "$RD/two" ] || fail "the second name has a folder"
  A "$b" --name one; eq $? 2 "the second label under the bound name, afterwards"
}

t_running_or_unloaded_refused() {
  new_case
  put brain-cron; local lab=$LAB
  : >"$FK/running/$lab"
  reset_calls
  A "$lab"; eq $? 2 "adopt a running job"
  untouched "$lab" "running"
  rm -f "$FK/running/$lab"
  lctl bootout "gui/501/$lab"
  reset_calls
  A "$lab"; eq $? 2 "adopt an unloaded job"
  untouched "$lab" "unloaded"
  [ ! -e "$RD/brain-cron" ] || fail "a folder was created"
  lctl bootstrap gui/501 "$AG/$lab.plist"
  A "$lab" || fail "adopt"
  : >"$FK/running/$lab"
  reset_calls
  Rl "$lab"; eq $? 2 "release a running job"
  untouched "$lab" "release running"
  rm -f "$FK/running/$lab"
  lctl bootout "gui/501/$lab"
  reset_calls
  Rl "$lab"; eq $? 2 "release an unloaded job"
  untouched "$lab" "release unloaded"
}

refuse_case() {
  new_case
  put "$1"; local lab=$LAB
  pbt "$2" "$AG/$lab.plist" || fail "cannot change the fixture: $2"
  cp "$AG/$lab.plist" "$CASE/before.plist"
  reset_calls
  A "$lab" --name x; eq $? 2 "$2"
  grep -qw -- "$3" "$CASE/err" || fail "$2: the refusal does not name '$3': $(cat "$CASE/err")"
  cmp -s "$AG/$lab.plist" "$CASE/before.plist" || fail "$2: the plist was touched"
  untouched "$lab" "$2"
  [ ! -e "$RD/x" ] || fail "$2: a folder was created"
}

t_plists_outside_the_list_refused() {
  refuse_case brain-cron 'Add :Program string /bin/true' Program
  refuse_case brain-cron 'Add :KeepAlive bool true' KeepAlive
  refuse_case mac-cleanup 'Add :RunAtLoad bool true' RunAtLoad
  refuse_case brain-cron 'Set :RunAtLoad true' RunAtLoad
  refuse_case brain-cron 'Add :StartInterval integer 60' StartInterval
  refuse_case brain-cron 'Add :StartCalendarInterval:Month integer 5' Month
  refuse_case brain-cron 'Add :StartCalendarInterval:Day integer 5' Day
  refuse_case mac-cleanup 'Add :StartCalendarInterval:1:Month integer 1' Month
  refuse_case brain-cron 'Add :StartCalendarInterval:Weekday integer 8' Weekday
  refuse_case brain-cron 'Delete :StartCalendarInterval' StartCalendarInterval
  refuse_case brain-cron 'Delete :ProgramArguments' ProgramArguments
  new_case
  put brain-cron
  local lab=$LAB hm
  for hm in "2 30" "1 0" "2 59"; do
    set -- $hm
    pbt "Set :StartCalendarInterval:Hour $1" "$AG/$lab.plist"; pbt "Set :StartCalendarInterval:Minute $2" "$AG/$lab.plist"
    A "$lab" --name x; eq $? 2 "entry $hm"
    grep -q "$(printf '%02d:%02d' "$1" "$2")" "$CASE/err" || fail "entry $hm: the refusal does not name the time: $(cat "$CASE/err")"
  done
  pbt "Set :StartCalendarInterval:Hour 3" "$AG/$lab.plist"; pbt "Set :StartCalendarInterval:Minute 0" "$AG/$lab.plist"
  A "$lab" --name x; eq $? 0 "03:00 is accepted"
  new_case
  put fleet-improvement
  A com.tonours.fleet-improvement --name x; eq $? 2 "the reserved label"
  pbt 'Set :Label com.example.fleet-copy' "$AG/com.tonours.fleet-improvement.plist"
  cp "$AG/com.tonours.fleet-improvement.plist" "$AG/com.example.fleet-copy.plist"
  lctl bootstrap gui/501 "$AG/com.example.fleet-copy.plist" || fail "cannot load the copy"
  cp "$AG/com.example.fleet-copy.plist" "$CASE/before.plist"
  reset_calls
  A com.example.fleet-copy --name x; eq $? 2 "the fleet-improvement plist"
  grep -qw ProcessType "$CASE/err" && grep -qw Umask "$CASE/err" || fail "the refusal does not name ProcessType and Umask: $(cat "$CASE/err")"
  cmp -s "$AG/com.example.fleet-copy.plist" "$CASE/before.plist" || fail "the copy was touched"
  untouched com.example.fleet-copy "fleet-improvement copy"
}

slots_of() { sed -n 's/.*"slots":\(\[.*\]\),"adopted".*/\1/p' "$1/routine.json"; }

t_schedule_shapes_and_cap() {
  new_case
  put mac-cleanup; local lab=$LAB f="$RD/mac-cleanup"
  A "$lab" || fail "two entries"
  eq "$(slots_of "$f")" '[{"weekday":null,"hour":8,"minute":0},{"weekday":null,"hour":13,"minute":0}]' "two entries give two slots"
  eq "$(cat "$f/cap")" 4 "two daily slots"
  new_case
  put mac-cleanup; lab=$LAB; f="$RD/mac-cleanup"
  pbt 'Set :StartCalendarInterval:1:Hour 8' "$AG/$lab.plist"
  A "$lab" || fail "equal entries"
  eq "$(slots_of "$f")" '[{"weekday":null,"hour":8,"minute":0}]' "two equal entries give one"
  eq "$(cat "$f/cap")" 3 "one slot"
  new_case
  put docs-pr-sync; lab=$LAB; f="$RD/docs-pr-sync"
  pbt 'Set :StartCalendarInterval:Weekday 7' "$AG/$lab.plist"
  A "$lab" || fail "weekday 7"
  eq "$(slots_of "$f")" '[{"weekday":0,"hour":9,"minute":0}]' "Weekday 7 is stored as 0"
  new_case
  put mac-cleanup; lab=$LAB; f="$RD/mac-cleanup"
  pbt 'Add :StartCalendarInterval:2 dict' "$AG/$lab.plist"
  pbt 'Add :StartCalendarInterval:2:Hour integer 9' "$AG/$lab.plist"
  pbt 'Add :StartCalendarInterval:2:Minute integer 30' "$AG/$lab.plist"
  pbt 'Add :StartCalendarInterval:2:Weekday integer 3' "$AG/$lab.plist"
  A "$lab" || fail "three entries"
  eq "$(cat "$f/cap")" 5 "most slots on one day plus two"
  has "$f/routine.json" '{"weekday":3,"hour":9,"minute":30}' "weekly slot"
  new_case
  put mac-cleanup; lab=$LAB; f="$RD/mac-cleanup"
  pbt 'Add :StartCalendarInterval:2 dict' "$AG/$lab.plist"
  pbt 'Add :StartCalendarInterval:2:Hour integer 8' "$AG/$lab.plist"
  pbt 'Add :StartCalendarInterval:2:Minute integer 0' "$AG/$lab.plist"
  pbt 'Add :StartCalendarInterval:2:Weekday integer 1' "$AG/$lab.plist"
  A "$lab" || fail "daily and weekly"
  has "$f/routine.json" '{"weekday":1,"hour":8,"minute":0}' "the weekly entry is kept"
  has "$f/routine.json" '{"weekday":null,"hour":8,"minute":0}' "the daily entry is kept"
}

t_failures_restore() {
  local kind pt lab s0 rc want
  for kind in adopt release; do for pt in bootout bootstrap swap term; do
    new_case
    put brain-cron; lab=$LAB
    if [ "$kind" = release ]; then A "$lab" || fail "setup"; fi
    cp "$AG/$lab.plist" "$CASE/before.plist"
    s0=$(snap_or_absent "$RD/brain-cron")
    reset_calls
    case "$pt" in
      bootout) FAKE_LCTL_FAIL="$(fail_next bootout)" run_kind "$kind" "$lab"; rc=$? ;;
      bootstrap) FAKE_LCTL_FAIL="$(fail_next bootstrap)" run_kind "$kind" "$lab"; rc=$? ;;
      swap) ROUTINE_TEST_FAIL=mv:swap run_kind "$kind" "$lab"; rc=$? ;;
      term) held unloaded "$kind" "$lab"; kill -TERM "$BGPID"; wait "$BGPID"; rc=$? ;;
    esac
    [ "$rc" -ne 0 ] || fail "$kind/$pt: the command went through"
    plist_is "$lab" "$CASE/before.plist" "$kind/$pt"
    want="$s0"; [ "$kind" != adopt ] || want=absent
    eq "$(snap_or_absent "$RD/brain-cron")" "$want" "$kind/$pt: the folder"
  done; done
}

t_failed_restore_is_broken() {
  new_case
  put brain-cron; local lab=$LAB f="$RD/brain-cron"
  put mac-cleanup; local m=$LAB
  cp "$AG/$lab.plist" "$CASE/before.plist"
  FAKE_LCTL_FAIL="bootstrap:*" A "$lab"; eq $? 1 "adopt with a failing restore"
  [ -e "$f/adopt.failed" ] || fail "no adopt.failed"
  cmp -s "$f/plist.prev" "$CASE/before.plist" || fail "the backup plist.prev is not the original"
  grep -q "bootstrap" "$CASE/err" && grep -qF "$AG/$lab.plist" "$CASE/err" || fail "the manual commands are not printed: $(cat "$CASE/err")"
  S; grep -q "^brain-cron broken " "$CASE/status" || fail "status does not say broken: $(cat "$CASE/status")"
  [ ! -e "$FK/loaded/$lab" ] || fail "the job is loaded"
  A "$m"; eq $? 0 "the next command settles the broken folder"
  plist_is "$lab" "$CASE/before.plist" "settled"
  [ ! -e "$f/adopt.failed" ] && [ ! -e "$f/plist.prev" ] && [ ! -e "$f/pending" ] || fail "leftovers after the settling"
  new_case
  put brain-cron; lab=$LAB; f="$RD/brain-cron"
  A "$lab" || fail "setup"
  cp "$AG/$lab.plist" "$CASE/before.plist"
  FAKE_LCTL_FAIL="bootstrap:*" Rl "$lab"; eq $? 1 "release with a failing restore"
  cmp -s "$f/plist.prev" "$CASE/before.plist" || fail "release: plist.prev is not the adopted plist"
  [ -e "$f/adopt.failed" ] || fail "release: no adopt.failed"
  [ -f "$f/routine.json" ] || fail "release: the manifest was touched"
}

t_status_states() {
  new_case
  put brain-cron; local c=$LAB
  put brain-consolidate; local r=$LAB
  put docs-pr-sync; local u=$LAB
  put mac-cleanup; local i=$LAB
  A "$c" || fail "setup"
  A "$r" || fail "setup"; Rl "$r" || fail "setup"
  A "$u" || fail "setup"; hand_rewrite "$u"
  held verified adopt "$i"; kill_held
  mkdir -p "$RD/fleet-improvement"
  printf '{"v":1,"name":"fleet-improvement","label":"com.tonours.fleet-improvement","source":"native"}\n' >"$RD/fleet-improvement/routine.json"
  S; eq $? 0 "status exit"
  grep -q "^brain-cron adopted $c (loaded)$" "$CASE/status" || fail "adopted: $(cat "$CASE/status")"
  grep -q "^brain-consolidate released $r$" "$CASE/status" || fail "released: $(cat "$CASE/status")"
  grep -q "^docs-pr-sync unwrapped $u " "$CASE/status" || fail "unwrapped: $(cat "$CASE/status")"
  grep -q "^mac-cleanup incomplete $i (adopt)$" "$CASE/status" || fail "incomplete: $(cat "$CASE/status")"
  grep -q "^fleet-improvement native com.tonours.fleet-improvement$" "$CASE/status" || fail "native: $(cat "$CASE/status")"
  grep -q "^lock: ok$" "$CASE/status" || fail "lock line: $(cat "$CASE/status")"
  lctl bootout "gui/501/$c"
  S; grep -q "^brain-cron adopted $c (not loaded)$" "$CASE/status" || fail "not loaded: $(cat "$CASE/status")"
  eq "$(grep -vc '^lock:' "$CASE/status")" 5 "one line per routine"
  [ -e "$RD/mac-cleanup/pending" ] || fail "status settled a folder"
}

t_lock_check_refuses() {
  new_case
  put brain-cron; local lab=$LAB n0
  printf '#!/bin/sh\nexit 1\n' >"$CASE/perl-stub"; chmod +x "$CASE/perl-stub"
  n0=$(ncalls)
  ROUTINE_TEST_PERL="$CASE/perl-stub" A "$lab"; eq $? 74 "adopt with a failing lock line"
  [ ! -e "$RD" ] || fail "something was written: $(ls -A "$RD")"
  eq "$(ncalls)" "$n0" "launchctl calls"
  ROUTINE_TEST_PERL="$CASE/perl-stub" Rl "$lab"; eq $? 74 "release with a failing lock line"
  [ ! -e "$RD" ] || fail "something was written by release"
  ROUTINE_TEST_PERL="$CASE/perl-stub" S; eq $? 74 "status with a failing lock line"
  grep -q "^lock: failing" "$CASE/status" || fail "status does not say the lock fails: $(cat "$CASE/status")"
  cmp -s "$AG/$lab.plist" "$CASE/orig.$lab" || fail "the plist changed"
}

t_release_needs_a_saved_plist() {
  new_case
  put brain-cron; local lab=$LAB f="$RD/brain-cron"
  Rl "$lab"; eq $? 2 "release of a label that is not adopted"
  A "$lab" || fail "adopt"
  cp "$AG/$lab.plist" "$CASE/before.plist"
  rm -f "$f/$(mval "$f/routine.json" origin)"
  reset_calls
  Rl "$lab"; eq $? 2 "release without a saved plist"
  untouched "$lab" "release"
  plist_is "$lab" "$CASE/before.plist" "release"
  [ -f "$f/routine.json" ] || fail "the manifest was deleted"
  new_case
  put brain-cron; lab=$LAB
  A "$lab" || fail "adopt"; Rl "$lab" || fail "release"
  Rl "$lab"; eq $? 2 "release of a released label"
}

t_release_refuses_unwrapped() {
  new_case
  put brain-cron; local lab=$LAB f="$RD/brain-cron" s0
  A "$lab" || fail "adopt"
  hand_rewrite "$lab"
  cp "$AG/$lab.plist" "$CASE/P1"
  s0=$(snap "$f")
  reset_calls
  Rl "$lab"; eq $? 2 "release of an unwrapped routine"
  grep -qw adopt "$CASE/err" || fail "the refusal does not tell to run adopt: $(cat "$CASE/err")"
  untouched "$lab" "release unwrapped"
  plist_is "$lab" "$CASE/P1" "release unwrapped"
  eq "$(snap "$f")" "$s0" "the folder"
  A "$lab"; eq $? 0 "adopt again"
  Rl "$lab"; eq $? 0 "release"
  plist_is "$lab" "$CASE/P1" "released after adopt again"
}

t_tz_from_the_system() {
  new_case
  local want t
  t=$(readlink /etc/localtime 2>/dev/null) || t=""
  case "$t" in
    *zoneinfo/*)
      want="${t#*zoneinfo/}"
      put brain-cron
      ( unset ROUTINE_TZ; A "$LAB" ) || fail "adopt with the system time zone"
      has "$RD/brain-cron/routine.json" "\"tz\":\"$want\"" "tz" ;;
    *) printf '    (no /etc/localtime link to read: skipped)\n' ;;
  esac
}

E() { "$EDITOR_ENTRY" "$@" >"$CASE/out" 2>"$CASE/err"; }

editor_setup() {
  new_case
  mkdir -p "$CASE/home/.claude/scripts"
  ln -s "${R%/*}" "$CASE/home/.claude/scripts/routine"
  EDITOR_ENTRY="$CASE/home/.claude/scripts/routine/routine.sh"
  make_start adopted
  M="$RD/$NAME/routine.json"
  E editor "$NAME" || fail "open: $(cat "$CASE/out" "$CASE/err")"
  REV=$(mval "$CASE/out" revision)
  eq "$REV" "$(/usr/bin/perl -MDigest::SHA -0777 -ne 'print Digest::SHA::sha256_hex($_)' "$M")" "raw revision"
  reset_calls
}

t_editor_roundtrip() {
  editor_setup
  E capabilities || fail "probe"; has "$CASE/out" '"routine_editor":1' "capability"
  chmod 600 "$M"
  local desc='{"description":"Quoted \"note\" 🍋"}'
  E edit "$NAME" "$REV" "$desc" || fail "description: $(cat "$CASE/out")"
  has "$CASE/out" '"status":"applied"' "saved"
  eq "$(/usr/bin/perl -e 'printf "%03o", (stat $ARGV[0])[2]&0777' "$M")" 600 "preserve manifest permissions"
  untouched "$L" "description"
  E editor "$NAME" || fail "reopen"
  has "$CASE/out" 'Quoted \"note\" 🍋' "escaped description"
  REV=$(mval "$CASE/out" revision)
  local change='{"slots":[{"hour":0,"minute":59,"weekday":7},{"weekday":0,"minute":59,"hour":0},{"hour":3,"minute":0,"weekday":3}]}'
  E edit "$NAME" "$REV" "$change" || fail "calendar: $(cat "$CASE/out" "$CASE/err")"
  local next=$(mval "$CASE/out" revision)
  eq "$(grep -c '^bootstrap ' "$FK/calls")" 1 "single reload"
  E edit "$NAME" "$REV" "$change" && fail "stale retry accepted"
  has "$CASE/out" '"code":"conflict"' "retry"
  E edit "$NAME" "$next" "$change" || fail "unchanged"
  has "$CASE/out" '"status":"unchanged"' "no-op"
  eq "$(grep -c '^bootstrap ' "$FK/calls")" 1 "no second reload"
  wrapped_ok "$L" "$NAME"
  eq "$(pbt 'Print :StartCalendarInterval:0:Weekday' "$FK/loaded/$L")" 0 "Sunday"
  ! pbt 'Print :StartCalendarInterval:2' "$FK/loaded/$L" || fail "duplicate calendar"
  A "$L" || fail "refresh"; has "$M" 'Quoted \"note\" 🍋' "refresh description"
  Rl "$L" || fail "release"
  eq "$(pbt 'Print :StartCalendarInterval:1:Hour' "$FK/loaded/$L")" 3 "released slots"
  eq "$(pbt 'Print :ProgramArguments:1' "$FK/loaded/$L")" "/Users/me/work/brain/_meta/cron-run.sh" "released command"
  A "$L" || fail "readopt"
  E editor "$NAME" || fail "reopen after readoption"
  has "$CASE/out" 'Quoted \"note\" 🍋' "readopted description"
}

t_editor_refusals() {
  editor_setup
  local change
  for change in '{"slots":[]}' '{"slots":[{"hour":1,"minute":0}]}' '{"slots":[{"hour":2,"minute":59}]}' \
      '{"slots":[{"hour":"8","minute":0}]}' '{"slots":[{"hour":8,"minute":60}]}' '{"description":"bad\nline"}' \
      '{"command":"bad"}' '{"slots":[{"hour":8,"minute":0,"other":0}]}'; do
    E edit "$NAME" "$REV" "$change" && fail "accepted $change"
    has "$CASE/out" '"code":"invalid"' "rejection"
  done
  eq "$(ncalls)" 0 "invalid input before launchctl"
  cp "$M" "$CASE/initial"
  local where
  for where in "$FK/loaded/$L" "$AG/$L.plist"; do
    cp "$where" "$CASE/clean"
    pbt 'Set :StartCalendarInterval:Hour 16' "$where"
    E edit "$NAME" "$REV" '{"description":"new"}' && fail "accepted drift"
    has "$CASE/out" '"code":"conflict"' "calendar drift"
    Rl "$L"; eq $? 2 "release refuses calendar drift in either copy"
    cp "$CASE/clean" "$where"
    pbt 'Set :ProgramArguments:6 /different' "$where"
    E editor "$NAME" && fail "accepted argument drift"
    cp "$CASE/clean" "$where"
  done
  ROUTINE_TZ=Etc/UTC E editor "$NAME" && fail "accepted stale producer timezone"
  has "$CASE/out" '"code":"conflict"' "time zone"
  : >"$FK/running/$L"
  E edit "$NAME" "$REV" '{"description":"new"}'; eq $? 75 "active"
  untouched "$L" "drift"
  cmp -s "$CASE/initial" "$M" || fail "manifest changed"
  mkdir -p "$RD/external"
  echo '{"source":"install"}' >"$RD/external/routine.json"
  E editor external && fail "accepted folder installer"
  has "$CASE/out" '"code":"unsupported"' "installation"
}

t_editor_busy_boundaries() {
  editor_setup
  local change='{"slots":[{"hour":18,"minute":30}]}'
  echo "1 17 51" >"$CASE/clock"
  E edit "$NAME" "$REV" "$change"; eq $? 75 "old calendar nine minutes away"
  echo "1 18 21" >"$CASE/clock"
  E edit "$NAME" "$REV" "$change"; eq $? 75 "new calendar nine minutes away"
  local minute
  for minute in '17 56' '18 26'; do
    echo "1 17 50" >"$CASE/clock"
    held staged edit "$NAME" "$REV" "$change"
    E editor "$NAME"; eq $? 75 "owner lock"
    echo "1 $minute" >"$CASE/clock"
    : >"$CASE/h"; wait "$BGPID"; eq $? 75 "four minutes to old or new"
  done
  untouched "$L" "margin"
  echo "1 18 20" >"$CASE/clock"
  held staged edit "$NAME" "$REV" "$change"
  echo "1 18 25" >"$CASE/clock"; : >"$CASE/h"; wait "$BGPID"; eq $? 0 "ten and five are allowed"
}

t_editor_uses_producer_clock() {
  editor_setup
  # Pick a fixed-offset zone where the current hour and next hour are both
  # valid for a wrapped job. Send the request from a different local clock.
  local zone hour minute now target change caller
  for zone in Etc/UTC Etc/GMT+8 Etc/GMT-8; do
    now=$(TZ="$zone" date '+%H %M'); read -r hour minute <<<"$now"
    [ "$((10#$hour))" -ge 4 ] && [ "$((10#$hour))" -lt 22 ] && break
  done
  export ROUTINE_TZ="$zone"
  A "$L" || fail "refresh producer timezone"
  E editor "$NAME" || fail "reopen"
  REV=$(mval "$CASE/out" revision)
  target=$((10#$hour * 60 + 10#$minute + 3))
  change=$(printf '{"slots":[{"hour":%s,"minute":%s}]}' "$((target / 60))" "$((target % 60))")
  for caller in Etc/UTC Etc/GMT+8 Etc/GMT-8; do
    [ "$caller" != "$zone" ] && [ "$(TZ="$caller" date +%H)" != 17 ] && break
  done
  unset ROUTINE_TEST_CLOCK
  reset_calls
  TZ="$caller" E edit "$NAME" "$REV" "$change"; eq $? 75 "three minutes on producer clock"
  untouched "$L" "producer timezone"
}

t_editor_elapsed_margins() {
  editor_setup
  local change='{"slots":[{"hour":3,"minute":0}]}'
  export ROUTINE_TZ=Europe/Paris
  A "$L" || fail "refresh timezone"
  E editor "$NAME" || fail "open"
  REV=$(mval "$CASE/out" revision)
  # 2027-03-28 01:59:30 CET, followed by 03:00 CEST in 30 seconds.
  echo 1806195570 >"$CASE/clock"
  E edit "$NAME" "$REV" "$change"; eq $? 75 "DST margin"
  # Same Sunday in winter, 17:50:01 in Paris. The original 18:00 is 599s away.
  echo 1800809401 >"$CASE/clock"
  E edit "$NAME" "$REV" "$change"; eq $? 75 "partial-minute margin"
  untouched "$L" "elapsed-time refusal"
}

t_editor_rechecks_identity_and_run_lock() {
  editor_setup
  local f="$RD/$NAME"
  # A wrapper child can outlive the process launchctl knew about.
  exec 7>>"$f/run.lock"
  /usr/bin/perl -MFcntl=:flock -e 'open(my $h, ">&=", 7) or exit 1; flock($h, LOCK_EX|LOCK_NB) or exit 1' || fail "lock run"
  E edit "$NAME" "$REV" '{"description":"new"}'; eq $? 75 "orphan run"
  exec 7>&-
  held staged edit "$NAME" "$REV" '{"slots":[{"hour":23,"minute":58}]}'
  pbt 'Set :StartCalendarInterval:Hour 16' "$FK/loaded/$L"
  : >"$CASE/h"; wait "$BGPID" && fail "saved over loaded drift"
  has "$CASE/out.h" '"code":"conflict"' "recheck under lock"
  cp "$AG/$L.plist" "$FK/loaded/$L"
  held verified edit "$NAME" "$REV" '{"description":"new"}'
  printf '\n' >>"$M"
  : >"$CASE/h"; wait "$BGPID" && fail "stale description published"
  has "$CASE/out.h" '"code":"conflict"' "atomic description"
  untouched "$L" "late refusal"
}

t_editor_verified_calendar_drift() {
  editor_setup
  local change='{"slots":[{"hour":13,"minute":42}]}'
  cp "$AG/$L.plist" "$CASE/initial"
  held verified edit "$NAME" "$REV" "$change"
  printf '\n' >>"$M"
  : >"$CASE/h"; wait "$BGPID" && fail "accepted changed manifest after reload"
  has "$CASE/out.h" '"code":"conflict"' "late manifest conflict after restoration"
  plist_is "$L" "$CASE/initial" "restored calendar"
  E editor "$NAME" || fail "reopen"
  REV=$(mval "$CASE/out" revision)
  held verified edit "$NAME" "$REV" "$change"
  pbt 'Set :StartCalendarInterval:0:Minute 23' "$FK/loaded/$L"
  : >"$CASE/h"; wait "$BGPID" && fail "published an unverified loaded calendar"
  has "$CASE/out.h" '"code":"recovery"' "unsettled loaded drift"
  [ -e "$RD/$NAME/pending" ] || fail "lost recovery evidence"
}

t_editor_description_limit() {
  editor_setup
  local value
  value=$(/usr/bin/perl -e 'print "🍋" x 200')
  E edit "$NAME" "$REV" "{\"description\":\"$value🍋\"}" && fail "201 characters"
  eq "$(ncalls)" 0 "oversized description"
  E edit "$NAME" "$REV" "{\"description\":\"$value\"}" || fail "200 characters"
  REV=$(mval "$CASE/out" revision)
  E edit "$NAME" "$REV" '{"description":""}' || fail "clear"
  has "$CASE/out" '"description":""' "empty"
  untouched "$L" "text only"
}

t_editor_failure_and_crash() {
  editor_setup
  local change='{"slots":[{"hour":13,"minute":42}]}'
  cp "$AG/$L.plist" "$CASE/initial"
  FAKE_LCTL_FAIL="$(fail_next bootstrap)" E edit "$NAME" "$REV" "$change" && fail "accepted failed reload"
  has "$CASE/out" '"code":"apply"' "rolled back"
  plist_is "$L" "$CASE/initial" "failed bootstrap"
  FAKE_LCTL_FAIL="bootstrap:*" E edit "$NAME" "$REV" "$change" && fail "accepted broken restore"
  has "$CASE/out" '"code":"recovery"' "failed rollback"
  [ -f "$RD/$NAME/adopt.failed" ] || fail "missing manual recovery instructions"
  held verified edit "$NAME" "$REV" "$change"; kill_held
  reset_calls
  local unrelated
  unrelated=$(printf '%064d' 7)
  E edit "$NAME" "$unrelated" "$change" && fail "unrelated stale request settled the transaction"
  has "$CASE/out" '"code":"conflict"' "unrelated revision"
  untouched "$L" "stale recovery"
  FAKE_LCTL_FAIL="print:*" E edit "$NAME" "$REV" "$change" && fail "indeterminate print treated as absent"
  has "$CASE/out" '"code":"recovery"' "indeterminate service"
  cmp -s "$AG/$L.plist" "$FK/loaded/$L" || fail "disk changed after failed service check"
  untouched "$L" "indeterminate service"
  reset_calls
  E editor "$NAME" || fail "read pending preview"
  has "$CASE/out" '"pendingChanges":{"slots"' "pending calendar"
  untouched "$L" "passive preview"
  echo "1 13 40" >"$CASE/clock"
  E edit "$NAME" "$REV" "$change" && fail "settled too near the new slot"
  untouched "$L" "settlement margin"
  echo "1 12 0" >"$CASE/clock"
  held committed edit "$NAME" "$REV" "$change"; kill_held
  reset_calls
  E edit "$NAME" "$REV" "$change" && fail "stale after lost reply"
  has "$CASE/out" '"code":"conflict"' "lost reply"
  E editor "$NAME" || fail "settled read"
  has "$CASE/out" '"minute":42' "committed calendar"
  untouched "$L" "committed retry"
}

t_editor_registry_identity() {
  editor_setup
  cp -R "$RD" "$CASE/copy"
  ETABLI_ROUTINES_DIR="$CASE/copy" E editor "$NAME" && fail "opened copied record"
  ETABLI_ROUTINES_DIR="$CASE/copy" E edit "$NAME" "$REV" '{"description":"copy"}' && fail "edited copied record"
  [ ! -e "$CASE/copy/$NAME/run.lock" ] || fail "opened the wrong run lock"
  printf '\t\tETABLI_ROUTINES_DIR => %s\n' "$CASE/copy" >"$FK/domain-env"
  E edit "$NAME" "$REV" '{"slots":[{"hour":13,"minute":42}]}' && fail "unloaded despite changed domain"
  rm "$FK/domain-env"
  pbt 'Add :EnvironmentVariables dict' "$FK/loaded/$L"
  pbt "Add :EnvironmentVariables:ETABLI_ROUTINES_DIR string $CASE/copy" "$FK/loaded/$L"
  ETABLI_ROUTINES_DIR="$CASE/copy" E editor "$NAME" && fail "ignored the registry used after bootstrap"
  cp "$AG/$L.plist" "$FK/loaded/$L"
  untouched "$L" "copied registry"
  printf '\t\tHOME => %s\n' "$CASE/job home" >"$FK/inherited"
  mkdir -p "$CASE/job home/.claude/state"
  mv "$RD" "$CASE/job home/.claude/state/routines"
  ETABLI_ROUTINES_DIR="$CASE/job home/.claude/state/routines" E editor "$NAME" || fail "job HOME"
  printf '\t\tETABLI_ROUTINES_DIR => relative\n' >"$FK/inherited"
  ETABLI_ROUTINES_DIR="$CASE/job home/.claude/state/routines" E editor "$NAME" && fail "unproven registry"
  has "$CASE/out" '"code":"conflict"' "relative registry"
}

t_editor_plist_environment() {
  new_case
  put brain-cron
  L=$LAB; NAME=brain-cron; EDITOR_ENTRY=$R
  lctl bootout "gui/501/$L" || fail "setup"
  pbt 'Add :EnvironmentVariables dict' "$AG/$L.plist" &&
    pbt "Add :EnvironmentVariables:ETABLI_ROUTINES_DIR string $RD" "$AG/$L.plist" || fail "setup environment"
  lctl bootstrap gui/501 "$AG/$L.plist" && A "$L" || fail "setup adoption"
  printf '\t\tETABLI_ROUTINES_DIR => %s\n' "$CASE/other" >"$FK/inherited"
  E editor "$NAME" || fail "honor job override"
  pbt 'Set :EnvironmentVariables:ETABLI_ROUTINES_DIR /different' "$FK/loaded/$L"
  E editor "$NAME" && fail "ignored loaded override"
  has "$CASE/out" '"code":"conflict"' "loaded environment drift"
}

t_editor_pending_description_and_copy() {
  editor_setup
  held verified edit "$NAME" "$REV" '{"description":"text"}'; kill_held
  cp -R "$RD" "$CASE/copy"
  rm "$CASE/copy/$NAME/run.lock"
  ETABLI_ROUTINES_DIR="$CASE/copy" E editor "$NAME" && fail "previewed copied receipt"
  ETABLI_ROUTINES_DIR="$CASE/copy" E edit "$NAME" "$REV" '{"description":"text"}' && fail "confirmed copied receipt"
  ETABLI_ROUTINES_DIR="$CASE/copy" A "$L" && fail "owner settled copied receipt"
  [ ! -e "$CASE/copy/$NAME/run.lock" ] || fail "used copied run lock"
  E editor "$NAME" || fail "preview description"
  has "$CASE/out" '"pendingChanges":{"description":"text"}' "only changed fields"
  E edit "$NAME" "$REV" '{"description":"text"}' || fail "publish description"
  untouched "$L" "description crash and retry"
}

t_editor_initial_description_receipt() {
  editor_setup
  held edit-intent edit "$NAME" "$REV" '{"description":"requested"}'; kill_held
  E editor "$NAME" || fail "reopen initial description intent"
  has "$CASE/out" '"pendingChanges":{"description":"requested"}' "original request"
  E edit "$NAME" "$REV" '{"description":"requested"}' || fail "resume initial description"
  untouched "$L" "description-only staging"
}

t_editor_interrupted_preview() {
  local pt change='{"description":"updated","slots":[{"hour":13,"minute":42}]}'
  for pt in edit-intent edit-manifest-staged staged unloaded moved-swap bootstrapped verified; do
    editor_setup
    held "$pt" edit "$NAME" "$REV" "$change"; kill_held
    local snapshot=$(snap "$RD")
    E editor "$NAME" || fail "preview $pt: $(cat "$CASE/out")"
    eq "$(mval "$CASE/out" revision)" "$REV" "base revision"
    /usr/bin/perl -MJSON::PP -0777 -ne '
      $r=decode_json($_); exit !($r->{fields}{description} eq "" && $r->{fields}{slots}[0]{hour} == 18 &&
        $r->{pendingChanges}{description} eq "updated" && $r->{pendingChanges}{slots}[0]{minute} == 42)
    ' "$CASE/out" || fail "preview fields at $pt"
    eq "$(snap "$RD")" "$snapshot" "passive preview"
    E edit "$NAME" "$REV" '{"description":"other"}' && fail "accepted different retry"
    E edit "$NAME" "$REV" "$change" || fail "resume $pt: $(cat "$CASE/out" "$CASE/err")"
    eq "$(grep -c '^bootout ' "$FK/calls")" 1 "one unload across $pt and retry"
    eq "$(grep -c '^bootstrap ' "$FK/calls")" 1 "one bootstrap across $pt and retry"
    E editor "$NAME" || fail "reopen"
    has "$CASE/out" '"description":"updated"' "published description"
  done
}

t_editor_recovers_failed_rollback() {
  editor_setup
  local change='{"slots":[{"hour":13,"minute":42}]}'
  FAKE_LCTL_FAIL='bootstrap:*' E edit "$NAME" "$REV" "$change" && fail "accepted failed restore"
  [ -f "$RD/$NAME/adopt.failed" ] || fail "missing failed restore record"
  E editor "$NAME" || fail "preview failed restore"
  E edit "$NAME" "$REV" "$change" || fail "resume failed restore"
  [ ! -e "$RD/$NAME/adopt.failed" ] || fail "orphan failed restore record"
  E editor "$NAME" || fail "reopen after failed restore"
  has "$CASE/out" '"minute":42' "effective schedule"
}

t_editor_published_pending() {
  local pt rev state
  for pt in committed prev-deleted; do
    editor_setup
    held "$pt" edit "$NAME" "$REV" '{"slots":[{"hour":13,"minute":42}]}'; kill_held
    state=$(snap "$RD")
    E editor "$NAME" || fail "open after $pt"
    rev=$(mval "$CASE/out" revision)
    [ "$rev" != "$REV" ] && ! grep -q pendingChanges "$CASE/out" || fail "published preview"
    has "$CASE/out" '"minute":42' "effective fields"
    eq "$(snap "$RD")" "$state" "read leaves cleanup pending"
    E edit "$NAME" "$rev" '{"description":"follow-up"}' || fail "fresh save after $pt: $(cat "$CASE/out")"
    [ ! -e "$RD/$NAME/pending" ] || fail "cleanup incomplete"
    has "$M" '"description":"follow-up"' "fresh edit"
    eq "$(grep -c '^bootout ' "$FK/calls")" 1 "one unload through fresh edit"
    eq "$(grep -c '^bootstrap ' "$FK/calls")" 1 "one bootstrap through fresh edit"
  done
}

t_editor_unloaded_registry_drift() {
  editor_setup
  held moved-swap edit "$NAME" "$REV" '{"slots":[{"hour":13,"minute":42}]}'; kill_held
  printf '\t\tETABLI_ROUTINES_DIR => %s\n' "$CASE/elsewhere" >"$FK/inherited"
  E editor "$NAME" && fail "accepted changed domain environment"
  E edit "$NAME" "$REV" '{"slots":[{"hour":13,"minute":42}]}' && fail "bootstrapped with wrong registry"
  A "$L" && fail "rolled back with wrong registry"
  [ -f "$RD/$NAME/pending" ] && [ ! -f "$FK/loaded/$L" ] || fail "lost evidence"
}

t_editor_damaged_recovery() {
  local artifact change='{"slots":[{"hour":13,"minute":42}]}'
  for artifact in plist.prev plist.next routine.json.next pending; do
    editor_setup
    held verified edit "$NAME" "$REV" "$change"; kill_held
    case "$artifact" in
      pending) sed -n '1,3p' "$RD/$NAME/pending" >"$CASE/legacy"; cp "$CASE/legacy" "$RD/$NAME/pending" ;;
      routine.json.next) echo >>"$RD/$NAME/$artifact" ;;
      *) pbt 'Set :ProgramArguments:6 /damaged' "$RD/$NAME/$artifact" || fail "damage $artifact" ;;
    esac
    reset_calls
    E editor "$NAME" && fail "previewed damaged $artifact"
    E edit "$NAME" "$REV" "$change" && fail "resumed damaged $artifact"
    has "$CASE/out" '"code":"recovery"' "damaged proof"
    A "$L" && fail "owner settled damaged $artifact"
    untouched "$L" "$artifact"
    [ -e "$RD/$NAME/pending" ] || fail "lost evidence"
  done
}

t_editor_unloaded_plist_drift() {
  local pt
  for pt in unloaded moved-swap; do
    editor_setup
    held "$pt" edit "$NAME" "$REV" '{"slots":[{"hour":13,"minute":42}]}'
    printf '\n' >>"$AG/$L.plist"
    cp "$AG/$L.plist" "$CASE/independent"
    : >"$CASE/h"; wait "$BGPID" && fail "accepted independent edit at $pt"
    cmp -s "$AG/$L.plist" "$CASE/independent" || fail "lost independent bytes"
    has "$CASE/out.h" '"code":"recovery"' "disk drift at $pt"
    [ -f "$RD/$NAME/pending" ] && [ ! -e "$FK/loaded/$L" ] || fail "missing recovery state"
  done
}

t_release_refuses_changed_origin_before_bootout() {
  local origin
  editor_setup
  origin="$RD/$NAME/$(mval "$M" origin)"
  held staging release "$L"
  pbt 'Set :ProgramArguments:1 changed' "$origin" || fail "fixture origin command"
  touch "$CASE/h"
  wait "$BGPID" && fail "released changed arguments"
  untouched "$L" "staged command"
  editor_setup
  origin="$RD/$NAME/$(mval "$M" origin)"
  pbt 'Add :WorkingDirectory string /private/tmp' "$origin" || fail "fixture origin setting"
  Rl "$L" && fail "released unsupported saved setting"
  untouched "$L" "unsupported saved setting"
}

t_release_late_loaded_drift() {
  local drift
  for drift in 'Set :ProgramArguments:1 /independent' 'Set :StartCalendarInterval:0:Minute 5'; do
    editor_setup
    E edit "$NAME" "$REV" '{"slots":[{"hour":13,"minute":42}]}' || fail "setup change"
    held verified release "$L"
    pbt "$drift" "$FK/loaded/$L" || fail "damage loaded service"
    reset_calls
    : >"$CASE/h"; wait "$BGPID" && fail "retired manifest after drift"
    A "$L" && fail "restored over unfamiliar service"
    [ -f "$M" ] && [ -f "$RD/$NAME/pending" ] || fail "lost release evidence"
    untouched "$L" "release drift"
  done
}

t_bash32_and_no_jq() {
  local body
  body=$(grep -vE "^[[:space:]]*#" "$R")
  ! printf '%s\n' "$body" | grep -nE 'declare -A|local -A|BASHPID|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|\bjq\b|&>>?|\|&' || fail "the script uses something outside bash 3.2 or jq"
  ! printf '%s\n' "$body" | grep -nE '(^|[[:space:]])(claude|codex)[[:space:]]+-' || fail "the script calls a model"
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
printf 'routine adopt smoke: ok%s\n' "$([ "$REAL" = 1 ] && echo ' (real PlistBuddy and plutil)')"
