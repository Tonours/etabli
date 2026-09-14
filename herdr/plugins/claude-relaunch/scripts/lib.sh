#!/usr/bin/env bash
# Core library for etabli.claude-relaunch.
# Sourced by every entrypoint; never executed directly.
#
# State model (TSV, one pending relaunch per line, keyed by pane_id):
#   due_epoch|pane_id|agent_name|agent_session|cwd|created_epoch|note|attempts|reset_text

set -euo pipefail

HERDR_BIN="${HERDR_BIN_PATH:-$(command -v herdr || true)}"
HERDR_BIN="${HERDR_BIN:-herdr}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${HERDR_CLAUDE_RELAUNCH_STATE_DIR:-${HERDR_PLUGIN_STATE_DIR:-}}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/herdr/plugins/etabli.claude-relaunch}"
STATE_FILE="$STATE_DIR/crons"
SOCKET_FILE="$STATE_DIR/socket"
if [[ -f "$SOCKET_FILE" ]]; then
  saved_socket="$(cat "$SOCKET_FILE")"
  if [[ -n "${HERDR_SOCKET_PATH:-}" && "$HERDR_SOCKET_PATH" != "$saved_socket" ]]; then
    echo "claude-relaunch is bound to another Herdr session" >&2
    return 1
  fi
  export HERDR_SOCKET_PATH="$saved_socket"
fi
LOG_FILE="$STATE_DIR/watcher.log"
ENABLED_FILE="$STATE_DIR/watcher.enabled"
LOCK_DIR="$STATE_DIR/.lock"
LAUNCHD_LABEL="com.etabli.herdr-claude-relaunch"
PLIST_PATH="$HOME/Library/LaunchAgents/$LAUNCHD_LABEL.plist"
DEFAULT_RETRY_S=2700    # 45 min re-probe when the reset time is unparseable
RETRY_UNREACHABLE_S=600 # 10 min retry when the herdr server is unreachable
ENTRY_MAX_AGE_S=43200   # pause active entries older than 12 h
MAX_ATTEMPTS=3
printf -v CRON_COMMAND '%q ' /usr/bin/env "HERDR_CLAUDE_RELAUNCH_STATE_DIR=$STATE_DIR" "HERDR_BIN_PATH=$HERDR_BIN" /bin/bash "$PLUGIN_ROOT/scripts/watch.sh"
# Cron interprets percent even inside shell quotes.
CRON_COMMAND="${CRON_COMMAND//%/\\%}"
CRON_TAG="# etabli.claude-relaunch"
CRON_ENTRY="* * * * * $CRON_COMMAND $CRON_TAG"
RELAYOUT_PROMPT="Continue: the usage limit window has reset — pick up exactly where you left off."

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >>"$LOG_FILE" 2>/dev/null || true; }

notify() {
  local title="$1" body="${2:-}"
  [[ -n "$HERDR_BIN" ]] || return 0
  "$HERDR_BIN" notification show "$title" --body "$body" >/dev/null 2>&1 || true
}

now_epoch() { date +%s; }

state_init() {
  mkdir -p "$STATE_DIR"
  touch "$STATE_FILE"
}

# --- lock (mkdir-based: portable, no flock dependency on macOS) ------------
# Only fire/scan mutations take the lock; stale locks break after 120 s.
with_lock() {
  mkdir -p "$STATE_DIR"
  local tries=0
  until mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries + 1))
    if ((tries > 12)); then
      # stale lock: breaker older than 120 s wins
      local age
      age=$(($(now_epoch) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)))
      local owner
      owner="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
      if ((age > 120)) && { [[ ! "$owner" =~ ^[0-9]+$ ]] || ! kill -0 "$owner" 2>/dev/null; }; then
        rm -rf "$LOCK_DIR"
        continue
      fi
      return 0 # another watcher holds the lock; skip this tick
    fi
    sleep 5
  done
  printf '%s\n' "$$" > "$LOCK_DIR/pid"
  trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' RETURN
  "$@"
}

# --- state I/O (atomic: tmp + mv) -------------------------------------------
read_entries() { grep -v '^[[:space:]]*#' "$STATE_FILE" 2>/dev/null | grep -v '^[[:space:]]*$' || true; }

