#!/bin/bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="${PR_REVIEW_WATCH_STATE_DIR:-$HOME/.claude/state/pr-review-watch}"
WATCHED="$STATE_DIR/watched.tsv"
REPORTS="$STATE_DIR/reports"
RUNS="$STATE_DIR/runs"
LOCK_DIR="$STATE_DIR/lock"
KILL_SWITCH="$STATE_DIR/off"
LOG="${PR_REVIEW_WATCH_LOG:-$HOME/.claude/logs/pr-review-watch.log}"
COUNCIL="${PR_REVIEW_WATCH_COUNCIL:-$HOME/.claude/scripts/pr-council-review/run.sh}"
RUNNER="$HERE/review-run.sh"
HERDR_WORKSPACE="${PR_REVIEW_WATCH_HERDR_WORKSPACE:-pr-reviews}"
MAX_CONCURRENT="${PR_REVIEW_WATCH_MAX_CONCURRENT:-2}"
MAX_ATTEMPTS="${PR_REVIEW_WATCH_MAX_ATTEMPTS:-3}"
MAX_RUNS_PER_DAY="${PR_REVIEW_WATCH_MAX_RUNS_PER_DAY:-20}"
SETTLE_SECONDS="${PR_REVIEW_WATCH_SETTLE:-600}"
MAX_DIFF_LINES="${PR_REVIEW_WATCH_MAX_DIFF_LINES:-5000}"
LAUNCH_GRACE_SECONDS=180
CLONE_ROOTS=("$HOME/work" "$HOME/work/zendesk")
TEMP_CLONES="$STATE_DIR/clones"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
. "$HERE/herdr.sh"
. "$HERE/../pr-council-review/lib.sh"
. "$HERE/clones.sh"

log() { echo "$(date '+%F %T') $*"; }

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo $$ >"$LOCK_DIR/pid"
    trap 'rm -rf "$LOCK_DIR"' EXIT
    return 0
  fi
  local holder
  holder="$(cat "$LOCK_DIR/pid" 2>/dev/null)"
  if [ -n "$holder" ] && ps -p "$holder" -o command= 2>/dev/null | grep -q 'watch\.sh'; then
    return 1
  fi
  rm -rf "$LOCK_DIR"
  acquire_lock
}

discover_requested() {
  gh search prs "user-review-requested:@me" --state=open --limit 100 \
    --json repository,number --jq '.[] | [.repository.nameWithOwner, .number] | @tsv'
}

merge_into_watched() {
  local repo number
  while IFS=$'\t' read -r repo number; do
    [ -n "$repo" ] || continue
    if ! awk -F'\t' -v r="$repo" -v n="$number" '$1==r && $2==n {found=1} END {exit !found}' "$WATCHED"; then
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

run_key() { printf '%s/%s_%s' "$RUNS" "${1//\//_}" "$2"; }

run_alive() {
  local pid
  pid="$(cat "$1.pid" 2>/dev/null)"
  [ -n "$pid" ] && ps -p "$pid" -o command= 2>/dev/null | grep -q 'review-run\.sh'
}

running_count() {
  local pidfile count=0
  while IFS= read -r pidfile; do
    run_alive "${pidfile%.pid}" && count=$((count + 1))
  done < <(find "$RUNS" -maxdepth 1 -name '*.pid')
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
  echo $(( $(date +%s) - $(stat -f %m "$1.status" 2>/dev/null || date +%s) ))
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

diff_lines() {
  gh pr view "$2" --repo "$1" --json additions,deletions --jq '.additions + .deletions' </dev/null
}

write_launcher() {
  local launcher="$1" name value
  shift
  {
    echo '#!/bin/bash'
    env | grep -E '^(PR_REVIEW_WATCH_|PR_COUNCIL_|PR_REVIEW_USAGE_LOG=)' | while IFS='=' read -r name value; do
      printf 'export %s=%q\n' "$name" "$value"
    done
    printf 'export PR_REVIEW_WATCH_STATE_DIR=%q\n' "$STATE_DIR"
    printf 'exec'
    printf ' %q' "$@"
    echo
  } >"$launcher"
  chmod +x "$launcher"
}

pr_snapshot() {
  gh pr view "$2" --repo "$1" --json state,isDraft,headRefOid,url,reviewRequests,latestReviews </dev/null \
    | jq -r --arg me "$3" '[
      .state, .isDraft, .headRefOid, .url,
      ((([.reviewRequests[].login] + [.latestReviews[].author.login]) | index($me)) != null),
      ([.latestReviews[] | select(.author.login == $me)] | length > 0),
      ([.latestReviews[] | select(.author.login == $me and .state == "APPROVED")] | length > 0)
    ] | @tsv'
}

next_attempt() {
  local key="$1" sha="$2" s_sha s_mode s_rc s_attempts
  IFS=$'\t' read -r s_sha s_mode s_rc s_attempts <<<"$(read_status "$key")"
  if [ "$s_sha" != "$sha" ]; then
    echo 1
    return
  fi
  case "$s_rc" in
    0) echo done ;;
    running)
      if [ "$(status_age "$key")" -lt "$LAUNCH_GRACE_SECONDS" ]; then echo wait
      elif [ "$s_attempts" -ge "$MAX_ATTEMPTS" ]; then echo exhausted
      else echo $((s_attempts + 1)); fi ;;
    *) [ "$s_attempts" -ge "$MAX_ATTEMPTS" ] && echo exhausted || echo $((s_attempts + 1)) ;;
  esac
}

