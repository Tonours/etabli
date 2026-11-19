# Sourced by routine.sh. Uses the adoption transaction and its kernel lock.
editor_data() { /usr/bin/perl "${ROUTINE_SELF%/*}/editor.pl" "$@"; }

edit_error() { editor_data error "$1" "$2"; return "${3:-1}"; }

calendar_key() { LC_ALL=C /usr/bin/sort -u | /usr/bin/paste -sd '|' -; }

set_calendar() { # staged plist, normalized weekday/hour/minute lines
  local i=0 wd h m entry
  pb 'Delete :StartCalendarInterval' "$1" >/dev/null && pb 'Add :StartCalendarInterval array' "$1" >/dev/null || return 1
  while read -r wd h m; do
    entry=":StartCalendarInterval:$i"
    pb "Add $entry dict" "$1" >/dev/null && pb "Add $entry:Hour integer $h" "$1" >/dev/null &&
      pb "Add $entry:Minute integer $m" "$1" >/dev/null || return 1
    if [ "$wd" != n ]; then pb "Add $entry:Weekday integer $wd" "$1" >/dev/null || return 1; fi
    i=$((i + 1))
  done <<<"$2"
  "$PLUTIL" -lint "$1" >/dev/null
}

loaded_arguments_match() { # label, calendar key, arguments expected from disk
  local label="$1" key="$2"
  shift 2
  editor_data loaded "gui/$(user_id)/$label" "$(launch_dir)/$label.plist" "$key" "$@" <<<"$JOB_OUT" >/dev/null
}

loaded_matches() { # expected plist, calendar key. JOB_OUT comes from job_state.
  local label
  label=$(pb 'Print :Label' "$1") || return 1
  read_args "$1"
  loaded_arguments_match "$label" "$2" "${PARGS[@]}"
}

# Roll back only a recognizable state of this swap. An externally replaced
# plist or a loaded job with different arguments/triggers needs owner repair.
restore_edit() {
  local label="$1" f="$2" margin="$3" dst prev_key disk_key calendars zone
  case "$label" in ''|*[!A-Za-z0-9._-]*|"$RESERVED_LABEL") return 1 ;; esac
  dst="$(launch_dir)/$label.plist"
  [ "$(pb 'Print :Label' "$f/plist.prev")" = "$label" ] && is_wrapped "$f/plist.prev" "${f##*/}" &&
    [ "${PARGS[1]}" -ef "$ROUTINE_SELF" ] && parse_slots "$f/plist.prev" || return 1
  prev_key=$(calendar_key <<<"$SLOTS")
  calendars="$SLOTS"
  if $CMP -s "$dst" "$f/plist.prev"; then
    disk_key="$prev_key"
  elif $CMP -s "$dst" "$f/plist.next" && parse_slots "$dst"; then
    disk_key=$(calendar_key <<<"$SLOTS")
    calendars="$calendars
$SLOTS"
  else
    return 1
  fi
  local rc
  job_state "$label"; rc=$?
  [ "$rc" = 0 ] || [ "$rc" = 113 ] || return 1
  if [ "$JOB_LOADED" = 1 ]; then
    loaded_matches "$dst" "$disk_key" || return 1
    $CMP -s "$dst" "$f/plist.prev" && return 0
    SLOTS="$calendars"
    zone=$(system_tz) || return 1
    if [ "$JOB_RUNNING" = 1 ] || TZ="$zone" slot_within "$margin"; then return 2; fi
    "$LCTL" bootout "gui/$(user_id)/$label" >/dev/null 2>&1 || return 1
  fi
  install_plist "$f/plist.prev" "$label" &&
    "$LCTL" bootstrap "gui/$(user_id)" "$dst" >/dev/null 2>&1 &&
    job_state "$label" && $CMP -s "$dst" "$f/plist.prev" && loaded_matches "$f/plist.prev" "$prev_key"
}