entry_field() { # entry_field <line> <index 1..9>
  printf '%s\n' "$1" | awk -F'|' -v i="$2" '{print $i}'
}

write_entries() { # write_entries <full text>
  local tmp
  tmp="${STATE_FILE}.tmp.$$"
  printf '%s\n' "$1" >"$tmp" || return 1
  mv "$tmp" "$STATE_FILE" || return 1
}

remove_entry() { # by pane_id
  local pane="$1"
  write_entries "$(read_entries | awk -F'|' -v p="$pane" '$2 != p')"
}

entry_for_pane() { read_entries | awk -F'|' -v p="$1" '$2 == p' | head -1; }

upsert_entry() {
  local due="$1" pane="$2" name="$3" session="$4" cwd="$5" note="$6"
  local existing created attempts reset rest field
  existing="$(entry_for_pane "$pane")"
  created="$(entry_field "$existing" 6)"
  attempts="${7:-$(entry_field "$existing" 8)}"
  reset="${8:-$(entry_field "$existing" 9)}"
  created="${created:-$(now_epoch)}"
  attempts="${attempts:-0}"
  for field in "$pane" "$session" "$cwd" "$note" "$reset"; do
    [[ "$field" != *'|'* && "$field" != *$'\n'* && "$field" != *$'\r'* ]] || return 1
  done
  rest="$(read_entries | awk -F'|' -v p="$pane" '$2 != p')"
  write_entries "$(printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$due" "$pane" "$name" "$session" "$cwd" "$created" "$note" "$attempts" "$reset"; [[ -z "$rest" ]] || printf '%s\n' "$rest")"
}

pause_entry() {
  local line="$1" reason="$2"
  upsert_entry "$(entry_field "$line" 1)" "$(entry_field "$line" 2)" claude \
    "$(entry_field "$line" 4)" "$(entry_field "$line" 5)" "paused: $reason" || return 1
  log "paused $(entry_field "$line" 2): $reason"
  notify "claude relaunch paused" "$reason"
}

# --- reset-time parsing ------------------------------------------------------
# Extract the reset text ("until 5pm", "resets at Tue 7am", ...) from a banner
# line. Always exits 0 (pipefail-safe): no match just prints nothing.
extract_reset_text() {
  { printf '%s\n' "$1" |
    grep -oiE '(until|resets?[[:space:]]+at)[[:space:]]+[^|)│]{1,26}' |
    head -1 |
    sed -E 's/^[[:space:]]*([Uu][Nn][Tt][Ii][Ll]|[Rr][Ee][Ss][Ee][Tt][Ss]?[[:space:]]+[Aa][Tt])[[:space:]]+//' |
    sed -E 's/[[:space:]]+$//'; } || true
}

# Parse a reset text into an epoch (future) or print nothing. perl Time::Local
# keeps this identical on macOS (no GNU date) and Linux.
parse_until_epoch() {
  local raw="${1:-}" now="${2:-$(now_epoch)}"
  [[ -n "$raw" ]] || return 0
  command -v perl >/dev/null 2>&1 || return 0
  perl -MTime::Local - "$raw" "$now" <<'PERL' 2>/dev/null || true
my ($raw, $now) = @ARGV;
$raw = lc($raw); $raw =~ s/\s+/ /g; $raw =~ s/[^a-z0-9: ]//g;
my %wd = (sun=>0, mon=>1, tue=>2, wed=>3, thu=>4, fri=>5, sat=>6);
my ($wdname) = $raw =~ /\b(sun|mon|tue|wed|thu|fri|sat)\b/;
my $tom = ($raw =~ /tomorrow/) ? 1 : 0;
my ($h, $m, $have) = (0, 0, 0);
if ($raw =~ /(\d{1,2})(?::(\d{2}))? ?(am|pm|noon|midnight)/) {
  ($h, $m) = ($1, defined($2) ? $2 : 0);
  my $ap = $3;
  if    ($ap eq 'noon')     { $h = 12; }
  elsif ($ap eq 'midnight') { $h = 0; }
  elsif ($ap eq 'pm')       { $h += 12 if $h < 12; }
  else                      { $h -= 12 if $h == 12; }
  $have = 1;
} elsif ($raw =~ /\b(\d{1,2}):(\d{2})\b/) {
  ($h, $m, $have) = ($1, $2, 1);
}
exit 0 unless $have;
exit 0 if $h > 23 || $m > 59;
my @lt = localtime($now);
my $target = timelocal(0, $m, $h, $lt[3], $lt[4], $lt[5] + 1900);
if (defined $wdname) {
  my $delta = ($wd{$wdname} - $lt[6]) % 7;
  $delta += 7 if $delta < 0;
  $target += $delta * 86400;
  $target += 7 * 86400 if $target <= $now;
} elsif ($tom) {
  $target += 86400;
} else {
  $target += 86400 if $target <= $now;
}
exit 0 if $target <= $now || $target - $now > 7 * 86400;
print int($target);
PERL
}

