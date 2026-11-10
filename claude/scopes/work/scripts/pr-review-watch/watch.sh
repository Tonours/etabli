#!/bin/bash
set -uo pipefail
umask 077

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${PR_REVIEW_WATCH_STATE_DIR:-$HOME/.claude/state/pr-review-watch}"
WATCHED="$STATE_DIR/watched.tsv"
REPORTS="$STATE_DIR/reports"
RUNS="$STATE_DIR/runs"
LOCK_DIR="$STATE_DIR/lock"
KILL_SWITCH="$STATE_DIR/off"
LOG="${PR_REVIEW_WATCH_LOG:-$HOME/.claude/logs/pr-review-watch.log}"
LOG_MAX_BYTES=5000000
COUNCIL="${PR_REVIEW_WATCH_COUNCIL:-$HOME/.claude/scripts/pr-council-review/run.sh}"
RUNNER="$HERE/review-run.sh"
HERDR_WORKSPACE="${PR_REVIEW_WATCH_HERDR_WORKSPACE:-pr-reviews}"
MAX_CONCURRENT="${PR_REVIEW_WATCH_MAX_CONCURRENT:-2}"
MAX_ATTEMPTS="${PR_REVIEW_WATCH_MAX_ATTEMPTS:-3}"
MAX_RUNS_PER_DAY="${PR_REVIEW_WATCH_MAX_RUNS_PER_DAY:-20}"
SETTLE_SECONDS="${PR_REVIEW_WATCH_SETTLE:-120}"
MAX_DIFF_LINES="${PR_REVIEW_WATCH_MAX_DIFF_LINES:-5000}"
RETRY_BACKOFF_SECONDS="${PR_REVIEW_WATCH_RETRY_BACKOFF:-600}"
LAUNCH_GRACE_SECONDS=180
GH_TIMEOUT="${PR_REVIEW_WATCH_GH_TIMEOUT:-60}"
CLI_MISMATCH="$STATE_DIR/cli-mismatch"
CLONE_ROOTS=("$HOME/work" "$HOME/work/zendesk")
TEMP_CLONES="$STATE_DIR/clones"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
. "$HERE/herdr.sh"
. "$HERE/../pr-council-review/lib.sh"
. "$HERE/clones.sh"
. "$HERE/register.sh"
. "$HERE/requests.sh"

log() { echo "$(date '+%F %T') $*"; }