# Confirm the original command (every argument), the wrapper and both copies
# of the calendar. Refuse unfamiliar launchctl output as unverifiable.
verify_disk() {
  local origin="$C_FOLDER/$E_ORIGIN" i key saved active saved_status active_status
  [ -f "$E_PLIST" ] && [ -O "$E_PLIST" ] && [ ! -L "$E_PLIST" ] &&
    [ "$(/usr/bin/wc -c <"$E_PLIST")" -le "$PLIST_MAX_BYTES" ] || return 1
  [ -f "$origin" ] && [ -O "$origin" ] && [ ! -L "$origin" ] &&
    [ "$(pb 'Print :Label' "$origin")" = "$C_LABEL" ] || return 1
  validate_plist "$E_PLIST" "$C_LABEL" && [ "$(calendar_key <<<"$SLOTS")" = "$E_OLD" ] || return 1
  is_wrapped "$E_PLIST" "$C_NAME" && [ "${PARGS[1]}" -ef "$ROUTINE_SELF" ] || return 1
  # A calendar save reloads the complete plist. Preserve the adopted settings outside the calendar and wrapper.
  for key in StandardOutPath StandardErrorPath EnvironmentVariables RunAtLoad Nice LowPriorityIO; do
    saved=$(pb "Print :$key" "$origin"); saved_status=$?
    active=$(pb "Print :$key" "$E_PLIST"); active_status=$?
    [ "$saved_status" = "$active_status" ] && [ "$saved" = "$active" ] || return 1
  done
  E_ARGS=("${PARGS[@]}")
  read_args "$origin"
  [ "$PARGC" -gt 0 ] && [ "${#E_ARGS[@]}" -eq "$((PARGC + 5))" ] || return 1
  for ((i=0; i<PARGC; i++)); do [ "${E_ARGS[i+5]}" = "${PARGS[i]}" ] || return 1; done
  return 0
}

verify_edit_base() {
  E_ZONE=$(system_tz) || return 1
  [ "$(editor_data revision "$C_FOLDER/routine.json")" = "$E_REV" ] &&
    [ "$E_ZONE" = "$(manifest_get "$C_FOLDER/routine.json" tz)" ] && verify_disk &&
    job_state "$C_LABEL" && loaded_arguments_match "$C_LABEL" "$E_OLD" "${E_ARGS[@]}"
}

edit_margins() {
  SLOTS=$(printf '%s\n%s\n' "$E_OLD" "$E_NEW" | /usr/bin/tr '|' '\n')
  [ "$JOB_RUNNING" = 0 ] && ! TZ="$E_ZONE" slot_within "$1"
}

# A child of a killed wrapper can still hold run.lock after launchd reports
# the job idle. Keep the lock until the transaction or settlement completes.
lock_run_for_edit() {
  local lock="$C_FOLDER/run.lock" rc
  [ "${E_RUN_LOCKED:-0}" = 0 ] || return 0
  if [ -L "$lock" ] || { [ -e "$lock" ] && { [ ! -f "$lock" ] || [ ! -O "$lock" ]; }; } ||
     ! exec 8>>"$lock"; then edit_error recovery 'Check the run lock and its permissions.'; return 1; fi
  routine_lock_try 8; rc=$?
  if [ "$rc" = 75 ]; then edit_error busy 'The routine still has an active run. Retry after it ends.' 75; return $?; fi
  if [ "$rc" != 0 ]; then edit_error recovery 'Cannot verify the run lock. Check its permissions.'; return 1; fi
  E_RUN_LOCKED=1
}

