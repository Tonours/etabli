#!/usr/bin/env bash
# Core library for etabli.claude-relaunch.
# Sourced by every entrypoint; never executed directly.
#
# State model (TSV, one pending relaunch per line, keyed by pane_id):
#   due_epoch|pane_id|agent_name|agent_session|cwd|created_epoch|note

set -euo pipefail

HERDR_BIN="${HERDR_BIN_PATH:-$(command -v herdr || true)}"
HERDR_BIN="${HERDR_BIN:-herdr}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${HERDR_CLAUDE_RELAUNCH_STATE_DIR:-${HERDR_PLUGIN_STATE_DIR:-}}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/herdr/plugins/etabli.claude-relaunch}"
STATE_FILE="$STATE_DIR/crons"
LOG_FILE="$STATE_DIR/watcher.log"
ENABLED_FILE="$STATE_DIR/watcher.enabled"
LOCK_DIR="$STATE_DIR/.lock"
LAUNCHD_LABEL="com.etabli.herdr-claude-relaunch"
PLIST_PATH="$HOME/Library/LaunchAgents/$LAUNCHD_LABEL.plist"
DEFAULT_RETRY_S=2700    # 45 min re-probe when the reset time is unparseable
RETRY_UNREACHABLE_S=600 # 10 min retry when the herdr server is unreachable
ENTRY_MAX_AGE_S=43200   # drop entries older than 12 h
CRON_ENTRY="* * * * * /bin/bash $PLUGIN_ROOT/scripts/watch.sh"
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
      if ((age > 120)); then
        rm -rf "$LOCK_DIR"
        continue
      fi
      return 0 # another watcher holds the lock; skip this tick
    fi
    sleep 5
  done
  trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' RETURN
  "$@"
}

# --- state I/O (atomic: tmp + mv) -------------------------------------------
read_entries() { grep -v '^[[:space:]]*#' "$STATE_FILE" 2>/dev/null | grep -v '^[[:space:]]*$' || true; }

entry_field() { # entry_field <line> <index 1..7>
  printf '%s\n' "$1" | awk -F'|' -v i="$2" '{print $i}'
}

write_entries() { # write_entries <full text>
  local tmp
  tmp="${STATE_FILE}.tmp.$$"
  printf '%s\n' "$1" >"$tmp"
  mv "$tmp" "$STATE_FILE"
}

remove_entry() { # by pane_id
  local pane="$1"
  write_entries "$(read_entries | awk -F'|' -v p="$pane" '$2 != p')"
}

entry_for_pane() { read_entries | awk -F'|' -v p="$1" '$2 == p' | head -1; }

