#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
PROFILE_LUA="$TMP_DIR/event_profile.lua"

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

started_ms() {
	awk '/--- NVIM STARTED ---/{print $1}' "$1"
}

print_delta() {
	local clean_ms="$1"
	local config_ms="$2"
	LC_ALL=C awk -v clean="$clean_ms" -v config="$config_ms" 'BEGIN { printf "%.3f", config - clean }'
}

run_startuptime() {
	local mode="$1"
	local log_path="$2"
	shift 2

	if [[ "$mode" == "clean" ]]; then
		env XDG_CONFIG_HOME="$ROOT_DIR" XDG_STATE_HOME="$TMP_DIR/state" \
			nvim -i NONE --clean --headless --startuptime "$log_path" "$@" +qa >/dev/null 2>&1
		return
	fi

	env XDG_CONFIG_HOME="$ROOT_DIR" XDG_STATE_HOME="$TMP_DIR/state" \
		nvim -i NONE --headless -u "$ROOT_DIR/nvim/init.lua" --startuptime "$log_path" "$@" +qa >/dev/null 2>&1
}

write_profile_lua() {
	cat >"$PROFILE_LUA" <<'LUA'
local event = assert(vim.env.NVIM_PERF_EVENT, "NVIM_PERF_EVENT is required")
local pattern = vim.env.NVIM_PERF_PATTERN
local label = vim.env.NVIM_PERF_LABEL or event
local uv = vim.uv or vim.loop
local started = uv.hrtime()

if pattern and pattern ~= "" then
  vim.api.nvim_exec_autocmds(event, { pattern = pattern, modeline = false })
else
  vim.api.nvim_exec_autocmds(event, { modeline = false })
end

local elapsed_ms = (uv.hrtime() - started) / 1e6
print(string.format("%s dispatch: %.3fms", label, elapsed_ms))
LUA
}

profile_lua_cmd() {
	printf '+lua local ok, err = pcall(dofile, [[%s]]); if not ok then vim.api.nvim_err_writeln(tostring(err)); vim.cmd("cquit 1") end' "$PROFILE_LUA"
}

run_event_profile() {
	local label="$1"
	local event="$2"
	local pattern="$3"
	shift 3

	printf '\n== %s\n' "$label"
	env XDG_CONFIG_HOME="$ROOT_DIR" XDG_STATE_HOME="$TMP_DIR/state" \
		NVIM_PERF_EVENT="$event" NVIM_PERF_PATTERN="$pattern" NVIM_PERF_LABEL="$label" \
		nvim -i NONE --headless -u "$ROOT_DIR/nvim/init.lua" "$@" \
		"$(profile_lua_cmd)" +qa 2>&1
}

report_scenario() {
	local title="$1"
	shift

	local clean_log="$TMP_DIR/${title// /-}-clean.log"
	local config_log="$TMP_DIR/${title// /-}-config.log"

	run_startuptime clean "$clean_log" "$@"
	run_startuptime config "$config_log" "$@"

	local clean_ms
	local config_ms
	clean_ms="$(started_ms "$clean_log")"
	config_ms="$(started_ms "$config_log")"

	printf '\n== %s\n' "$title"
	printf 'clean:  %sms\n' "$clean_ms"
	printf 'config: %sms\n' "$config_ms"
	printf 'delta:  %sms\n' "$(print_delta "$clean_ms" "$config_ms")"
}

require_tool nvim
write_profile_lua
cd "$ROOT_DIR"

printf 'Neovim perf baseline for %s\n' "$ROOT_DIR"

report_scenario 'empty startup'
report_scenario 'code file open' nvim/init.lua
report_scenario 'markdown file open' README.md
run_event_profile 'VeryLazy after code file open' User VeryLazy nvim/init.lua
run_event_profile 'first InsertEnter on code file' InsertEnter '' nvim/init.lua