gh() { perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$GH_TIMEOUT" gh "$@"; }

check_claude_cli() {
  if "$CLAUDE" --help 2>/dev/null | grep -q -- --permission-prompts; then
    rm -f "$CLI_MISMATCH"
    return 0
  fi
  log "claude at ${CLAUDE:-<none>} has no --permission-prompts flag, not reviewing"
  if [ ! -f "$CLI_MISMATCH" ]; then
    touch "$CLI_MISMATCH"
    notify "PR review watcher stopped" "claude at ${CLAUDE:-<none>} has no --permission-prompts flag: update Claude Code" ""
  fi
  return 1
}

discover_requested() {
  gh search prs "user-review-requested:@me" --state=open --limit 100 \
    --json repository,number --jq '.[] | [.repository.nameWithOwner, .number] | @tsv'
}

merge_into_watched() {
  local repo number
  while IFS=$'\t' read -r repo number; do
    [ -n "$repo" ] || continue
    if ! awk -F'\t' -v r="$repo" -v n="$number" 'tolower($1)==tolower(r) && $2==n {found=1} END {exit !found}' "$WATCHED"; then
      printf '%s\t%s\n' "$repo" "$number" >>"$WATCHED"
      log "watching $repo#$number"
    fi
  done
}

find_clone() {
  local name="${1#*/}" root
  for root in "${CLONE_ROOTS[@]}"; do
    if [ -d "$root/$name/.git" ] && git -C "$root/$name" remote get-url origin 2>/dev/null | grep -qiE "[:/]$1(\.git)?$"; then
      printf '%s' "$root/$name"
      return 0
    fi
  done
  return 1
}

run_key() { printf '%s/%s_%s' "$(cd "$RUNS" 2>/dev/null && pwd -P || printf '%s' "$RUNS")" "${1//\//_}" "$2"; }

running_count() {
  local key count=0
  while IFS= read -r key; do
    run_reserved "$key" && count=$((count + 1))
  done < <(find "$RUNS" -maxdepth 1 \( -name '*.status' -o -name '*.pid' -o -name '*.execution' \) | sed -E 's/\.(status|pid|execution)$//' | sort -u)
  echo "$count"
}

launches_file() { printf '%s/launches-%s' "$RUNS" "$(date +%F)"; }

launched_today() {
  local file
  file="$(launches_file)"
  if [ -f "$file" ]; then wc -l <"$file" | tr -d ' '; else echo 0; fi
}

read_status() {
  if [ -f "$1.status" ]; then cat "$1.status"; else printf -- '-\t-\t-\t0'; fi
}

status_age() {
  echo $(( $(date +%s) - $(perl -e 'print((stat $ARGV[0])[9] // time)' "$1.status") ))
}

last_review_sha() {
  gh api --paginate "repos/$1/pulls/$2/reviews" </dev/null \
    | jq -rs --arg me "$3" '[.[][] | select(.user.login == $me) | .commit_id] | last // "-"'
}

seen_age() {
  local key="$1" sha="$2" seen_sha="" seen_at=0
  [ -f "$key.seen" ] && read -r seen_sha seen_at <"$key.seen"
  if [ "$seen_sha" != "$sha" ]; then
    printf '%s %s\n' "$sha" "$(date +%s)" >"$key.seen"
    echo 0
    return
  fi
  echo $(( $(date +%s) - seen_at ))
}

# Prints the changed lines outside lockfiles, or "skip <reason>" for a PR that
# needs no model review.
diff_scope() {
  gh pr view "$2" --repo "$1" --json author,files,changedFiles,additions,deletions </dev/null | jq -r '
    def lockfile: test("(^|/)(package-lock\\.json|npm-shrinkwrap\\.json|yarn\\.lock|pnpm-lock\\.yaml|bun\\.lockb?|Gemfile\\.lock|Cargo\\.lock|poetry\\.lock|uv\\.lock|Pipfile\\.lock|composer\\.lock|go\\.sum|flake\\.lock|mix\\.lock)$");
    def docs: test("(^|/)docs/|\\.(md|mdx|rst|adoc)$");
    ([.files[] | select(.path | lockfile)]) as $locks
    | ([.files[] | select(.path | lockfile | not)]) as $code
    | (.changedFiles == (.files | length)) as $listed
    | if .author.is_bot or (.author.login | endswith("[bot]")) then "skip bot author \(.author.login)"
      elif $listed and ($code | length) == 0 then "skip lockfile-only diff"
      elif $listed and ($code | all(.path | docs)) then "skip docs-only diff"
      else .additions + .deletions - ([$locks[] | .additions + .deletions] | add // 0) end'
}

write_launcher() {
  local launcher="$1" diagnostic="$2" name value
  shift 2
  {
    echo '#!/bin/bash'
    printf 'exec >>%q 2>&1\n' "$diagnostic"
    env | grep -E '^(PR_REVIEW_|PR_COUNCIL_)' | while IFS='=' read -r name value; do
      printf 'export %s=%q\n' "$name" "$value"
    done
    printf 'export PR_REVIEW_WATCH_STATE_DIR=%q\n' "$STATE_DIR"
    printf 'exec'
    printf ' %q' "$@"
    echo
  } >"$launcher" || return 1
  chmod 700 "$launcher"
}

pr_snapshot() {
  local pr review
  pr="$(gh pr view "$2" --repo "$1" --json state,isDraft,headRefOid,url,reviewRequests,latestReviews </dev/null)" || return 1
  # gh latestReviews can serialize an empty commit.oid. REST carries the
  # reviewed commit, and its last non-comment opinion supersedes older approval.
  review="$(gh api --paginate "repos/$1/pulls/$2/reviews" </dev/null | jq -cs --arg me "$3" '
    [.[][] | select((.user.login|ascii_downcase) == ($me|ascii_downcase))
      | select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "DISMISSED")]
    | max_by(.id) // {} | {state,commit_id}')" || return 1
  printf '%s\n' "$pr" | jq -r --arg me "$3" --argjson review "$review" '[
      .state, .isDraft, .headRefOid, .url,
      ((([.reviewRequests[]?.login] + [.latestReviews[]?.author.login]) | map(ascii_downcase) | index($me|ascii_downcase)) != null),
      ($review.state == "APPROVED" and $review.commit_id == .headRefOid),
      ($review.state == "APPROVED" and $review.commit_id != .headRefOid)
    ] | @tsv'
}

