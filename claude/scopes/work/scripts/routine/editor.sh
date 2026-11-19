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

# Prefix present values so an empty plist string stays distinct from an absent key.
registry_matches() { # plist, launchctl target, service plist path (empty for a domain), print output
  local plist="$1" registry home
  if registry=$(pb 'Print :EnvironmentVariables:ETABLI_ROUTINES_DIR' "$plist"); then registry="=$registry"; else registry=-; fi
  if home=$(pb 'Print :EnvironmentVariables:HOME' "$plist"); then home="=$home"; else home=-; fi
  editor_data registry "$dir" "$2" "$3" "$registry" "$home" <<<"$4"
}

loaded_registry_matches() {
  registry_matches "$1" "gui/$(user_id)/$2" "$(launch_dir)/$2.plist" "$JOB_OUT"
}

domain_registry_matches() {
  local target="gui/$(user_id)" domain
  domain=$("$LCTL" print "$target" 2>/dev/null) &&
    registry_matches "$1" "$target" "" "$domain"
}

plist_hash() { editor_data plist-hash "$1" "$PLIST_MAX_BYTES"; }

# The folder inode binds a receipt to the registry verified while the service
# was loaded, including the short interval when launchctl cannot describe it.
write_pending() { # folder, kind, desired id, base revision, snapshot hashes or phase
  local f="$1" identity temp
  identity=$(editor_data folder-id "$f") && temp=$(/usr/bin/mktemp "$f/.pending.XXXXXX") || return 1
  if printf '%s\n' "$2" "$3" "$4" "$identity" "$5" >"$temp" && /bin/mv -f "$temp" "$f/pending"; then return 0; fi
  /bin/rm -f "$temp"
  return 1
}

seal_plists() {
  local f="$1" prev next
  prev=$(plist_hash "$f/plist.prev") && next=$(plist_hash "$f/plist.next") &&
    write_pending "$f" "$C_KIND" "$C_ID" "$E_REV" "$prev $next"
}

read_pending() {
  local f="$1" folder_id extra
  [ -f "$f/pending" ] && [ -O "$f/pending" ] && [ ! -L "$f/pending" ] || return 1
  { IFS= read -r P_KIND && IFS= read -r P_AFTER && IFS= read -r P_BEFORE &&
    IFS= read -r folder_id && IFS= read -r P_PROOF && ! IFS= read -r extra; } <"$f/pending" &&
    [ "$folder_id" = "$(editor_data folder-id "$f")" ] && [ -n "$folder_id" ] &&
    [[ $P_BEFORE =~ ^[0-9a-f]{64}$ ]] || return 1
  P_INTENT=""
  if [[ $P_PROOF = "staging "* ]]; then P_INTENT=${P_PROOF#staging }; P_PROOF=staging; fi
}

check_plists() {
  local f="$1" prev next
  prev=$(plist_hash "$f/plist.prev") && next=$(plist_hash "$f/plist.next") &&
    [ "$P_PROOF" = "$prev $next" ]
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
  loaded_registry_matches "$1" "$label" && loaded_arguments_match "$label" "$2" "${PARGS[@]}"
}

# Roll back only a recognizable state of this swap. An externally replaced
# plist or a loaded job with different arguments/triggers needs owner repair.
restore_edit() {
  local label="$1" f="$2" margin="$3" dst prev_key disk_key disk_hash calendars zone
  case "$label" in ''|*[!A-Za-z0-9._-]*|"$RESERVED_LABEL") return 1 ;; esac
  read_pending "$f" && check_plists "$f" || return 1
  dst="$(launch_dir)/$label.plist"
  [ "$(pb 'Print :Label' "$f/plist.prev")" = "$label" ] && is_wrapped "$f/plist.prev" "${f##*/}" &&
    [ "${PARGS[1]}" -ef "$ROUTINE_SELF" ] && parse_slots "$f/plist.prev" || return 1
  prev_key=$(calendar_key <<<"$SLOTS")
  calendars="$SLOTS"
  if $CMP -s "$dst" "$f/plist.prev"; then
    disk_key="$prev_key"; disk_hash="${P_PROOF%% *}"
  elif $CMP -s "$dst" "$f/plist.next" && parse_slots "$dst"; then
    disk_key=$(calendar_key <<<"$SLOTS"); disk_hash="${P_PROOF##* }"
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
    domain_registry_matches "$f/plist.prev" || return 1
    SLOTS="$calendars"
    zone=$(system_tz) || return 1
    if [ "$JOB_RUNNING" = 1 ] || TZ="$zone" slot_within "$margin"; then return 2; fi
    "$LCTL" bootout "gui/$(user_id)/$label" >/dev/null 2>&1 || return 1
  fi
  domain_registry_matches "$f/plist.prev" || return 1
  install_plist "$f/plist.prev" "$label" "" "$disk_hash" "${P_PROOF%% *}" &&
    "$LCTL" bootstrap "gui/$(user_id)" "$dst" >/dev/null 2>&1 &&
    job_state "$label" && $CMP -s "$dst" "$f/plist.prev" && loaded_matches "$f/plist.prev" "$prev_key"
}

