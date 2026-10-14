#!/bin/bash

herdr_available() {
  command -v herdr >/dev/null && herdr workspace list >/dev/null 2>&1
}

herdr_workspace_lookup() {
  herdr workspace list | jq -r --arg l "$HERDR_WORKSPACE" '.result.workspaces[] | select(.label == $l) | .workspace_id' | head -1
}

herdr_workspace_id() {
  local id created
  id="$(herdr_workspace_lookup)"
  if [ -n "$id" ]; then
    printf '%s\t' "$id"
    return 0
  fi
  created="$(herdr workspace create --label "$HERDR_WORKSPACE" --cwd "$HOME" --no-focus)" || return 1
  printf '%s\t%s' "$(jq -r '.result.workspace.workspace_id' <<<"$created")" "$(jq -r '.result.tab.tab_id' <<<"$created")"
}

herdr_tabs_labelled() {
  herdr tab list --workspace "$1" | jq -r --arg l "$2" '.result.tabs[] | select(.label == $l) | .tab_id'
}

open_review_tab() {
  local label="$1" clone="$2" command="$3" ws root_tab previous old created pane
  IFS=$'\t' read -r ws root_tab <<<"$(herdr_workspace_id)"
  [ -n "$ws" ] || return 1
  previous="$(herdr_tabs_labelled "$ws" "$label")"
  created="$(herdr tab create --workspace "$ws" --cwd "$clone" --label "$label" --no-focus)" || return 1
  pane="$(jq -r '.result.root_pane.pane_id' <<<"$created")"
  for old in $previous $root_tab; do
    herdr tab close "$old" >/dev/null
  done
  herdr pane run "$pane" "$command" >/dev/null
}

close_review_tab() {
  local ws tab
  ws="$(herdr_workspace_lookup)"
  [ -n "$ws" ] || return 0
  for tab in $(herdr_tabs_labelled "$ws" "$1"); do
    herdr tab close "$tab" >/dev/null
  done
}
