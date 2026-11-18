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
. "$HERE/own-only.sh"
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
  pr="$(gh pr view "$2" --repo "$1" --json state,isDraft,headRefOid,url,reviewRequests,latestReviews,author </dev/null)" || return 1
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
      ($review.state == "APPROVED" and $review.commit_id != .headRefOid),
      (.author.login // "" | ascii_downcase)
    ] | @tsv'
}

next_attempt() {
  local key="$1" sha="$2" want="${3:-post}" had=post s_sha s_mode s_rc s_attempts skill
  IFS=$'\t' read -r s_sha s_mode s_rc s_attempts <<<"$(read_status "$key")"
  [ "$s_mode" != dryrun ] || had=dryrun
  # A dry-run's outcome never stands for a posting review of the same head, nor the reverse.
  if [ "$s_sha" != "$sha" ] || [ "$had" != "$want" ]; then
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
        if skill="$(verify_skill)" && verify_settings "$skill" >/dev/null 2>&1; then echo "$s_attempts"
        else echo unconfigured; fi
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
  rm -f "$key.paused" "$key.requested"
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

# This marker is scheduling intent, never proof that a council completed.
marker_holds() {
  local path="$1" sha="$2" me="$3"
  [ -f "$path" ] && [ ! -L "$path" ] || return 1
  [ "$(perl -e 'print((stat shift)[7] // 9999)' "$path")" -le 256 ] || return 1
  [ "$(cat "$path")" = "$sha"$'\t'"$(printf '%s' "$me" | tr '[:upper:]' '[:lower:]')" ]
}
explicit_review_request() { marker_holds "$1.requested" "$2" "$3"; }

consider() {
  local me="$1" repo="$2" number="$3" sha="$4" url="$5" key attempt age size mode since stop dry=0
  [ ! -f "$KILL_SWITCH" ] || return 0
  key="$(run_key "$repo" "$number")"
  # An own PR is reviewed only on the head a dry-run request named, never on its own.
  if [ -e "$key.dryrun" ] || [ -L "$key.dryrun" ]; then
    if marker_holds "$key.dryrun" "$sha" "$me"; then dry=1
    # Another account's dry-run intent never holds this account's posting flow.
    elif ! marker_holds "$key.registered" "$(cut -f1 "$key.registered" 2>/dev/null)" "$me"; then return 0
    fi
  fi
  if own_only && [ "$dry" = 0 ]; then return 0; fi
  run_reserved "$key" && { log "$repo#$number review still running, wait"; return; }
  if [ "$dry" = 0 ] && [ -f "$key.approval-pending" ]; then
    retry_pending_approval "$repo" "$number" "$sha" "$url" "$key"
    return
  fi
  if [ "$dry" = 1 ]; then attempt="$(next_attempt "$key" "$sha" dryrun)"; else attempt="$(next_attempt "$key" "$sha")"; fi
  case "$attempt" in
    done|wait) return ;;
    unconfigured)
      if [ "$(cat "$key.unconfigured" 2>/dev/null)" != "$sha" ]; then
        echo "$sha" >"$key.unconfigured"
        log "$repo#$number @${sha:0:8} verify configuration unavailable: set PR_COUNCIL_VERIFY_SKILL or ~/.config/pr-council-review/verify-skill, or repair ~/.claude/settings.json"
      fi
      return ;;
    exhausted|stopped)
      # A stopped dry-run is kept apart: it never stands for a stopped posting review.
      stop="$key.exhausted"; [ "$dry" = 0 ] || stop="$key.dryrun-exhausted"
      if [ "$(cat "$stop" 2>/dev/null)" != "$sha" ]; then
        echo "$sha" >"$stop"
        if [ "$attempt" = stopped ]; then log "$repo#$number @${sha:0:8} vetoed or incomplete, not retried on this sha"
        else log "$repo#$number @${sha:0:8} failed $MAX_ATTEMPTS times, giving up on this sha"; fi
      fi
      return ;;
  esac
  age="$(seen_age "$key" "$sha")"
  explicit_review_request "$key" "$sha" "$me" || [ "${age:-0}" -ge "$SETTLE_SECONDS" ] || { log "$repo#$number @${sha:0:8} first seen ${age}s ago, settling"; return; }
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
  if [ "$dry" = 1 ]; then
    mode=dryrun
  elif [ -f "$key.council-done" ]; then
    mode=verify
    since="$(cat "$key.watermark" 2>/dev/null)"
    [ -n "$since" ] || since="$(last_review_sha "$repo" "$number" "$me" 2>/dev/null)"
    [ -n "$since" ] && [ "$since" != "-" ] || since="$(cat "$key.council-done" 2>/dev/null || echo -)"
  fi
  launch "$repo" "$number" "$sha" "$url" "$mode" "$since" "$key" "$attempt"
}