# Confirm the original command (every argument), the wrapper and both copies
# of the calendar. Refuse unfamiliar launchctl output as unverifiable.
verify_disk() {
  local plist="${1:-$E_PLIST}" calendar="${2:-$E_OLD}" origin="${3:-$C_FOLDER/$E_ORIGIN}"
  [ -f "$plist" ] && [ -O "$plist" ] && [ ! -L "$plist" ] &&
    [ "$(/usr/bin/wc -c <"$plist")" -le "$PLIST_MAX_BYTES" ] || return 1
  [ -f "$origin" ] && [ -O "$origin" ] && [ ! -L "$origin" ] &&
    [ "$(/usr/bin/wc -c <"$origin")" -le "$PLIST_MAX_BYTES" ] && validate_plist "$origin" "$C_LABEL" || return 1
  if [ "$#" -ge 3 ] && [ "$(calendar_key <<<"$SLOTS")" != "$calendar" ]; then return 1; fi
  validate_plist "$plist" "$C_LABEL" && [ "$(calendar_key <<<"$SLOTS")" = "$calendar" ] || return 1
  is_wrapped "$plist" "$C_NAME" && [ "${PARGS[1]}" -ef "$ROUTINE_SELF" ] || return 1
  E_ARGS=("${PARGS[@]}")
  editor_data same-definition "$PLUTIL" "$plist" "$origin"
}

verify_edit_identity() {
  E_ZONE=$(system_tz) || return 1
  [ "$(editor_data revision "$C_FOLDER/routine.json")" = "$E_REV" ] &&
    [ "$E_ZONE" = "$(manifest_get "$C_FOLDER/routine.json" tz)" ] && verify_disk "$@"
}

verify_edit_base() {
  verify_edit_identity && job_state "$C_LABEL" && loaded_registry_matches "$E_PLIST" "$C_LABEL" && loaded_arguments_match "$C_LABEL" "$E_OLD" "${E_ARGS[@]}"
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

inspect_request() {
  local result
  result=$(editor_data inspect "$manifest" "$C_NAME" "$1" "$2") || { printf '%s\n' "$result"; return 1; }
  {
    IFS= read -r C_LABEL; IFS= read -r E_ORIGIN; IFS= read -r E_REV
    IFS= read -r E_OLD; IFS= read -r E_NEW; IFS= read -r C_ID
    IFS= read -r response; IFS= read -r next || true
  } <<<"$result"
  E_PLIST="$(launch_dir)/$C_LABEL.plist"
}

# Classify the disk and service before taking the run lock, and again under it.
# An absent service has no environment to inspect. Only a sealed pair from
# this exact routine folder authorizes resuming the unload/install interval.
pending_service() {
  local f="$1" label="$2" dst="$(launch_dir)/$2.plist" rc
  P_DISK=base
  if [ "$P_PROOF" != staging ] && [ "$P_PROOF" != none ]; then
    check_plists "$f" || return 1
    if $CMP -s "$dst" "$f/plist.next"; then P_DISK=desired
    elif ! $CMP -s "$dst" "$f/plist.prev"; then return 1
    fi
  fi
  [ -f "$dst" ] && [ -O "$dst" ] && [ ! -L "$dst" ] && parse_slots "$dst" || return 1
  job_state "$label"; rc=$?
  if [ "$rc" = 113 ]; then
    [ "$P_PROOF" != staging ] && [ "$P_PROOF" != none ] && domain_registry_matches "$dst"; return $?
  fi
  [ "$rc" = 0 ] && loaded_matches "$dst" "$(calendar_key <<<"$SLOTS")"
}

settle_before_publication() {
  local f="$1" manifest="$1/routine.json" label E_RUN_LOCKED=0
  [ "$(editor_data revision "$manifest")" = "$P_BEFORE" ] || return 1
  label=$(manifest_get "$manifest" label) || return 1
  case "$label" in ''|*[!A-Za-z0-9._-]*|"$RESERVED_LABEL") return 1 ;; esac
  if [ "$P_PROOF" = staging ] || [ "$P_PROOF" = none ]; then
    C_FOLDER="$f"; C_NAME="${f##*/}"
    inspect_request "$P_BEFORE" '{}' >/dev/null && verify_edit_base || return 1
    [ "$P_PROOF" = staging ] && return 0
    [ "$P_KIND" = edit ] && [ ! -e "$f/plist.prev" ] && [ ! -e "$f/plist.next" ] || return 1
  else
    pending_service "$f" "$label" || return 1
  fi
  if [ "$P_KIND" = edit ]; then
    [ "$(editor_data revision "$f/routine.json.next")" = "$P_AFTER" ] || return 1
    C_FOLDER="$f"; lock_run_for_edit >&2 || return 1
  fi
  [ "$P_PROOF" != none ] || return 0
  restore_edit "$label" "$f" 10
}

