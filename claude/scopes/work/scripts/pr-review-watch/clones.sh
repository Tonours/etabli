#!/bin/bash

temp_clone_dir() { printf '%s/%s' "$TEMP_CLONES" "${1//\//__}"; }

ensure_clone() {
  local repo="$1" dir
  find_clone "$repo" && return 0
  dir="$(temp_clone_dir "$repo")"
  if [ ! -d "$dir/.git" ]; then
    rm -rf "$dir"
    mkdir -p "$TEMP_CLONES"
    log "cloning $repo into $dir" >&2
    command gh repo clone "$repo" "$dir" -- --quiet --filter=blob:none </dev/null >/dev/null 2>&1 || { rm -rf "$dir"; return 1; }
  fi
  printf '%s' "$dir"
}

repo_has_live_run() {
  local pidfile
  while IFS= read -r pidfile; do
    run_alive "${pidfile%.pid}" && return 0
  done < <(find "$RUNS" -maxdepth 1 -name "${1//\//_}_*.pid")
  return 1
}

remove_finished_clones() {
  local dir repo
  [ -d "$TEMP_CLONES" ] || return 0
  while IFS= read -r dir; do
    repo="$(basename "$dir")"
    repo="${repo/__//}"
    awk -F'\t' -v r="$repo" '$1 == r {found=1} END {exit !found}' "$WATCHED" && continue
    repo_has_live_run "$repo" && continue
    rm -rf "$dir"
    log "removed temporary clone of $repo"
  done < <(find "$TEMP_CLONES" -mindepth 1 -maxdepth 1 -type d)
}