next_attempt() {
  local key="$1" sha="$2" s_sha s_mode s_rc s_attempts
  IFS=$'\t' read -r s_sha s_mode s_rc s_attempts <<<"$(read_status "$key")"
  if [ "$s_sha" != "$sha" ]; then
    echo 1
    return
  fi
  if [ "$s_rc" = 75 ] && [ "$(cat "$key.paused" 2>/dev/null)" = "$(printf '%s\t%s' "$sha" "$s_attempts")" ]; then
    if [ "$(status_age "$key")" -lt "$RETRY_BACKOFF_SECONDS" ]; then echo wait; else echo "$s_attempts"; fi
    return
  fi
  case "$s_rc" in
    0) echo done ;;
    running)
      if [ "$(status_age "$key")" -lt "$(reservation_seconds)" ]; then echo wait
      elif [ "$s_attempts" -ge "$MAX_ATTEMPTS" ]; then echo exhausted
      else echo $((s_attempts + 1)); fi ;;
    "$REVIEW_VETO_RC"|"$REVIEW_INCOMPLETE_RC") echo stopped ;;
    *)
      # rc 5 alone is ambiguous (a child can exit 5); only the marker run_verify writes means unconfigured.
      if [ "$s_rc" = "$VERIFY_UNCONFIGURED_RC" ] && [ "$(cat "$key.verify-unconfigured" 2>/dev/null)" = "$sha" ]; then
        if verify_skill >/dev/null; then echo "$s_attempts"; else echo unconfigured; fi
      elif [ "$s_attempts" -ge "$MAX_ATTEMPTS" ]; then echo exhausted
      elif [ "$(status_age "$key")" -lt "$RETRY_BACKOFF_SECONDS" ]; then echo wait
      else echo $((s_attempts + 1)); fi ;;
  esac
}

launch() {
  local repo="$1" number="$2" sha="$3" url="$4" mode="$5" since="$6" key="$7" attempt="$8"
  local clone report label launcher token temp diagnostic status_before
  status_before="$(cat "$key.status" 2>/dev/null || true)"
  run_reserved "$key" && return 0
  clear_dead_execution "$key" || return 0
  take_execution "$key" || return 0
  if run_reserved "$key" || [ "$(cat "$key.status" 2>/dev/null)" != "$status_before" ]; then release_execution "$key"; return 0; fi
  if ! mkdir -p "$STATE_DIR/diagnostics" "$RUNS" "$REPORTS" \
    || ! chmod 700 "$STATE_DIR" "$STATE_DIR/diagnostics" "$RUNS" "$REPORTS"; then
    release_execution "$key"; return 1
  fi
  launcher="$(mktemp "$key.launch.XXXXXX")" || { release_execution "$key"; return 1; }
  token="${launcher##*/}"
  diagnostic="$STATE_DIR/diagnostics/$token.log"
  if ! { : >"$diagnostic" && chmod 600 "$diagnostic"; }; then release_execution "$key"; return 1; fi
  temp="$(mktemp "$key.token.XXXXXX")" || { release_execution "$key"; return 1; }
  printf '%s\n' "$token" >"$temp" && mv "$temp" "$key.token" || { release_execution "$key"; return 1; }
  write_run_status "$key" "$sha" "$mode" running "$attempt" || { release_execution "$key"; return 1; }
  rm -f "$key.paused"
  echo "$repo#$number@$sha" >>"$(launches_file)" || { write_run_status "$key" "$sha" "$mode" 1 "$attempt"; release_execution "$key"; return 1; }
  clone="$(ensure_clone "$repo" 2>>"$diagnostic")" || {
    write_run_status "$key" "$sha" "$mode" 1 "$attempt"
    release_execution "$key"
    log "cannot prepare clone for $repo#$number; diagnostic retained privately"
    return 1
  }
  report="$REPORTS/${repo//\//_}-$number-${sha:0:8}-$mode.md"
  label="${repo#*/}#$number"
  write_launcher "$launcher" "$diagnostic" "$HERE/launch-run.sh" "$key" "$token" "$mode" "$sha" "$attempt" "$RUNNER" "$mode" "$repo" "$number" "$sha" "$since" "$url" "$report" "$key" || { release_execution "$key"; return 1; }
  release_execution "$key"
  if herdr_available && open_review_tab "$label" "$clone" "$(printf '%q' "$launcher")" >>"$diagnostic" 2>&1; then
    log "$mode $repo#$number @${sha:0:8} attempt $attempt submitted to herdr"
  else
    (cd "$clone" && nohup "$launcher" >>"$diagnostic" 2>&1 </dev/null &)
    log "$mode $repo#$number @${sha:0:8} attempt $attempt submitted headless"
  fi
}

retry_pending_approval() {
  local repo="$1" number="$2" sha="$3" url="$4" key="$5" pending_sha
  pending_sha="$(cat "$key.approval-pending" 2>/dev/null)"
  if [ "$pending_sha" != "$sha" ]; then
    rm -f "$key.approval-pending" "$key.approval-body"
    return
  fi
  clear_dead_execution "$key" || return 0
  "$RUNNER" approve "$repo" "$number" "$sha" - "$url" "$REPORTS/${repo//\//_}-$number-${sha:0:8}-approve.md" "$key" </dev/null \
    | grep -E '^=== (approved|approval)' | while IFS= read -r line; do log "$repo#$number $line"; done
}