pending_error() { edit_error recovery 'Cannot verify the interrupted operation. Reconcile the job and its staged records.'; }

verify_published_edit() {
  inspect_request "" '{}' >/dev/null && [ "$E_REV" = "$P_AFTER" ] && verify_edit_base || return 1
  [ "$P_PROOF" = none ] || { [[ $P_PROOF =~ ^[0-9a-f]{64}\ [0-9a-f]{64}$ ]] &&
    [ "$(plist_hash "$E_PLIST")" = "${P_PROOF##* }" ]; }
}

pending_edit() {
  local base changes
  read_pending "$C_FOLDER" && [ "$P_KIND" = edit ] || { pending_error; return 1; }
  base=$(editor_data revision "$manifest") || { pending_error; return 1; }
  if [ "$base" = "$P_AFTER" ]; then
    verify_published_edit || { pending_error; return 1; }
    if [ "$op" = editor ]; then printf '%s\n' "$response"; return 0; fi
    if [ "$expected" != "$base" ]; then edit_error conflict 'The edit has already been published. Reopen the routine.'; return 1; fi
    lock_run_for_edit || return $?
    settle_folder "$C_FOLDER" || { pending_error; return 1; }
    perform_edit "$1"; return $?
  fi
  if [ "$op" = edit ] && [ "$expected" != "$P_BEFORE" ]; then
    edit_error conflict 'Reopen the routine before retrying this edit.'; return 1
  fi
  if [ "$P_PROOF" = staging ] && [ -n "$P_INTENT" ]; then
    # Staging precedes every service operation. Rebuild partial files only after
    # matching the durable intent and verifying the unchanged installed base.
    [ "$base" = "$P_BEFORE" ] && inspect_request "$base" "$P_INTENT" >/dev/null &&
      [ "$C_ID" = "$P_AFTER" ] && verify_edit_base || { pending_error; return 1; }
    if [ "$op" = editor ]; then
      inspect_request "" '{}' >/dev/null && editor_data preview "$response" "$P_INTENT"
      return $?
    fi
    inspect_request "$expected" "$1" || return 1
    [ "$C_ID" = "$P_AFTER" ] || { edit_error conflict 'Retry the original pending change.'; return 1; }
    perform_edit "$1"; return $?
  fi
  [ "$base" = "$P_BEFORE" ] && [ "$P_PROOF" != staging ] &&
    [ "$(editor_data revision "$C_FOLDER/routine.json.next")" = "$P_AFTER" ] ||
    { pending_error; return 1; }
  changes=$(editor_data pending-changes "$manifest" "$C_FOLDER/routine.json.next") &&
    inspect_request "$base" "$changes" >/dev/null && [ "$C_ID" = "$P_AFTER" ] ||
    { pending_error; return 1; }
  if [ "$op" = edit ]; then
    inspect_request "$expected" "$1" || return 1
    [ "$C_ID" = "$P_AFTER" ] || { edit_error conflict 'Retry the original pending change or reconcile the routine.'; return 1; }
  fi
  verify_pending_edit || { pending_error; return 1; }
  if [ "$op" = editor ]; then
    inspect_request "" '{}' >/dev/null && [ "$E_REV" = "$base" ] || { pending_error; return 1; }
    editor_data preview "$response" "$changes"; return $?
  fi
  lock_run_for_edit || return $?
  verify_pending_edit || { pending_error; return 1; }
  edit_margins 10 || { edit_error busy 'Retry when the job is idle and both calendars are at least ten minutes away.' 75; return $?; }
  if [ "$P_PROOF" != none ]; then
    if [ "$JOB_LOADED" = 1 ] && [ "$P_DISK" = base ]; then
      apply_staged_calendar || return $?
    else
      C_SWAP=1
      if [ "$JOB_LOADED" = 0 ]; then
        if [ "$P_DISK" = base ]; then
          install_plist "$C_FOLDER/plist.next" "$C_LABEL" swap "${P_PROOF%% *}" "${P_PROOF##* }" ||
            { pending_error; return 1; }
        fi
        [ "$(plist_hash "$E_PLIST")" = "${P_PROOF##* }" ] &&
          "$LCTL" bootstrap "gui/$(user_id)" "$E_PLIST" >/dev/null 2>&1 || { pending_error; return 1; }
      fi
    fi
  fi
  finish_edit
}