upsert_entry() { # upsert_entry <due> <pane> <name> <session> <cwd> <note>
  local due="$1" pane="$2" name="$3" session="$4" cwd="$5" note="$6"
  note="$(printf '%s' "$note" | tr '|' ' ' | tr '\t' ' ' | cut -c1-60)"
  local rest
  rest="$(read_entries | awk -F'|' -v p="$pane" '$2 != p')"
  printf '%s|%s|%s|%s|%s|%d|%s\n' "$due" "$pane" "$name" "$session" "$cwd" "$(now_epoch)" "$note" >"$STATE_FILE.new.$$"
  {
    [[ -n "$rest" ]] && printf '%s\n' "$rest"
    cat "$STATE_FILE.new.$$"
  } >"${STATE_FILE}.tmp.$$"
  rm -f "$STATE_FILE.new.$$"
  mv "${STATE_FILE}.tmp.$$" "$STATE_FILE"
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
    printf '%s' "$raw" | jq -r '.result.agents[]? | select(.agent=="claude") | [.pane_id, (.cwd // ""), (.agent_session.value // ""), (.agent_status // "")] | @tsv' 2>/dev/null || true
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$raw" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for a in d.get("result", {}).get("agents", []):
    if a.get("agent") == "claude":
        s = a.get("agent_session") or {}
        print("\t".join([a.get("pane_id", ""), a.get("cwd") or "", s.get("value", ""), a.get("agent_status", "")]))
' 2>/dev/null || true
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

pane_alive() { "$HERDR_BIN" pane read "$1" --source detection --lines 2 >/dev/null 2>&1; }

# --- scan / fire -------------------------------------------------------------
# scan_pane sets the global SCAN_PANE_LIMITED=1 when a usage-limit banner was
# detected (scheduled or rescheduled), so callers can count detections without
# relying on the return code (always 0).
scan_pane() { # scan_pane <pane> <cwd> <session> — schedule when limited
  SCAN_PANE_LIMITED=0
  local pane="$1" cwd="$2" session="$3"
  local text line reset due
  text="$(read_detection "$pane")" || return 0
  line="$(detect_limit_lines "$text" | tail -1)"
  [[ -n "$line" ]] || return 0
  SCAN_PANE_LIMITED=1
  local reset_text
  reset_text="$(extract_reset_text "$line")"
  reset="$(parse_until_epoch "$reset_text")"
  due="${reset:-$(($(now_epoch) + DEFAULT_RETRY_S))}"
  local existing note="limited"
  existing="$(entry_for_pane "$pane")"
  note="$(printf '%s' "$reset_text" | cut -c1-40)"
  note="${note:-limited}"
  if [[ -n "$existing" ]]; then
    local old_due
    old_due="$(entry_field "$existing" 1)"
    if ((due > old_due + 120 || due < old_due - 120)); then
      upsert_entry "$due" "$pane" claude "$session" "$cwd" "$note"
      log "rescheduled $pane due=$due ($note)"
    fi
  else
    upsert_entry "$due" "$pane" claude "$session" "$cwd" "$note"
    log "scheduled $pane due=$due ($note)"
    notify "claude usage limit hit" "$pane — auto-relaunch scheduled ($note)"
  fi
}

scan_all() {
  state_init
  expire_entries
  local found=0 pane cwd session _status
  while IFS=$'\t' read -r pane cwd session _status; do
    [[ -n "$pane" ]] || continue
    scan_pane "$pane" "$cwd" "$session" || true
    if ((SCAN_PANE_LIMITED)); then found=$((found + 1)); fi
  done < <(list_claude_agents)
  local total
  total="$(read_entries | wc -l | tr -d '[:space:]')"
  printf 'claude agents scanned, %d newly limited, %d pending relaunch(s)\n' "$found" "${total:-0}"
}

expire_entries() {
  local now keep
  now="$(now_epoch)"
  keep="$(read_entries | awk -F'|' -v cutoff=$((now - ENTRY_MAX_AGE_S)) '$6 >= cutoff')"
  write_entries "$keep"
}

fire_entry() { # fire_entry <line>
  local line="$1"
  local due pane name session cwd _created note
  due="$(entry_field "$line" 1)"
  pane="$(entry_field "$line" 2)"
  name="$(entry_field "$line" 3)"
  session="$(entry_field "$line" 4)"
  cwd="$(entry_field "$line" 5)"
  _created="$(entry_field "$line" 6)"
  note="$(entry_field "$line" 7)"

  # target resolution: pane first, then same claude session elsewhere
  if ! agent_alive_claude "$pane" && [[ -n "$session" ]]; then
    local p _c s _st
    while IFS=$'\t' read -r p _c s _st; do
      [[ -n "$p" && "$s" == "$session" ]] && {
        pane="$p"
        log "retargeted session -> $pane"
        break
      }
    done < <(list_claude_agents)
  fi

  if agent_alive_claude "$pane"; then
    local text line2 reset
    text="$(read_detection "$pane")" || text=""
    line2="$(detect_limit_lines "$text" | tail -1)"
    if [[ -n "$line2" ]]; then
      reset="$(parse_until_epoch "$(extract_reset_text "$line2")")"
      if [[ -z "$reset" ]]; then
        reset=$(($(now_epoch) + DEFAULT_RETRY_S))
        upsert_entry "$reset" "$pane" "$name" "$session" "$cwd" "re-probe"
        log "still limited $pane, unparsed reset, retry at $reset"
        return 0
      fi
      if ((reset > $(now_epoch) + 60)); then
        upsert_entry "$reset" "$pane" "$name" "$session" "$cwd" "re-probe"
        log "still limited $pane, pushed to $reset"
        return 0
      fi
      # stale banner with a past/near reset time: fall through and relaunch
    fi
    if "$HERDR_BIN" agent prompt "$pane" "$RELAYOUT_PROMPT" >/dev/null 2>&1; then
      "$HERDR_BIN" agent wait "$pane" --timeout 90000 >/dev/null 2>&1 || true
      remove_entry "$pane"
      log "relaunched (prompt) $pane"
      notify "claude relaunched" "$pane after usage limit reset"
    else
      remove_entry "$pane"
      log "prompt failed for $pane, dropped"
      notify "claude relaunch failed" "prompt rejected on $pane"
    fi
    return 0
  fi

  if pane_alive "$pane"; then
    if "$HERDR_BIN" pane run "$pane" claude --continue >/dev/null 2>&1; then
      local _i detected=0
      for _i in 1 2 3 4 5 6; do
        sleep 10
        if agent_alive_claude "$pane"; then
          detected=1
          break
        fi
      done
      remove_entry "$pane"
      if ((detected)); then
        log "relaunched (claude --continue) $pane"
        notify "claude relaunched" "$pane resumed via claude --continue"
      else
        log "claude not detected after resume on $pane"
        notify "claude relaunch uncertain" "no claude detected on $pane after claude --continue"
      fi
    else
      remove_entry "$pane"
      log "pane run failed for $pane, dropped"
    fi
    return 0
  fi

  if ! "$HERDR_BIN" pane list >/dev/null 2>&1; then
    # herdr server unreachable: agent/pane probes are inconclusive, keep the
    # entry and retry later instead of dropping it for good.
    local retry=$(($(now_epoch) + RETRY_UNREACHABLE_S))
    upsert_entry "$retry" "$pane" "$name" "$session" "$cwd" "herdr unreachable, retry"
    log "herdr unreachable, kept $pane, retry at $retry"
    return 0
  fi

  remove_entry "$pane"
  log "pane $pane gone, dropped entry"
  notify "claude relaunch skipped" "$pane no longer exists"
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
    if crontab -l 2>/dev/null | grep -qF "$CRON_ENTRY"; then
      echo "cron"
    else
      echo "off"
    fi
  fi
}

install_watcher() {
  mkdir -p "$STATE_DIR" "$(dirname "$PLIST_PATH")"
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
    <string>$PLUGIN_ROOT/scripts/watch.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HERDR_CLAUDE_RELAUNCH_STATE_DIR</key><string>$STATE_DIR</string>
    <key>HERDR_BIN_PATH</key><string>$(command -v herdr || echo herdr)</string>
  </dict>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$STATE_DIR/watcher.out</string>
  <key>StandardErrorPath</key><string>$STATE_DIR/watcher.err</string>
</dict>
</plist>
PLIST
    mv "${PLIST_PATH}.tmp" "$PLIST_PATH"
    launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
  else
    (
      crontab -l 2>/dev/null | grep -vF "$CRON_ENTRY"
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
    crontab -l 2>/dev/null | grep -vF "$CRON_ENTRY" | crontab - || true
  fi
  rm -f "$ENABLED_FILE"
}