# --- detection ---------------------------------------------------------------
# Match Claude Code usage-limit banners. Prints the matching lines (may be empty).
detect_limit_lines() {
  printf '%s\n' "$1" |
    grep -iE '(usage|weekly|rate)[ _-]?limit' |
    grep -iE '(reached|exceeded|hit|until|resets)' || true
}

read_detection() { # read_detection <pane> — prints text, rc 1 when unreadable
  "$HERDR_BIN" agent read "$1" --source detection --lines 80 2>/dev/null || return 1
}

# --- herdr agents ------------------------------------------------------------
list_claude_agents() { # prints TSV: pane_id|cwd|session_value|status
  local raw
  raw="$("$HERDR_BIN" agent list 2>/dev/null)" || return 1
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$raw" | jq -r 'if (.result.agents | type) != "array" then error("missing agents") else .result.agents[] end | select(.agent=="claude") | [.pane_id, (.cwd // ""), (.agent_session.value // ""), (.agent_status // "")] | @tsv' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$raw" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
agents = d["result"]["agents"]
if not isinstance(agents, list): sys.exit(1)
for a in agents:
    if a.get("agent") == "claude":
        s = a.get("agent_session") or {}
        print("\t".join([a.get("pane_id", ""), a.get("cwd") or "", s.get("value", ""), a.get("agent_status", "")]))
' 2>/dev/null
  else
    echo "claude-relaunch: jq or python3 required to parse herdr agent list" >&2
    return 1
  fi
}

agent_alive_claude() { # rc 0 when the pane currently hosts a claude agent
  local raw
  raw="$("$HERDR_BIN" agent get "$1" 2>/dev/null)" || return 1
  printf '%s' "$raw" | grep -q '"agent"[[:space:]]*:[[:space:]]*"claude"'
}

# --- scan / fire -------------------------------------------------------------
# scan_pane sets the global SCAN_PANE_LIMITED=1 when a usage-limit banner was
# detected (scheduled or rescheduled), so callers can count detections without
# relying on the return code (always 0).
scan_pane() {
  SCAN_PANE_LIMITED=0
  local pane="$1" cwd="$2" session="$3" text line reset_text due existing
  if [[ -n "$session" ]] && read_entries | awk -F'|' -v s="$session" '$4 == s {found=1} END {exit !found}'; then return 0; fi
  text="$(read_detection "$pane")" || return 0
  line="$(detect_limit_lines "$text" | tail -1)"
  [[ -n "$line" ]] || return 0
  SCAN_PANE_LIMITED=1
  existing="$(entry_for_pane "$pane")"
  if [[ -n "$existing" ]]; then
    # Keep the captured deadline and paused state even if the screen is stale.
    return 0
  fi
  reset_text="$(extract_reset_text "$line")"
  due="$(parse_until_epoch "$reset_text")"
  due="${due:-$(($(now_epoch) + DEFAULT_RETRY_S))}"
  upsert_entry "$due" "$pane" claude "$session" "$cwd" limited 0 "$reset_text"
  log "scheduled $pane due=$due"
  notify "claude usage limit hit" "$pane - relaunch scheduled"
}