consider() {
  local me="$1" repo="$2" number="$3" sha="$4" url="$5" key attempt age size mode since
  key="$(run_key "$repo" "$number")"
  run_reserved "$key" && { log "$repo#$number review still running, wait"; return; }
  if [ -f "$key.approval-pending" ]; then
    retry_pending_approval "$repo" "$number" "$sha" "$url" "$key"
    return
  fi
  attempt="$(next_attempt "$key" "$sha")"
  case "$attempt" in
    done|wait) return ;;
    unconfigured)
      if [ "$(cat "$key.unconfigured" 2>/dev/null)" != "$sha" ]; then
        echo "$sha" >"$key.unconfigured"
        log "$repo#$number @${sha:0:8} verify skill unconfigured, waiting for PR_COUNCIL_VERIFY_SKILL or ~/.config/pr-council-review/verify-skill"
      fi
      return ;;
    exhausted|stopped)
      if [ "$(cat "$key.exhausted" 2>/dev/null)" != "$sha" ]; then
        echo "$sha" >"$key.exhausted"
        if [ "$attempt" = stopped ]; then log "$repo#$number @${sha:0:8} vetoed or incomplete, not retried on this sha"
        else log "$repo#$number @${sha:0:8} failed $MAX_ATTEMPTS times, giving up on this sha"; fi
      fi
      return ;;
  esac
  age="$(seen_age "$key" "$sha")"
  [ "${age:-0}" -ge "$SETTLE_SECONDS" ] || { log "$repo#$number @${sha:0:8} first seen ${age}s ago, settling"; return; }
  size="$(diff_scope "$repo" "$number" 2>/dev/null)"
  case "$size" in
    '') log "$repo#$number @${sha:0:8} size lookup failed, retry next tick"; return ;;
    skip\ *)
      if [ "$(cat "$key.skipped" 2>/dev/null)" != "$sha" ]; then
        echo "$sha" >"$key.skipped"
        log "$repo#$number @${sha:0:8} ${size#skip }, not reviewed"
      fi
      return ;;
  esac
  if [ "$size" -gt "$MAX_DIFF_LINES" ]; then
    if [ "$(cat "$key.skipped" 2>/dev/null)" != "$sha" ]; then
      echo "$sha" >"$key.skipped"
      log "$repo#$number @${sha:0:8} changes $size lines (> $MAX_DIFF_LINES), left to a human"
      notify "PR too big for auto-review" "$repo#$number: $size changed lines" "$url"
    fi
    return
  fi
  [ "$(running_count)" -lt "$MAX_CONCURRENT" ] || { log "$repo#$number queued: $MAX_CONCURRENT reviews running"; return; }
  [ "$(launched_today)" -lt "$MAX_RUNS_PER_DAY" ] || { log "$repo#$number queued: daily cap $MAX_RUNS_PER_DAY reached"; return; }
  mode=council
  since="-"
  if [ -f "$key.council-done" ]; then
    mode=verify
    since="$(cat "$key.watermark" 2>/dev/null)"
    [ -n "$since" ] || since="$(last_review_sha "$repo" "$number" "$me" 2>/dev/null)"
    [ -n "$since" ] && [ "$since" != "-" ] || since="$(cat "$key.council-done" 2>/dev/null || echo -)"
  fi
  launch "$repo" "$number" "$sha" "$url" "$mode" "$since" "$key" "$attempt"
}