process_watched() {
  local me="$1" repo number state draft sha url involved approved stale author key registered_sha registered_login
  local next="$WATCHED.next"
  : >"$next"
  while IFS=$'\t' read -r repo number _; do
    [ -n "$repo" ] || continue
    IFS=$'\t' read -r state draft sha url involved approved stale author <<<"$(pr_snapshot "$repo" "$number" "$me" 2>/dev/null)"
    if [ -z "${state:-}" ]; then
      printf '%s\t%s\n' "$repo" "$number" >>"$next"
      continue
    fi
    if own_only; then
      if [ -z "${author:-}" ]; then
        printf '%s\t%s\n' "$repo" "$number" >>"$next"
        continue
      fi
      if [ "$author" != "$(printf '%s' "$me" | tr '[:upper:]' '[:lower:]')" ]; then
        log "own-only: dropping $repo#$number (another author's pull request)"
        continue
      fi
    fi
    key="$(run_key "$repo" "$number")"
    [ "$state" != OPEN ] || [ ! -f "$key.dryrun" ] || involved=true
    if [ "$state" = OPEN ] && [ -f "$key.registered" ]; then
      IFS=$'\t' read -r registered_sha registered_login <"$key.registered" || registered_login=''
      # A dry-run this account requested on this head needs no posting registration.
      if [ "$registered_login" != "$(printf '%s' "$me" | tr '[:upper:]' '[:lower:]')" ] && ! marker_holds "$key.dryrun" "$sha" "$me"; then
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
        rm -f "$key".{status,seen,watermark,council-done,council-clean,approval-pending,approval-body,registered,requested,dryrun,dryrun-last,dryrun-exhausted,skipped,exhausted,delta-done,unconfigured,verify-unconfigured,token,claimed,paused}
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

cached_author() {
  local id author
  id="$(printf '%s#%s' "$1" "$2" | tr '[:upper:]' '[:lower:]')"
  if author="$(awk -F'\t' -v id="$id" '$1 == id {print $2; found = 1; exit} END {exit !found}' "$AUTHOR_CACHE")"; then
    [ "$author" != - ] && printf '%s' "$author"
    return
  fi
  author="$(pr_author_login "$1" "$2")" || author=-
  printf '%s\t%s\n' "$id" "$author" >>"$AUTHOR_CACHE"
  [ "$author" != - ] && printf '%s' "$author"
}

remove_reservation() {
  local file
  for file in "$1.launch" "$1".launch.*; do
    if [ -e "$file" ] || [ -L "$file" ]; then rm -f "$file"; fi
  done
  rm -f "$1.token" "$1.claimed"
}

write_skip_status() {
  local key="$1" reason="$2" temp
  [ "$(head -1 "$key.status" 2>/dev/null)" != "$reason" ] || return 0
  temp="$(mktemp "$key.status.XXXXXX")" || return 1
  printf '%s\n' "$reason" >"$temp" && mv "$temp" "$key.status"
}

purge_foreign() {
  local me file base key pair author status_mode marker unread=0 next="$WATCHED.next" entry_repo entry_number
  local -a keys=()
  me="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  AUTHOR_CACHE="$(mktemp)" || return 1
  while IFS= read -r key; do
    keys+=("$key")
  done < <(find "$RUNS" -maxdepth 1 \( -type f -o -type l \) | while IFS= read -r file; do
    base="${file##*/}"
    [[ "$base" =~ ^(.+_[0-9]+)\.(registered|council-done|approval-pending|approval-body|token|claimed|launch|launch\..+|status)$ ]] && printf '%s/%s\n' "$RUNS" "${BASH_REMATCH[1]}"
  done | sort -u)
  for key in ${keys[@]+"${keys[@]}"}; do
    if ! pair="$(own_only_key_pr "$key")" || ! author="$(cached_author "${pair% *}" "${pair#* }")"; then
      unread=$((unread + 1))
      log "own-only purge: author of ${key##*/} unreadable, left as is"
      continue
    fi
    status_mode=''
    [ ! -f "$key.status" ] || IFS=$'\t' read -r _ status_mode _ <"$key.status" || true
    for marker in registered council-done approval-pending approval-body; do rm -f "$key.$marker"; done
    if [ "$author" != "$me" ]; then
      remove_reservation "$key"
      write_skip_status "$key" 'skipped own-only'
      log "own-only purge: ${key##*/} is another author's pull request"
    elif [ -n "$status_mode" ] && [ "$status_mode" != dryrun ]; then
      remove_reservation "$key"
      write_skip_status "$key" 'skipped posting-off'
      log "own-only purge: ${key##*/} mode $status_mode refused"
    fi
  done
  : >"$next"
  while IFS=$'\t' read -r entry_repo entry_number _; do
    [ -n "$entry_repo" ] || continue
    if author="$(cached_author "$entry_repo" "$entry_number")" && [ "$author" != "$me" ]; then
      log "own-only purge: dropping $entry_repo#$entry_number from the watch list"
      continue
    fi
    printf '%s\t%s\n' "$entry_repo" "$entry_number" >>"$next"
  done <"$WATCHED"
  mv "$next" "$WATCHED"
  rm -f "$AUTHOR_CACHE"
  [ "$unread" = 0 ] || return 3
}

purge_foreign_command() {
  local me rc=0
  mkdir -p "$STATE_DIR" "$RUNS" || return 1
  chmod 700 "$STATE_DIR" "$RUNS" || return 1
  RUNS="$(cd "$RUNS" && pwd -P)" || return 1
  touch "$WATCHED"
  acquire_lock "$LOCK_DIR" 'watch\.sh' || { echo "a watcher tick is running, purge not done" >&2; return 75; }
  trap 'rm -rf "$LOCK_DIR"' EXIT
  me="$(own_only_login)" || { echo "gh not authenticated" >&2; return 1; }
  purge_foreign "$me" || rc=$?
  return "$rc"
}

purge_foreign_tick() {
  local me
  own_only || return 0
  me="$(gh api user --jq .login 2>/dev/null)" && [ -n "$me" ] || return 0
  purge_foreign "$me" || true
}

# The pid and every descendant, read before they are signalled.
tree_pids() {
  local child
  printf '%s\n' "$1"
  for child in $(pgrep -P "$1" 2>/dev/null); do tree_pids "$child"; done
}

pid_start() { ps -p "$1" -o lstart= 2>/dev/null; }
pgid_of() { ps -p "$1" -o pgid= 2>/dev/null | tr -d ' '; }

# A process stays the one recorded while its start time is unchanged: a reused pid differs.
pid_alive() {
  local pid="${1%%@*}" stat
  [ "$(pid_start "$pid")" = "${1#*@}" ] || return 1
  stat="$(ps -p "$pid" -o stat= 2>/dev/null)" && [ -n "$stat" ] && [ "${stat#Z}" = "$stat" ]
}

# A group id is not reused while one member lives, so a live member is still the run's.
group_alive() {
  ps -A -o pgid=,stat= 2>/dev/null | awk -v g="$1" '$1 == g && $2 !~ /^Z/ { found = 1 } END { exit !found }'
}

# Records every process of a run and every process group one of them leads.
track_tree() {
  local p g
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    pids+=("$p@$(pid_start "$p")")
    g="$(pgid_of "$p")"
    [ "$g" = "$p" ] && [ "$g" != "$own_group" ] && groups+=("$g")
  done < <(tree_pids "$1")
}

stop_everything() {
  local pidfile key pid entry group wait left own_group
  local -a pids=() groups=()
  own_group="$(pgid_of $$)"
  mkdir -p "$STATE_DIR"
  touch "$KILL_SWITCH"
  rm -f "$STATE_DIR/requests/ready"
  while IFS= read -r pidfile; do
    key="${pidfile%.pid}"
    run_alive "$key" || continue
    # Only a pid whose command is this key's launcher or runner is signalled.
    for pid in "$(cat "$key.pid" 2>/dev/null)" "$(cat "$key.execution/pid" 2>/dev/null)"; do
      process_matches "$pid" "$key" || continue
      track_tree "$pid"
      kill_tree "$pid" TERM
      echo "stopped review run $pid ($(basename "$key"))"
    done
  done < <(find "$RUNS" -maxdepth 1 -name '*.pid' 2>/dev/null)
  for group in ${groups[@]+"${groups[@]}"}; do kill -TERM -- "-$group" 2>/dev/null; done
  # Survivors get KILL; the stop fails while any is still alive.
  for wait in 1 2 3 4 5 6 7 8 9 10 kill 1 2; do
    left=0
    for entry in ${pids[@]+"${pids[@]}"}; do
      pid_alive "$entry" || continue
      left=1
      [ "$wait" != kill ] || kill -KILL "${entry%%@*}" 2>/dev/null
    done
    for group in ${groups[@]+"${groups[@]}"}; do
      group_alive "$group" || continue
      left=1
      [ "$wait" != kill ] || kill -KILL -- "-$group" 2>/dev/null
    done
    [ "$left" = 1 ] || break
    [ "$wait" = kill ] || sleep 1
  done
  echo "kill switch on: $KILL_SWITCH (rm it to resume)"
  [ "$left" = 0 ] || { echo "a review run is still alive after KILL" >&2; return 1; }
}

main() {
  umask 077
  [ "${1:-}" = stop ] && { stop_everything; exit $?; }
  [ "${1:-}" = --purge-foreign ] && { purge_foreign_command; exit $?; }
  mkdir -p "$STATE_DIR" "$REPORTS" "$RUNS" "$STATE_DIR/diagnostics" "$(dirname "$LOG")"
  chmod 700 "$STATE_DIR" "$REPORTS" "$RUNS" "$STATE_DIR/diagnostics" || exit 1
  RUNS="$(cd "$RUNS" && pwd -P)" || exit 1
  touch "$WATCHED"
  [ "$(perl -e 'print((stat shift)[7] // 0)' "$LOG")" -lt "$LOG_MAX_BYTES" ] || mv -f "$LOG" "$LOG.1"
  exec >>"$LOG" 2>&1
  if [ -f "$KILL_SWITCH" ]; then
    if own_only && acquire_lock "$LOCK_DIR" 'watch\.sh'; then
      trap 'rm -rf "$LOCK_DIR"' EXIT
      purge_foreign_tick
    fi
    exit 0
  fi
  acquire_lock "$LOCK_DIR" 'watch\.sh' || { log "previous tick still running, skip"; exit 0; }
  trap 'rm -rf "$LOCK_DIR"' EXIT
  purge_foreign_tick
  check_claude_cli || exit 1
  [ -x "$COUNCIL" ] || { log "pr-council-review not found at $COUNCIL"; exit 1; }
  [ -x "$RUNNER" ] || { log "review runner not found at $RUNNER"; exit 1; }
  local me
  me="$(gh api user --jq .login 2>/dev/null)" || { log "gh not authenticated"; exit 1; }
  [ -n "$me" ] || { log "gh answered no login"; exit 1; }
  write_watch_heartbeat "$me" || exit 1
  write_review_request_ready "$me" || exit 1
  own_only || discover_requested | merge_into_watched
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