scan_all() {
  state_init
  expire_entries
  local found=0 pane cwd session row agents
  agents="$(list_claude_agents)" || return 1
  while IFS= read -r row; do
    [[ -n "$row" ]] || continue
    pane="$(printf '%s\n' "$row" | cut -f1)"
    cwd="$(printf '%s\n' "$row" | cut -f2)"
    session="$(printf '%s\n' "$row" | cut -f3)"
    scan_pane "$pane" "$cwd" "$session" || true
    if ((SCAN_PANE_LIMITED)); then found=$((found + 1)); fi
  done <<< "$agents"
  local total
  total="$(read_entries | wc -l | tr -d '[:space:]')"
  printf 'claude agents scanned, %d newly limited, %d pending relaunch(s)\n' "$found" "${total:-0}"
}

expire_entries() {
  local line created
  while IFS= read -r line; do
    [[ -n "$line" && "$(entry_field "$line" 7)" != paused:* ]] || continue
    created="$(entry_field "$line" 6)"
    if [[ ! "$created" =~ ^[0-9]+$ ]] || ((created < $(now_epoch) - ENTRY_MAX_AGE_S)); then
      pause_entry "$line" "expired; inspect before rearming"
    fi
  done < <(read_entries)
}

fire_entry() {
  local line="$1" pane session cwd attempts agents match live_pane live_cwd live_session state
  pane="$(entry_field "$line" 2)"
  session="$(entry_field "$line" 4)"
  cwd="$(entry_field "$line" 5)"
  attempts="$(entry_field "$line" 8)"
  [[ "$(entry_field "$line" 7)" != paused:* ]] || return 0
  if [[ -z "$session" || ! "$attempts" =~ ^[0-9]+$ ]]; then
    pause_entry "$line" "missing session identity or legacy state"
    return 0
  fi
  if ((attempts >= MAX_ATTEMPTS)); then
    pause_entry "$line" "retry limit reached"
    return 0
  fi
  if ! agents="$(list_claude_agents)"; then
    upsert_entry "$(($(now_epoch) + RETRY_UNREACHABLE_S))" "$pane" claude "$session" "$cwd" "server unavailable" "$((attempts + 1))"
    return 0
  fi
  # Match native identity first. A reused pane must never receive a prompt.
  match="$(printf '%s\n' "$agents" | awk -F '\t' -v s="$session" '$3 == s')"
  if [[ -z "$match" || "$match" == *$'\n'* ]]; then
    pause_entry "$line" "session missing or ambiguous"
    return 0
  fi
  live_pane="$(printf '%s\n' "$match" | cut -f1)"
  live_cwd="$(printf '%s\n' "$match" | cut -f2)"
  live_session="$(printf '%s\n' "$match" | cut -f3)"
  state="$(printf '%s\n' "$match" | cut -f4)"
  if [[ "$state" != idle && "$state" != done ]]; then
    pause_entry "$line" "session is $state; inspect before rearming"
    return 0
  fi
  local text reset_text old_reset reset limit_line captured_reset
  text="$(read_detection "$live_pane")" || {
    upsert_entry "$(($(now_epoch) + RETRY_UNREACHABLE_S))" "$pane" claude "$session" "$cwd" "unreadable screen" "$((attempts + 1))"
    return 0
  }
  limit_line="$(detect_limit_lines "$text" | tail -1)"
  reset_text="$(extract_reset_text "$limit_line")"
  old_reset="$(entry_field "$line" 9)"
  if [[ -n "$limit_line" ]]; then
    captured_reset="$(parse_until_epoch "$old_reset" "$(entry_field "$line" 6)")"
    if [[ "$reset_text" != "$old_reset" || -z "$captured_reset" ]]; then
      reset="$(parse_until_epoch "$reset_text")"
      if [[ -n "$reset" ]]; then
        upsert_entry "$reset" "$pane" claude "$session" "$cwd" "new reset time" "$((attempts + 1))" "$reset_text"
      else
        upsert_entry "$(($(now_epoch) + DEFAULT_RETRY_S))" "$pane" claude "$session" "$cwd" "unresolved reset; re-probe" "$((attempts + 1))"
      fi
      return 0
    fi
  fi
  # Re-read identity immediately before input, including after a pane move.
  agents="$(list_claude_agents)" || {
    upsert_entry "$(($(now_epoch) + RETRY_UNREACHABLE_S))" "$pane" claude "$session" "$cwd" "server unavailable" "$((attempts + 1))"
    return 0
  }
  if ! printf '%s\n' "$agents" | awk -F '\t' -v p="$live_pane" -v s="$live_session" '$3 == s {count++; if ($1 == p && ($4 == "idle" || $4 == "done")) ok=1} END {exit !(ok && count == 1)}'; then
    pause_entry "$line" "session changed before input"
    return 0
  fi
  # Persist intent before input: a killed watcher must not submit it twice.
  pause_entry "$line" "prompt pending or outcome uncertain; inspect before rearming" || return 1
  if "$HERDR_BIN" agent prompt "$live_pane" "$RELAYOUT_PROMPT" --wait --timeout 90000 >/dev/null 2>&1; then
    pause_entry "$line" "continuation submitted; inspect before rearming"
    log "relaunched original session $session on $live_pane"
  else
    # A timeout can mean input was sent. Never retry a possibly submitted turn.
    pause_entry "$line" "prompt outcome uncertain; inspect before rearming"
  fi
}