verify_pending_edit() {
  read_pending "$C_FOLDER" && [ "$P_KIND" = edit ] && [ "$P_BEFORE" = "$E_REV" ] &&
    [ "$P_AFTER" = "$C_ID" ] && [ "$(editor_data revision "$C_FOLDER/routine.json.next")" = "$C_ID" ] &&
    pending_service "$C_FOLDER" "$C_LABEL" || return 1
  if [ "$E_NEW" = "$E_OLD" ]; then
    [ "$P_PROOF" = none ] && [ ! -e "$C_FOLDER/plist.prev" ] && [ ! -e "$C_FOLDER/plist.next" ] &&
      verify_edit_identity
  else
    [[ $P_PROOF =~ ^[0-9a-f]{64}\ [0-9a-f]{64}$ ]] && verify_edit_identity "$C_FOLDER/plist.prev" "$E_OLD" &&
      verify_disk "$C_FOLDER/plist.next" "$E_NEW"
  fi
}

cmd_editor() {
  local -a E_ARGS
  local E_ZONE E_RUN_LOCKED=0
  local op="$1" changes='{}' expected="" response next rc f
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
  if [ ! -e "$C_FOLDER/pending" ]; then
    local source
    source=$(manifest_get "$manifest" source) || { edit_error conflict 'Repair the unreadable manifest.'; return 1; }
    if [ "$source" != adopt ]; then
      edit_error unsupported 'Use the owning producer for this routine.' 2; return $?
    fi
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
    C_KIND=edit
    pending_edit "$changes"; return $?
  fi
  perform_edit "$changes"
}

perform_edit() {
  C_KIND=edit
  inspect_request "$expected" "$1" || return 1
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
  write_pending "$C_FOLDER" edit "$C_ID" "$E_REV" "staging $1" || { edit_failure; return 1; }
  hold edit-intent
  if ! (umask 077; printf '%s\n' "$next" >"$C_FOLDER/routine.json.next") ||
     ! /usr/bin/perl -e 'my @s=stat $ARGV[0]; @s && chmod($s[2]&0777, $ARGV[1]) or exit 1' "$manifest" "$C_FOLDER/routine.json.next"; then
    stage_fail "cannot stage the manifest"; edit_error apply 'Check the records directory permissions and retry.'; return 1
  fi
  hold edit-manifest-staged
  if [ "$E_NEW" != "$E_OLD" ]; then
    if ! save_prev "$E_PLIST" "$C_FOLDER" || ! /bin/cp "$C_FOLDER/plist.prev" "$C_FOLDER/plist.next" ||
       ! set_calendar "$C_FOLDER/plist.next" "$(printf '%s' "$E_NEW" | /usr/bin/tr '|' '\n')" ||
       [ "$(/usr/bin/wc -c <"$C_FOLDER/plist.next")" -gt "$PLIST_MAX_BYTES" ]; then
      stage_fail "cannot stage the calendar"; edit_error apply 'Check the size and permissions of the staged plist.'; return 1
    fi
    seal_plists "$C_FOLDER" || { stage_fail "cannot seal staged plists"; edit_failure; return 1; }
    hold staged
    apply_staged_calendar || return $?
  else
    write_pending "$C_FOLDER" edit "$C_ID" "$E_REV" none || { stage_fail "cannot seal manifest"; edit_failure; return 1; }
  fi
  finish_edit
}

apply_staged_calendar() {
  local rc
  swap_job "$C_FOLDER/plist.next" edit; rc=$?
  case "$rc" in
    0) return 0 ;;
    2) edit_error busy 'The job started or a calendar slot is now near. Retry later.' 75; return $? ;;
    3) edit_error conflict 'The loaded or saved definition changed. Reopen after reconciliation.'; return 1 ;;
    *) edit_failure; return 1 ;;
  esac
}

finish_edit() {
  local rc
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
