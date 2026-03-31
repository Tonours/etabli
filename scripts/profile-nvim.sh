#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
PROFILE_LUA="$TMP_DIR/lazy_profile.lua"

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
    env XDG_CONFIG_HOME="$ROOT_DIR" \
      nvim -i NONE --clean --headless --startuptime "$log_path" "$@" +qa >/dev/null 2>&1
    return
  fi

  env XDG_CONFIG_HOME="$ROOT_DIR" \
    nvim -i NONE --headless -u "$ROOT_DIR/nvim/init.lua" --startuptime "$log_path" "$@" +qa >/dev/null 2>&1
}

write_profile_lua() {
  cat >"$PROFILE_LUA" <<'LUA'
local filter = vim.env.NVIM_PERF_FILTER or ""
local limit = tonumber(vim.env.NVIM_PERF_LIMIT or "12") or 12
local roots = require("lazy.core.util")._profiles or {}
local rows = {}

local function label_for(data)
  if type(data) == "string" then
    return data
  end
  if type(data) ~= "table" then
    return "entry"
  end
  if data.plugin and data.init then
    return string.format("init:%s", data.plugin)
  end
  if data.plugin and data.start then
    return string.format("start-plugin:%s", data.plugin)
  end
  if data.plugin then
    return string.format("plugin:%s", data.plugin)
  end
  if data.event then
    return string.format("event:%s", data.event)
  end
  if data.ft then
    return string.format("ft:%s", data.ft)
  end
  if data.start then
    return string.format("start:%s", data.start)
  end
  if data.import then
    return string.format("import:%s", data.import)
  end
  if data.runtime then
    return string.format("runtime:%s", vim.fs.basename(data.runtime))
  end
  return "entry"
end

local function walk(node, path)
  if type(node) ~= "table" then
    return
  end

  local label = node.name or label_for(node.data)
  local next_path = path
  if label and label ~= "" then
    next_path = path == "" and label or (path .. " > " .. label)
  end

  if type(node.time) == "number" and next_path ~= "" and next_path ~= "lazy" then
    if filter == "" or next_path:find(filter, 1, true) then
      table.insert(rows, {
        label = next_path,
        ms = node.time / 1e6,
      })
    end
  end

  for _, child in ipairs(node) do
    walk(child, next_path)
  end
end

for _, root in ipairs(roots) do
  walk(root, "")
end

table.sort(rows, function(left, right)
  if left.ms == right.ms then
    return left.label < right.label
  end
  return left.ms > right.ms
end)

local seen = {}
local printed = 0
for _, row in ipairs(rows) do
  if not seen[row.label] then
    seen[row.label] = true
    print(string.format("%9.3fms  %s", row.ms, row.label))
    printed = printed + 1
    if printed >= limit then
      break
    end
  end
end
LUA
}

run_profile() {
  local label="$1"
  local filter="$2"
  shift 2

  printf 'top lazy profile (%s)\n' "$label"
  env XDG_CONFIG_HOME="$ROOT_DIR" NVIM_PERF_FILTER="$filter" NVIM_PERF_LIMIT=8 \
    nvim -i NONE --headless -u "$ROOT_DIR/nvim/init.lua" "$@" \
    "+lua dofile([[$PROFILE_LUA]])" +qa 2>&1
}

run_insert_profile() {
  local label="$1"
  shift

  printf 'top lazy profile (%s)\n' "$label"
  env XDG_CONFIG_HOME="$ROOT_DIR" NVIM_PERF_FILTER="event:InsertEnter" NVIM_PERF_LIMIT=8 \
    nvim -i NONE --headless -u "$ROOT_DIR/nvim/init.lua" "$@" \
    "+lua vim.api.nvim_exec_autocmds('InsertEnter', {})" \
    "+lua dofile([[$PROFILE_LUA]])" +qa 2>&1
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
run_profile 'empty startup' 'start:startup'

report_scenario 'code file open' nvim/init.lua
run_profile 'code file open' '' nvim/init.lua

report_scenario 'markdown file open' README.md
run_profile 'markdown file open' '' README.md

printf '\n== first insert on code file\n'
run_insert_profile 'first insert on code file' nvim/init.lua

printf '\n== first insert on markdown file\n'
run_insert_profile 'first insert on markdown file' README.md
