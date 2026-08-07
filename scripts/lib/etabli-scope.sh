#!/usr/bin/env bash

etabli_active_scopes() {
  local home_dir="${1:-$HOME}"
  local scope_file="$home_dir/.etabli-scope"
  local declared=""

  if [ -n "${ETABLI_SCOPE:-}" ]; then
    declared="$ETABLI_SCOPE"
  elif [ -f "$scope_file" ]; then
    declared="$(tr -d '[:space:]' <"$scope_file")"
  fi

  case "$declared" in
    work|personal) printf 'shared %s\n' "$declared" ;;
    "") printf 'shared\n' ;;
    *)
      printf 'unknown scope %q in %s: expected work or personal; fix the file or unset ETABLI_SCOPE\n' \
        "$declared" "$scope_file" >&2
      return 2
      ;;
  esac
}