fire_due() {
  state_init
  expire_entries
  local now line due pane
  now="$(now_epoch)"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    due="$(entry_field "$line" 1)"
    pane="$(entry_field "$line" 2)"
    [[ "$(entry_field "$line" 7)" != paused:* ]] || continue
    [[ "$due" =~ ^[0-9]+$ ]] || { pause_entry "$line" "invalid deadline"; continue; }
    if ((due <= now)); then
      fire_entry "$line" || true
    fi
  done < <(read_entries)
}

# --- launchd / cron watcher --------------------------------------------------
watcher_status() {
  if [[ ! -e "$ENABLED_FILE" ]]; then
    echo "off"
    return 0
  fi
  if [[ "$(uname)" == "Darwin" ]]; then
    local st
    st="$(launchctl print "gui/$(id -u)/$LAUNCHD_LABEL" 2>/dev/null | grep -E '^[[:space:]]*state =' | head -1 | sed 's/.*= //')" || true
    echo "${st:-enabled (state unknown)}"
  else
    if crontab -l 2>/dev/null | grep -qF "$CRON_TAG"; then
      echo "cron"
    else
      echo "off"
    fi
  fi
}

xml_escape() { python3 -c 'import html,sys; print(html.escape(sys.argv[1], quote=True))' "$1"; }

install_watcher() {
  if [[ -z "${HERDR_SOCKET_PATH:-}" ]]; then
    echo "Enable claude-relaunch from the intended Herdr session" >&2
    return 1
  fi
  mkdir -p "$STATE_DIR" "$(dirname "$PLIST_PATH")"
  printf '%s\n' "$HERDR_SOCKET_PATH" > "$SOCKET_FILE"
  if [[ "$(uname)" == "Darwin" ]]; then
    cat >"${PLIST_PATH}.tmp" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LAUNCHD_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$(xml_escape "$PLUGIN_ROOT/scripts/watch.sh")</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HERDR_CLAUDE_RELAUNCH_STATE_DIR</key><string>$(xml_escape "$STATE_DIR")</string>
    <key>HERDR_BIN_PATH</key><string>$(xml_escape "$HERDR_BIN")</string>
  </dict>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$(xml_escape "$STATE_DIR/watcher.out")</string>
  <key>StandardErrorPath</key><string>$(xml_escape "$STATE_DIR/watcher.err")</string>
</dict>
</plist>
PLIST
    mv "${PLIST_PATH}.tmp" "$PLIST_PATH"
    launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
  else
    (
      { crontab -l 2>/dev/null || true; } | { grep -vF "$CRON_TAG" | grep -vF "$PLUGIN_ROOT/scripts/watch.sh" || true; }
      echo "$CRON_ENTRY"
    ) | crontab -
  fi
  : >"$ENABLED_FILE"
}

remove_watcher() {
  if [[ "$(uname)" == "Darwin" ]]; then
    launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
    rm -f "$PLIST_PATH"
  else
    { crontab -l 2>/dev/null || true; } | { grep -vF "$CRON_TAG" | grep -vF "$PLUGIN_ROOT/scripts/watch.sh" || true; } | crontab - || true
  fi
  rm -f "$ENABLED_FILE"
}
