#!/bin/bash
# Council producers publish immutable envelopes. Only the watcher changes state.

write_watch_heartbeat() (
  umask 077
  local root="${PR_REVIEW_WATCH_STATE_DIR:-$HOME/.claude/state/pr-review-watch}" temp
  mkdir -p "$root" || return
  temp="$(mktemp "$root/heartbeat.XXXXXX")" || return
  printf '%s\t%s\n' "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" "$(date +%s)" >"$temp" && mv "$temp" "$root/heartbeat"
)

watch_registration_ready() {
  local root="$1" login="$2" actor stamp now
  [ ! -f "$root/off" ] && [ -f "$root/heartbeat" ] && [ ! -L "$root/heartbeat" ] || return 1
  [ "$(perl -e 'print((stat shift)[7] // 9999)' "$root/heartbeat")" -le 256 ] || return 1
  IFS=$'\t' read -r actor stamp <"$root/heartbeat" || return 1
  [[ "$stamp" =~ ^[0-9]{1,12}$ ]] && [ "$actor" = "$login" ] || return 1
  now="$(date +%s)"
  [ "$stamp" -le "$now" ] && [ "$((now - stamp))" -lt 300 ]
}

submit_council_registration() (
  umask 077
  local repo="$1" number="$2" sha="$3" login="$4" report="$5" mode="$6"
  local root="${PR_REVIEW_WATCH_STATE_DIR:-$HOME/.claude/state/pr-review-watch}" findings author temp
  repo="$(printf '%s' "$repo" | tr '[:upper:]' '[:lower:]')"
  login="$(printf '%s' "$login" | tr '[:upper:]' '[:lower:]')"
  refuse() { printf '=== watcher: not queued (%s)\n' "$1"; }
  if ! [[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && "$number" =~ ^[1-9][0-9]{0,9}$ && "$sha" =~ ^[0-9a-f]{40}$ && "$login" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || [ "$number" -gt 2147483647 ]; then
    refuse 'invalid registration identity'; return 0
  fi
  case "$mode" in follow|approve) ;; *) refuse 'invalid registration mode'; return 0 ;; esac
  [ -f "$report" ] && [ ! -L "$report" ] && [ "$(perl -e 'print((stat shift)[7] // 9999999)' "$report")" -le 1048576 ] || { refuse 'report missing or oversized'; return 0; }
  findings="$(validator_run_findings "$report" "$sha")" || { refuse 'no complete council proof'; return 0; }
  author="$(gh pr view "$number" --repo "$repo" --json author --jq .author.login 2>/dev/null)" || { refuse 'PR author unavailable'; return 0; }
  author="$(printf '%s' "$author" | tr '[:upper:]' '[:lower:]')"
  [ -n "$author" ] && [ "$author" != "$login" ] || { refuse 'own PR or missing author'; return 0; }
  if [ "$mode" = approve ] && ! watch_registration_ready "$root" "$login"; then
    refuse 'watcher not ready for this account'; return 0
  fi
  mkdir -p "$root/register" || { refuse 'cannot create registration inbox'; return 0; }
  temp="$(mktemp "$root/register/incoming.XXXXXX")" || { refuse 'cannot create registration'; return 0; }
  if ! jq -n --arg repo "$repo" --argjson number "$number" --arg sha "$sha" --arg login "$login" --arg mode "$mode" --argjson findings "$findings" --rawfile report "$report" \
    '{version:1,repo:$repo,number:$number,sha:$sha,login:$login,mode:$mode,findings:$findings,report:$report}' >"$temp" || ! mv "$temp" "$temp.json"; then
    rm -f "$temp"; refuse 'cannot publish registration'; return 0
  fi
  if [ "$mode" = follow ]; then printf '=== watcher: following %s (approval not queued)\n' "$sha"
  else printf '=== watcher: submitted %s (approval by the watcher once ingested)\n' "$sha"; fi
)

reject_registration() {
  log "registration rejected: $2#$3 $5"
  [ "$4" != approve ] || notify 'PR approval not queued' "$2#$3: $5" ""
  rm -f "$1"
}