launch() {
  local repo="$1" number="$2" sha="$3" url="$4" mode="$5" since="$6" key="$7" attempt="$8"
  local clone report label
  clone="$(ensure_clone "$repo")" || {
    log "cannot clone $repo, skip $repo#$number"
    notify "PR review skipped" "$repo#$number: cannot clone $repo" "$url"
    return 1
  }
  report="$REPORTS/${repo//\//_}-$number-${sha:0:8}-$mode.md"
  label="${repo#*/}#$number"
  printf '%s\t%s\trunning\t%s\n' "$sha" "$mode" "$attempt" >"$key.status"
  echo "$repo#$number@$sha" >>"$(launches_file)"
  write_launcher "$key.launch" "$RUNNER" "$mode" "$repo" "$number" "$sha" "$since" "$url" "$report" "$key"
  if herdr_available && open_review_tab "$label" "$clone" "$(printf '%q' "$key.launch")"; then
    log "$mode $repo#$number @${sha:0:8} attempt $attempt opened in herdr $HERDR_WORKSPACE/$label"
  else
    (cd "$clone" && nohup "$key.launch" >/dev/null 2>&1 &)
    log "$mode $repo#$number @${sha:0:8} attempt $attempt started headless (herdr unavailable)"
  fi
}

retry_pending_approval() {
  local repo="$1" number="$2" sha="$3" url="$4" key="$5" pending_sha
  pending_sha="$(cut -f1 "$key.approval-pending" 2>/dev/null)"
  if [ "$pending_sha" != "$sha" ]; then
    rm -f "$key.approval-pending"
    return
  fi
  "$RUNNER" approve "$repo" "$number" "$sha" - "$url" "$REPORTS/${repo//\//_}-$number-${sha:0:8}-approve.md" "$key" </dev/null \
    | grep -E '^=== (approved|approval)' | while IFS= read -r line; do log "$repo#$number $line"; done
}

