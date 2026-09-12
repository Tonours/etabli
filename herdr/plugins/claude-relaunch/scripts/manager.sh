#!/usr/bin/env bash
# Popup entrypoint `manager`: list pending relaunches and manage them.
# Keys: [r] refresh  [w] watcher on/off  [1-9] delete entry  [s] fire now  [q] quit
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
state_init

human_countdown() { # seconds -> "in 2h05" / "now"
  local s="$1"
  ((s <= 0)) && {
    echo "now"
    return
  }
  local h=$((s / 3600)) m=$(((s % 3600) / 60))
  if ((h > 0)); then printf 'in %dh%02d' "$h" "$m"; else printf 'in %dm' "$m"; fi
}

fmt_due() {
  if date -r "$1" '+%a %H:%M' >/dev/null 2>&1; then
    date -r "$1" '+%a %H:%M'
  else date -d "@$1" '+%a %H:%M'; fi
}

draw() {
  clear
  echo "── claude relaunch crons ────────────────────────────────"
  echo "watcher: $(watcher_status)   [w] toggle"
  echo
  local lines pane idx=0 due cd note
  lines="$(read_entries)"
  if [[ -z "$lines" ]]; then
    echo "  (no pending relaunch)"
  else
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      idx=$((idx + 1))
      due="$(entry_field "$line" 1)"
      pane="$(entry_field "$line" 2)"
      cd="$(entry_field "$line" 5)"
      note="$(entry_field "$line" 7)"
      if [[ "$note" == paused:* ]]; then
        printf '  [%d] paused %s (%s)\n' "$idx" "$pane" "$note"
        continue
      fi
      printf '  [%d] %-9s %s %-18s (%s)\n' "$idx" "$(fmt_due "$due")" "$(human_countdown $((due - $(now_epoch))))" "$pane  ${cd##*/}" "$note"
    done <<<"$lines"
  fi
  echo
  echo "  [r] refresh   [s] fire due now   [1-9] delete   [q] quit"
}

on_exit() { clear; }
trap on_exit EXIT

while true; do
  draw
  IFS= read -rsn1 key || exit 0
  case "$key" in
  q | Q) exit 0 ;;
  r | R) continue ;;
  w | W)
    if [[ -e "$ENABLED_FILE" ]]; then remove_watcher; else install_watcher; fi
    continue
    ;;
  s | S)
    with_lock fire_due
    continue
    ;;
  *) ;;
  esac
  if [[ "$key" =~ [1-9] ]]; then
    total=$(read_entries | grep -c . || true)
    ((key <= total)) || continue
    pane="$(read_entries | sed -n "${key}p" | awk -F'|' '{print $2}')"
    if [[ -n "$pane" ]]; then
      with_lock remove_entry "$pane"
      log "entry $pane deleted from manager"
    fi
  fi
done
