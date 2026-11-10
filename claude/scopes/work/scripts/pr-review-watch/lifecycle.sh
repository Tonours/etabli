#!/bin/bash

process_matches() {
  local pid="$1" key="$2" command
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
  command="$(ps -p "$pid" -o command= 2>/dev/null)" || return 1
  perl -MCwd=abs_path -MFile::Basename=dirname,basename -e '
    my ($key, $command) = @ARGV;
    $command =~ m{(?:^| )(?:[^ ]*/)?(?:review-run|launch-run)\.sh(?: |$)} or exit 1;
    index("$command ", " $key ") >= 0 and exit 0;
    my $parent = abs_path(dirname($key)); defined $parent or exit 1;
    my $name = basename($key); my $canonical = "$parent/$name";
    while ($command =~ m{/\Q$name\E(?= |$)}g) {
      my $end = pos($command);
      my $prefix = substr($command, 0, $end);
      while ($prefix =~ m{ (?=/)}g) {
        my $candidate = substr($prefix, pos($prefix));
        my $dir = abs_path(dirname($candidate));
        defined $dir && "$dir/" . basename($candidate) eq $canonical and exit 0;
      }
    }
    exit 1;
  ' "$key" "$command"
}

run_alive() {
  local key="$1" pid
  pid="$(cat "$key.pid" 2>/dev/null)"
  process_matches "$pid" "$key" && return 0
  pid="$(cat "$key.execution/pid" 2>/dev/null)"
  [ "$pid" != "$$" ] || return 1
  process_matches "$pid" "$key" && return 0
  if [ -d "$key.execution" ]; then
    # A tick may hold the key briefly while publishing an import/reservation.
    if [ -n "$pid" ]; then
      ps -p "$pid" -o command= 2>/dev/null | grep -q '[/ ]watch\.sh' && return 0
    elif [ "$(perl -e 'print time - ((stat shift)[9] // 0)' "$key.execution")" -lt 60 ]; then return 0
    fi
  fi
  return 1
}

reservation_seconds() {
  local backoff="${RETRY_BACKOFF_SECONDS:-${PR_REVIEW_WATCH_RETRY_BACKOFF:-600}}"
  if [ "$backoff" -gt 180 ]; then echo "$backoff"; else echo 180; fi
}

execution_held() {
  local pid start current; pid="$(cat "$1.execution/pid" 2>/dev/null)"
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] && [ "$pid" != "$$" ] && kill -0 "$pid" 2>/dev/null || return 1
  start="$(cat "$1.execution/start" 2>/dev/null)"; current="$(LC_ALL=C ps -p "$pid" -o lstart= 2>/dev/null)" || return 0
  [ -z "$start" ] || [ "$start" = "$current" ]
}

run_reserved() {
  local key="$1" sha mode rc attempt
  run_alive "$key" && return 0
  execution_held "$key" && return 0
  [ -f "$key.status" ] || return 1
  IFS=$'\t' read -r sha mode rc attempt <"$key.status" || return 1
  [ "$rc" = running ] && [ "$(status_age "$key")" -lt "$(reservation_seconds)" ]
}

# Only the serialized watcher tick recovers dead locks. Runners never steal.
clear_dead_execution() (
  local generation
  [ -d "$1.execution" ] || return 0
  exec 9<"$1.execution" || return 1
  generation="$(perl -e '@s=stat shift; @s or exit 1; print "$s[0]:$s[1]"' /dev/fd/9)" || return 1
  run_alive "$1" && return 1
  execution_held "$1" && return 1
  [ "$generation" = "$(perl -e '@s=stat shift; @s or exit 1; print "$s[0]:$s[1]"' "$1.execution")" ] || return 1
  rm -rf "$1.execution"
)

take_execution() {
  mkdir "$1.execution" 2>/dev/null || return 1
  LC_ALL=C ps -p "$$" -o lstart= >"$1.execution/start" || return 1
  (set -C; printf '%s\n' "$$" >"$1.execution/pid")
}

release_execution() {
  [ "$(cat "$1.execution/pid" 2>/dev/null)" != "$$" ] || rm -rf "$1.execution"
}

write_run_status() {
  local key="$1" temp
  shift
  temp="$(mktemp "$key.status.XXXXXX")" || return 1
  printf '%s\t%s\t%s\t%s\n' "$@" >"$temp" && mv "$temp" "$key.status"
}
