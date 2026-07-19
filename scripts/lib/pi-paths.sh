#!/usr/bin/env bash

pi_agent_npm_dir() {
  local home_dir="${1:-}"

  if [ -z "$home_dir" ]; then
    printf 'pi_agent_npm_dir requires a home directory\n' >&2
    return 2
  fi

  printf '%s/.pi/agent/npm\n' "${home_dir%/}"
}

pi_agent_node_modules_dir() {
  local npm_dir

  npm_dir="$(pi_agent_npm_dir "${1:-}")" || return
  printf '%s/node_modules\n' "$npm_dir"
}