cmd_editor() {
  local -a E_ARGS
  local E_ZONE E_RUN_LOCKED=0
  local op="$1" changes='{}' expected="" result response next rc f
  shift
  C_NAME="${1:-}"
  if ! valid_name "$C_NAME"; then edit_error invalid 'Supply a registered routine name.' 2; return $?; fi
  if [ "$op" = edit ]; then
    if [ "$#" != 3 ] || ! [[ $2 =~ ^[0-9a-f]{64}$ ]]; then edit_error invalid 'Supply the revision from editor and a JSON object of changes.' 2; return $?; fi
    expected="$2"
    changes=$(editor_data request "$3") || { printf '%s\n' "$changes"; return 2; }
  elif [ "$#" != 1 ]; then edit_error invalid 'Use editor <name>.' 2; return $?; fi

  dir=$(routines_dir)
  C_FOLDER="$dir/$C_NAME"
  local manifest="$C_FOLDER/routine.json"
  if [ ! -f "$manifest" ] && [ -f "$C_FOLDER/pending" ]; then
    edit_error recovery 'An adoption or release needs settlement. Retry the owner command first.'; return 1
  fi
  if [ "$C_NAME" = "$RESERVED_NAME" ] || [ ! -f "$manifest" ]; then
    edit_error unsupported 'Only registered, adopted Etabli jobs support this editor.' 2; return $?
  fi
  if [ ! -O "$dir" ] || [ -L "$dir" ] || [ ! -O "$C_FOLDER" ] || [ -L "$C_FOLDER" ] ||
     [ ! -O "$manifest" ] || [ -L "$manifest" ]; then
    edit_error conflict 'Check ownership and replace linked routine records before editing.'; return 1
  fi
  local source
  source=$(manifest_get "$manifest" source) || { edit_error conflict 'Repair the unreadable manifest.'; return 1; }
  if [ "$source" != adopt ]; then
    edit_error unsupported 'Use the owning producer for this routine.' 2; return $?
  fi
  if [ -L "$dir/adopt.lock" ] || [ ! -f "$dir/adopt.lock" ] || [ ! -O "$dir/adopt.lock" ] || ! exec 9<"$dir/adopt.lock"; then
    edit_error recovery 'Check the adoption lock and its permissions.'; return 1
  fi
  routine_lock_try; rc=$?
  if [ "$rc" = 75 ]; then edit_error busy 'Another producer operation holds the lock. Retry shortly.' 75; return $?; fi
  if [ "$rc" != 0 ]; then edit_error recovery 'The producer lock failed. Check its permissions.'; return 1; fi
  for f in "$C_FOLDER"/*.next "$C_FOLDER"/{pending,plist.prev,adopt.failed}; do
    if [ -L "$f" ] || { [ -e "$f" ] && { [ ! -f "$f" ] || [ ! -O "$f" ] || [ ! -f "$C_FOLDER/pending" ]; }; }; then
      edit_error recovery 'Repair the unexpected adoption transaction files before retrying.'; return 1
    fi
  done
  if [ -e "$C_FOLDER/pending" ] || [ -e "$C_FOLDER/plist.prev" ] || [ -e "$C_FOLDER/adopt.failed" ]; then
    if [ "$op" != edit ] || [ "$(/usr/bin/head -n 1 "$C_FOLDER/pending" 2>/dev/null)" != edit ]; then
      edit_error recovery 'An interrupted operation needs settlement. Retry the save or run the owner adoption command when the job is idle.'; return 1
    fi
    local pending_after pending_before current candidate
    { IFS= read -r f; IFS= read -r pending_after; IFS= read -r pending_before; } <"$C_FOLDER/pending"
    current=$(editor_data revision "$manifest") || { edit_error recovery 'Repair the incomplete edit.'; return 1; }
    if [ "$expected" != "$pending_before" ]; then edit_error conflict 'Reopen the routine before retrying this edit.'; return 1; fi
    if [ "$current" = "$pending_before" ]; then
      candidate=$(editor_data inspect "$manifest" "$C_NAME" "$expected" "$changes") || { printf '%s\n' "$candidate"; return 1; }
      if [ "$(printf '%s\n' "$candidate" | /usr/bin/sed -n '6p')" != "$pending_after" ]; then
        edit_error conflict 'Retry the original pending change or reconcile the routine.'; return 1
      fi
    fi
    lock_run_for_edit || return $?
    settle_folder "$C_FOLDER" || { edit_error recovery 'Cannot safely settle the previous edit. Check status and retry when idle.'; return 1; }
  fi
  C_KIND=edit
  result=$(editor_data inspect "$manifest" "$C_NAME" "$expected" "$changes") || { printf '%s\n' "$result"; return 1; }
  {
    IFS= read -r C_LABEL; IFS= read -r E_ORIGIN; IFS= read -r E_REV
    IFS= read -r E_OLD; IFS= read -r E_NEW; IFS= read -r C_ID
    IFS= read -r response; IFS= read -r next || true
  } <<<"$result"
  E_PLIST="$(launch_dir)/$C_LABEL.plist"
  if ! verify_edit_base; then
    edit_error conflict 'The job, plist, time zone or saved adoption identity differs. Reconcile the adoption before editing.'; return 1
  fi
  if [ "$op" = editor ]; then printf '%s\n' "$response"; return 0; fi

  if ! edit_margins 10; then
    edit_error busy 'Retry when the job is idle and both calendars are at least ten minutes away.' 75; return $?
  fi
  if [ -n "$next" ] || [ -e "$C_FOLDER/run.lock" ]; then lock_run_for_edit || return $?; fi
  if [ -z "$next" ]; then printf '%s\n' "$response"; return 0; fi
  C_PHASE=staging
  trap 'on_cmd_signal 143' TERM
  trap 'on_cmd_signal 130' INT
  trap 'on_cmd_signal 129' HUP
  if ! printf 'edit\n%s\n%s\n' "$C_ID" "$E_REV" >"$C_FOLDER/pending" ||
     ! (umask 077; printf '%s\n' "$next" >"$C_FOLDER/routine.json.next") ||
     ! /usr/bin/perl -e 'my @s=stat $ARGV[0]; @s && chmod($s[2]&0777, $ARGV[1]) or exit 1' "$manifest" "$C_FOLDER/routine.json.next"; then
    stage_fail "cannot stage the manifest"; edit_error apply 'Check the records directory permissions and retry.'; return 1
  fi
  if [ "$E_NEW" != "$E_OLD" ]; then
    if ! save_prev "$E_PLIST" "$C_FOLDER" || ! /bin/cp "$C_FOLDER/plist.prev" "$C_FOLDER/plist.next" ||
       ! set_calendar "$C_FOLDER/plist.next" "$(printf '%s' "$E_NEW" | /usr/bin/tr '|' '\n')" ||
       [ "$(/usr/bin/wc -c <"$C_FOLDER/plist.next")" -gt "$PLIST_MAX_BYTES" ]; then
      stage_fail "cannot stage the calendar"; edit_error apply 'Check the size and permissions of the staged plist.'; return 1
    fi
    hold staged
    swap_job "$C_FOLDER/plist.next" edit; rc=$?
    case "$rc" in
      0) ;;
      2) edit_error busy 'The job started or a calendar slot is now near. Retry later.' 75; return $? ;;
      3) edit_error conflict 'The loaded or saved definition changed. Reopen after reconciliation.'; return 1 ;;
      *) edit_failure; return 1 ;;
    esac
  fi
  publish_and_commit ""; rc=$?
  case "$rc" in
    0) ;;
    2) edit_error busy 'The job or calendar became busy. Retry later.' 75; return $? ;;
    3) edit_error conflict 'The definition changed during the edit. Reopen it.'; return 1 ;;
    *) edit_failure; return 1 ;;
  esac
  printf '%s\n' "$response"
}

edit_failure() {
  if [ -e "$C_FOLDER/pending" ]; then
    edit_error recovery 'The change needs settlement. Check status and retry when the job is idle.'
  else
    edit_error apply 'The change failed and was rolled back. Check launchd and file permissions before retrying.'
  fi
}
