#!/usr/bin/env bash

cw_tmux_target_for_path_in_session() {
    local session_name="$1"
    local target_path="$2"
    local canonical_target=""

    canonical_target="$(cw_canon_path "$target_path" 2>/dev/null || printf "%s" "$target_path")"

    tmux list-panes -t "$session_name" -F '#{session_name}:#{window_index}	#{pane_current_path}' 2>/dev/null \
        | awk -F '	' -v target="$canonical_target" '$2 == target || index($2, target "/") == 1 {print $1; exit}'
}

cw_tmux_target_for_path() {
    local target_path="$1"
    local canonical_target=""

    canonical_target="$(cw_canon_path "$target_path" 2>/dev/null || printf "%s" "$target_path")"

    tmux list-panes -a -F '#{session_name}:#{window_index}	#{pane_current_path}' 2>/dev/null \
        | awk -F '	' -v target="$canonical_target" '$2 == target || index($2, target "/") == 1 {print $1; exit}'
}

cw_tmux_window_ids_for_path() {
    local target_path="$1"
    local canonical_target=""

    canonical_target="$(cw_canon_path "$target_path" 2>/dev/null || printf "%s" "$target_path")"

    tmux list-panes -a -F '#{window_id}	#{pane_current_path}' 2>/dev/null \
        | awk -F '	' -v target="$canonical_target" '$2 == target || index($2, target "/") == 1 {print $1}' \
        | awk '!seen[$0]++'
}

cw_close_tmux_windows_for_path() {
    local target_path="$1"
    local window_id=""

    command -v tmux >/dev/null 2>&1 || return 0
    tmux list-sessions >/dev/null 2>&1 || return 0

    while IFS= read -r window_id; do
        [ -n "$window_id" ] || continue
        tmux kill-window -t "$window_id" >/dev/null 2>&1 || true
    done < <(cw_tmux_window_ids_for_path "$target_path")
}
