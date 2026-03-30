#!/usr/bin/env bash

# Source this file from your shell:
#   source /path/to/etabli/scripts/cw-mode-aliases.sh

_cw_mode_aliases_dir() {
  local source_path=""
  local dir=""

  if [ -n "${ZSH_VERSION:-}" ]; then
    source_path="$(eval 'printf %s "${(%):-%N}"')"
  else
    source_path="${BASH_SOURCE[0]}"
  fi

  while [ -L "$source_path" ]; do
    dir="$(cd -P "$(dirname "$source_path")" >/dev/null 2>&1 && pwd)"
    source_path="$(readlink "$source_path")"
    [[ "$source_path" != /* ]] && source_path="${dir}/${source_path}"
  done

  cd -P "$(dirname "$source_path")" >/dev/null 2>&1 && pwd
}

_CW_MODE_ALIASES_DIR="$(_cw_mode_aliases_dir)"
_CW_MODE_BIN="${_CW_MODE_ALIASES_DIR}/cw-mode"

_cw_mode_require_bin() {
  [ -x "$_CW_MODE_BIN" ] || {
    printf 'cw-mode-aliases: missing executable %s\n' "$_CW_MODE_BIN" >&2
    return 1
  }
}

_cw_mode_load() {
  _cw_mode_require_bin || return 1
  eval "$("$_CW_MODE_BIN" "$@" --print-shell)"
}

_cw_mode_enter_main() {
  [ -n "${CW_MODE_MAIN_PATH:-}" ] || {
    printf 'cw-mode-aliases: no main worktree path available\n' >&2
    return 1
  }

  cd "$CW_MODE_MAIN_PATH"
}

cws() {
  _cw_mode_load simple "$@" || return 1
  _cw_mode_enter_main || return 1
}

cwstd() {
  _cw_mode_load standard "$@" || return 1
  _cw_mode_enter_main || return 1
}

cwcmp() {
  _cw_mode_load option-compare "$@" || return 1
  _cw_mode_enter_main || return 1

  printf 'main:     %s\n' "$CW_MODE_MAIN_PATH"
  if [ "${CW_MODE_OPTION_COUNT:-0}" -ge 1 ]; then
    printf 'option-1: %s\n' "$CW_MODE_OPTION_1_PATH"
  fi
  if [ "${CW_MODE_OPTION_COUNT:-0}" -ge 2 ]; then
    printf 'option-2: %s\n' "$CW_MODE_OPTION_2_PATH"
  fi
  if [ "${CW_MODE_OPTION_COUNT:-0}" -ge 3 ]; then
    printf 'option-3: %s\n' "$CW_MODE_OPTION_3_PATH"
  fi
}

cwtmux() {
  _cw_mode_require_bin || return 1
  "$_CW_MODE_BIN" "$@" --print-tmux | bash
}
