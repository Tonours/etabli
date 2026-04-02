#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing tool: %s\n' "$1" >&2
    exit 1
  }
}

run_step() {
  local label="$1"
  shift
  printf '\n==> %s\n' "$label"
  "$@"
}

require_tool bun
require_tool nvim
require_tool git

cd "$ROOT_DIR"

run_step \
  "Targeted OPS Bun tests" \
  bun test \
  ./pi/extensions/__tests__/ops-snapshot.test.ts \
  ./pi/extensions/__tests__/runtime-status.test.ts \
  ./pi/extensions/__tests__/block-google-providers.test.ts

run_step \
  "OPS Neovim smoke" \
  env XDG_CONFIG_HOME="$ROOT_DIR" \
  nvim --headless -u "$ROOT_DIR/nvim/init.lua" \
  "+lua dofile([[$ROOT_DIR/scripts/ops_smoke.lua]])" \
  +qa

run_step \
  "Review Neovim smoke" \
  env XDG_CONFIG_HOME="$ROOT_DIR" \
  nvim --headless -u "$ROOT_DIR/nvim/init.lua" \
  "+lua dofile([[$ROOT_DIR/scripts/review_smoke.lua]])" \
  +qa

run_step \
  "Pi extension suite" \
  bash -lc "cd '$ROOT_DIR/pi' && bun test ./extensions/__tests__/*.test.ts"

run_step "git diff --check" git diff --check

printf '\nPASS: OPS local verification runner completed.\n'
printf 'Manual follow-up: run Claude /ops-status in a real Claude session against this cwd snapshot.\n'