process_watched() {
  local me="$1" repo number state draft sha url involved approved stale key registered_sha registered_login
  local next="$WATCHED.next"
  : >"$next"
  while IFS=$'\t' read -r repo number _; do
    [ -n "$repo" ] || continue
    IFS=$'\t' read -r state draft sha url involved approved stale <<<"$(pr_snapshot "$repo" "$number" "$me" 2>/dev/null)"
    if [ -z "${state:-}" ]; then
      printf '%s\t%s\n' "$repo" "$number" >>"$next"
      continue
    fi
    key="$(run_key "$repo" "$number")"
    if [ "$state" = OPEN ] && [ -f "$key.registered" ]; then
      IFS=$'\t' read -r registered_sha registered_login <"$key.registered" || registered_login=''
      if [ "$registered_login" != "$(printf '%s' "$me" | tr '[:upper:]' '[:lower:]')" ]; then
        log "$repo#$number registered account changed; not reviewing or approving"
        printf '%s\t%s\n' "$repo" "$number" >>"$next"
        continue
      fi
      involved=true
    fi
    if [ "$state" != "OPEN" ] || [ "$involved" != "true" ] || { [ "$stale" = true ] && [ ! -f "$key.council-done" ] && [ ! -f "$key.registered" ]; }; then
      herdr_available && close_review_tab "${repo#*/}#$number"
      log "unwatching $repo#$number ($state, involved=$involved, approved=$approved)"
      if [ "$state" != OPEN ]; then
        if ! clear_dead_execution "$key" || ! take_execution "$key"; then
          printf '%s\t%s\n' "$repo" "$number" >>"$next"; continue
        fi
        rm -f "$key".{status,seen,watermark,council-done,council-clean,approval-pending,approval-body,registered,skipped,exhausted,delta-done,unconfigured,verify-unconfigured,token,claimed,paused}
        release_execution "$key"
      fi
      continue
    fi
    if [ "$approved" = true ]; then
      if [ -f "$key.approval-pending" ]; then
        rm -f "$key.approval-pending" "$key.approval-body"
        log "$repo#$number approval already confirmed on @${sha:0:8}; pending cleared"
      fi
    elif [ "$draft" = false ]; then
      consider "$me" "$repo" "$number" "$sha" "$url" </dev/null
    fi
    printf '%s\t%s\n' "$repo" "$number" >>"$next"
  done <"$WATCHED"
  mv "$next" "$WATCHED"
  remove_finished_clones
}

stop_everything() {
  local pidfile pid
  mkdir -p "$STATE_DIR"
  touch "$KILL_SWITCH"
  rm -f "$STATE_DIR/requests/ready"
  while IFS= read -r pidfile; do
    pid="$(cat "$pidfile" 2>/dev/null)"
    run_alive "${pidfile%.pid}" || continue
    kill_tree "$pid" TERM
    echo "stopped review run $pid ($(basename "${pidfile%.pid}"))"
  done < <(find "$RUNS" -maxdepth 1 -name '*.pid' 2>/dev/null)
  echo "kill switch on: $KILL_SWITCH (rm it to resume)"
}

main() {
  umask 077
  [ "${1:-}" = stop ] && { stop_everything; exit 0; }
  mkdir -p "$STATE_DIR" "$REPORTS" "$RUNS" "$STATE_DIR/diagnostics" "$(dirname "$LOG")"
  chmod 700 "$STATE_DIR" "$REPORTS" "$RUNS" "$STATE_DIR/diagnostics" || exit 1
  RUNS="$(cd "$RUNS" && pwd -P)" || exit 1
  touch "$WATCHED"
  [ "$(perl -e 'print((stat shift)[7] // 0)' "$LOG")" -lt "$LOG_MAX_BYTES" ] || mv -f "$LOG" "$LOG.1"
  exec >>"$LOG" 2>&1
  [ -f "$KILL_SWITCH" ] && exit 0
  acquire_lock "$LOCK_DIR" 'watch\.sh' || { log "previous tick still running, skip"; exit 0; }
  trap 'rm -rf "$LOCK_DIR"' EXIT
  check_claude_cli || exit 1
  [ -x "$COUNCIL" ] || { log "pr-council-review not found at $COUNCIL"; exit 1; }
  [ -x "$RUNNER" ] || { log "review runner not found at $RUNNER"; exit 1; }
  local me
  me="$(gh api user --jq .login 2>/dev/null)" || { log "gh not authenticated"; exit 1; }
  [ -n "$me" ] || { log "gh answered no login"; exit 1; }
  write_watch_heartbeat "$me" || exit 1
  write_review_request_ready "$me" || exit 1
  discover_requested | merge_into_watched
  ingest_council_registrations "$me" || exit 1
  ingest_review_requests "$me" || exit 1
  [ -f "$KILL_SWITCH" ] && exit 0
  process_watched "$me"
  find "$REPORTS" -type f -exec chmod 600 {} +
  find "$REPORTS" -type f -mtime +30 -delete 2>/dev/null
  local artifact artifact_key
  while IFS= read -r artifact; do
    artifact_key="${artifact%%.launch.*}"
    run_reserved "$artifact_key" || rm -f "$artifact"
  done < <(find "$RUNS" -maxdepth 1 -type f -name '*.launch.*' -mtime +30)
  while IFS= read -r artifact; do
    artifact_key="$RUNS/${artifact##*/}"
    artifact_key="${artifact_key%%.launch.*}"
    run_reserved "$artifact_key" || rm -f "$artifact"
  done < <(find "$STATE_DIR/diagnostics" -type f -mtime +30 2>/dev/null)
}

[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"