consider() {
  local me="$1" repo="$2" number="$3" sha="$4" url="$5" reviewed="$6" key attempt age size mode since
  key="$(run_key "$repo" "$number")"
  run_alive "$key" && { log "$repo#$number review still running, wait"; return; }
  if [ -f "$key.approval-pending" ]; then
    retry_pending_approval "$repo" "$number" "$sha" "$url" "$key"
    return
  fi
  attempt="$(next_attempt "$key" "$sha")"
  case "$attempt" in
    done|wait) return ;;
    exhausted) log "$repo#$number @${sha:0:8} failed $MAX_ATTEMPTS times, giving up on this sha"; return ;;
  esac
  age="$(seen_age "$key" "$sha")"
  [ "${age:-0}" -ge "$SETTLE_SECONDS" ] || { log "$repo#$number @${sha:0:8} first seen ${age}s ago, settling"; return; }
  size="$(diff_lines "$repo" "$number" 2>/dev/null || echo 0)"
  if [ "${size:-0}" -gt "$MAX_DIFF_LINES" ]; then
    if [ "$(cat "$key.too-big" 2>/dev/null)" != "$sha" ]; then
      echo "$sha" >"$key.too-big"
      log "$repo#$number @${sha:0:8} changes $size lines (> $MAX_DIFF_LINES), left to a human"
      notify "PR too big for auto-review" "$repo#$number: $size changed lines" "$url"
    fi
    return
  fi
  [ "$(running_count)" -lt "$MAX_CONCURRENT" ] || { log "$repo#$number queued: $MAX_CONCURRENT reviews running"; return; }
  [ "$(launched_today)" -lt "$MAX_RUNS_PER_DAY" ] || { log "$repo#$number queued: daily cap $MAX_RUNS_PER_DAY reached"; return; }
  mode=council
  since="-"
  if [ "$reviewed" = "true" ] || [ -f "$key.council-done" ]; then
    mode=verify
    since="$(cat "$key.watermark" 2>/dev/null)"
    [ -n "$since" ] || since="$(last_review_sha "$repo" "$number" "$me" 2>/dev/null)"
    [ -n "$since" ] && [ "$since" != "-" ] || since="$(cat "$key.council-done" 2>/dev/null || echo -)"
  fi
  launch "$repo" "$number" "$sha" "$url" "$mode" "$since" "$key" "$attempt"
}

process_watched() {
  local me="$1" repo number state draft sha url involved reviewed approved
  local next="$WATCHED.next"
  : >"$next"
  while IFS=$'\t' read -r repo number _; do
    [ -n "$repo" ] || continue
    IFS=$'\t' read -r state draft sha url involved reviewed approved <<<"$(pr_snapshot "$repo" "$number" "$me" 2>/dev/null)"
    if [ -z "${state:-}" ]; then
      printf '%s\t%s\n' "$repo" "$number" >>"$next"
      continue
    fi
    if [ "$state" != "OPEN" ] || [ "$involved" != "true" ] || [ "$approved" = "true" ]; then
      herdr_available && close_review_tab "${repo#*/}#$number"
      log "unwatching $repo#$number ($state, involved=$involved, approved=$approved)"
      [ "$state" = OPEN ] || rm -f "$(run_key "$repo" "$number")".{status,seen,watermark,council-done,council-clean,approval-pending,too-big}
      continue
    fi
    [ "$draft" = "false" ] && consider "$me" "$repo" "$number" "$sha" "$url" "$reviewed" </dev/null
    printf '%s\t%s\n' "$repo" "$number" >>"$next"
  done <"$WATCHED"
  mv "$next" "$WATCHED"
  remove_finished_clones
}

stop_everything() {
  local pidfile pid
  mkdir -p "$STATE_DIR"
  touch "$KILL_SWITCH"
  while IFS= read -r pidfile; do
    pid="$(cat "$pidfile" 2>/dev/null)"
    run_alive "${pidfile%.pid}" || continue
    kill_tree "$pid" TERM
    echo "stopped review run $pid ($(basename "${pidfile%.pid}"))"
  done < <(find "$RUNS" -maxdepth 1 -name '*.pid' 2>/dev/null)
  echo "kill switch on: $KILL_SWITCH (rm it to resume)"
}

main() {
  [ "${1:-}" = stop ] && { stop_everything; exit 0; }
  mkdir -p "$STATE_DIR" "$REPORTS" "$RUNS" "$(dirname "$LOG")"
  touch "$WATCHED"
  exec >>"$LOG" 2>&1
  [ -f "$KILL_SWITCH" ] && exit 0
  acquire_lock || { log "previous tick still running, skip"; exit 0; }
  [ -x "$COUNCIL" ] || { log "pr-council-review not found at $COUNCIL"; exit 1; }
  [ -x "$RUNNER" ] || { log "review runner not found at $RUNNER"; exit 1; }
  local me
  me="$(gh api user --jq .login 2>/dev/null)" || { log "gh not authenticated"; exit 1; }
  discover_requested | merge_into_watched
  process_watched "$me"
  find "$REPORTS" -type f -mtime +30 -delete 2>/dev/null
}

[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"