# Called while watch.sh owns its lock. Reports and proof fields are validated
# again here; an envelope cannot declare itself clean or borrow another account.
ingest_council_registrations() {
  local me="$1" record repo number sha login mode key report temp findings stored_findings author snapshot listed status_sha status_mode status_rc status_attempt count=0
  me="$(printf '%s' "$me" | tr '[:upper:]' '[:lower:]')"
  mkdir -p "$STATE_DIR/register" "$RUNS" "$REPORTS" || return 1
  for record in "$STATE_DIR/register/"*.json; do
    [ -e "$record" ] || continue
    count=$((count + 1)); [ "$count" -le 64 ] || break
    if [ -L "$record" ] || [ ! -f "$record" ] || [ "$(perl -e 'print((stat shift)[7] // 99999999)' "$record")" -gt 8388608 ] || ! jq -e '
      .version == 1 and (.repo|type == "string" and test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"))
      and (.number|type == "number" and . > 0 and . <= 2147483647 and . == floor)
      and (.sha|type == "string" and test("^[0-9a-f]{40}$"))
      and (.login|type == "string" and test("^[A-Za-z0-9][A-Za-z0-9-]*$"))
      and (.mode == "follow" or .mode == "approve") and (.report|type == "string" and utf8bytelength <= 1048576)' "$record" >/dev/null 2>&1; then
      log 'registration rejected: malformed envelope'; rm -f "$record"; continue
    fi
    IFS=$'\t' read -r repo number sha login mode < <(jq -r '[.repo,.number,.sha,.login,.mode]|@tsv' "$record")
    if [ "$login" != "$me" ]; then
      reject_registration "$record" "$repo" "$number" "$mode" 'account changed'; continue
    fi
    listed="$(awk -F'\t' -v r="$repo" -v n="$number" 'tolower($1)==tolower(r) && $2==n {print $1; exit}' "$WATCHED")"
    repo="${listed:-$repo}"
    key="$(run_key "$repo" "$number")"
    status_sha='' status_mode='' status_rc='' status_attempt=''
    [ ! -f "$key.status" ] || IFS=$'\t' read -r status_sha status_mode status_rc status_attempt <"$key.status" || true
    if run_alive "$key" || { [ "$status_rc" = running ] && [ "$(status_age "$key")" -lt "$LAUNCH_GRACE_SECONDS" ]; }; then continue; fi
    snapshot="$(gh pr view "$number" --repo "$repo" --json author,state,headRefOid 2>/dev/null)" || continue
    if ! printf '%s' "$snapshot" | jq -e --arg sha "$sha" '.state == "OPEN" and .headRefOid == $sha' >/dev/null; then
      reject_registration "$record" "$repo" "$number" "$mode" 'stale or closed PR'; continue
    fi
    author="$(printf '%s' "$snapshot" | jq -er '.author.login | select(type == "string") | ascii_downcase')" || continue
    if [ -z "$author" ] || [ "$author" = "$me" ]; then
      reject_registration "$record" "$repo" "$number" "$mode" 'own PR or missing author'; continue
    fi
    report="$REPORTS/${repo//\//_}-$number-${sha:0:8}-council.md"
    if [ "$status_sha" = "$sha" ] && [ "$status_rc" != running ] && { [ "$status_mode" != council ] || [ "$status_rc" != 0 ] || [ ! -f "$report" ]; }; then
      reject_registration "$record" "$repo" "$number" "$mode" 'same-head decision kept'; continue
    fi
    if [ "$(cat "$key.exhausted" 2>/dev/null)" = "$sha" ] && { [ "$status_rc" != running ] || [ "$status_sha" != "$sha" ]; }; then
      reject_registration "$record" "$repo" "$number" "$mode" 'same-head stopped decision kept'; continue
    fi
    if [ -f "$key.council-done" ] && [ "$(cat "$key.council-done")" != "$sha" ]; then
      reject_registration "$record" "$repo" "$number" "$mode" 'follow-up verification required'; continue
    fi
    temp="$(mktemp "$REPORTS/.registration.XXXXXX")" || return 1
    chmod 600 "$temp"
    if ! jq -jr .report "$record" >"$temp" || ! findings="$(validator_run_findings "$temp" "$sha")"; then
      rm -f "$temp"; reject_registration "$record" "$repo" "$number" "$mode" 'incomplete proof'; continue
    fi
    if [ "$status_sha" = "$sha" ] && [ "$status_rc" = 0 ] && [ -f "$report" ]; then
      stored_findings="$(validator_run_findings "$report" "$sha" 2>/dev/null)" || stored_findings=''
      # Mailbox filenames do not establish completion order. Never let a
      # delayed same-head report reduce findings or transfer an existing actor.
      # A normal fresh council (or a new head) can establish new clean proof.
      if [ -n "$stored_findings" ] && [ "$stored_findings" -ge "$findings" ]; then
        rm -f "$temp"
        reject_registration "$record" "$repo" "$number" "$mode" 'existing same-head evidence and initial approval owner kept'; continue
      fi
    fi
    if ! mv "$temp" "$report"; then
      log "registration deferred: $repo#$number cannot store its report"
      rm -f "$temp"; continue
    fi
    if [ -z "$listed" ]; then
      printf '%s\t%s\n' "$repo" "$number" >>"$WATCHED"
    fi
    printf '%s\t%s\n' "$sha" "$login" >"$key.registered"
    printf '%s\n' "$sha" >"$key.council-done"
    printf '%s\n' "$sha" >"$key.watermark"
    printf '%s\tcouncil\t0\t1\n' "$sha" >"$key.status"
    rm -f "$key.council-clean" "$key.approval-pending" "$key.approval-body"
    if [ "$findings" = 0 ]; then
      printf '%s\n' "$sha" >"$key.council-clean"
      if [ "$mode" = approve ]; then
        if validator_approval_body "$report" "$sha" >"$key.approval-body"; then
          printf '%s\n' "$sha" >"$key.approval-pending"
        else rm -f "$key.approval-body"; fi
      fi
    fi
    log "registered $repo#$number @${sha:0:8} ($mode, $findings findings)"
    rm -f "$record"
  done
}
