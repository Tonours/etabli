#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing tool: %s\n' "$1" >&2
    exit 1
  }
}

run_nvim() {
  env XDG_CONFIG_HOME="$ROOT_DIR" XDG_STATE_HOME="$TMP_DIR/state" \
    nvim -i NONE --headless -u "$ROOT_DIR/nvim/init.lua" "$@"
}

run_nvim_legacy_commands() {
  env XDG_CONFIG_HOME="$ROOT_DIR" XDG_STATE_HOME="$TMP_DIR/state-legacy" \
    nvim -i NONE --headless --cmd "let g:etabli_review_legacy_commands = 1" -u "$ROOT_DIR/nvim/init.lua" "$@"
}

run_lua_file() {
  local path="$1"

  run_nvim "+lua local ok, err = pcall(dofile, [[$path]]); if not ok then vim.api.nvim_err_writeln(tostring(err)); vim.cmd('cquit 1') end" +qa
}

require_tool nvim
require_tool git

run_nvim "+lua if not vim.startswith(vim.fn.stdpath('state'), vim.env.XDG_STATE_HOME) then vim.api.nvim_err_writeln('nvim smoke state is not isolated: ' .. vim.fn.stdpath('state')); vim.cmd('cquit 1') end" +qa
run_lua_file "$ROOT_DIR/scripts/nvim_ui_smoke.lua"
run_lua_file "$ROOT_DIR/scripts/review_hunk_lazy_smoke.lua"
run_lua_file "$ROOT_DIR/scripts/review_state_smoke.lua"
run_lua_file "$ROOT_DIR/scripts/review_smoke.lua"
run_lua_file "$ROOT_DIR/scripts/etabli_doctor_smoke.lua"
run_nvim_legacy_commands "+lua local commands = vim.api.nvim_get_commands({}); if commands.ReviewLegacyInbox == nil or commands.ReviewLegacyAnnotate == nil or commands.ReviewSubmit == nil then vim.api.nvim_err_writeln('legacy review commands should be opt-in'); vim.cmd('cquit 1') end" +qa

printf 'nvim smoke test: ok\n'
