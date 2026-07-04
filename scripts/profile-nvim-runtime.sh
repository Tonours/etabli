#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
PROFILE_LUA="$TMP_DIR/runtime_profile.lua"

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

write_profile_lua() {
  cat >"$PROFILE_LUA" <<'LUA'
local uv = vim.uv or vim.loop
local root = vim.env.NVIM_PERF_ROOT
local tmp = vim.env.NVIM_PERF_TMP
vim.notify = function() end

local function sleep(ms)
  local done = false
  vim.defer_fn(function()
    done = true
  end, ms)
  vim.wait(ms + 100, function()
    return done
  end, 10)
end

local function measure(iterations, fn)
  local start = uv.hrtime()
  for index = 1, iterations do
    fn(index)
  end
  local total = (uv.hrtime() - start) / 1e6
  return total, total / iterations
end

local function report(name, iterations, total, average, extra)
  local suffix = extra and extra ~= "" and ("  " .. extra) or ""
  io.write(string.format("%-24s total=%8.3fms avg=%8.3fms runs=%d%s\n", name, total, average, iterations, suffix))
end

local function write_file(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end

local function git(repo, args)
  local command = vim.list_extend({ "git", "-C", repo }, args)
  local result = vim.system(command, { text = true }):wait()
  if result.code ~= 0 then
    error(table.concat(command, " ") .. "\n" .. (result.stderr or ""), 0)
  end
  return vim.trim(result.stdout or "")
end

local function measure_save()
  local save_root = vim.fs.joinpath(tmp, "save-project")
  local file_path = vim.fs.joinpath(save_root, "sample.ts")
  write_file(vim.fs.joinpath(save_root, "package.json"), {
    '{',
    '  "name": "nvim-perf-save",',
    '  "private": true,',
    '  "devDependencies": {',
    '    "prettier": "*"',
    '  }',
    '}',
  })
  write_file(vim.fs.joinpath(save_root, ".prettierrc"), { '{}' })
  write_file(file_path, { "export const value = 1", "" })

  vim.cmd.cd(save_root)
  vim.cmd.edit(vim.fn.fnameescape(file_path))

  local prettier_available = vim.fn.executable("prettier") == 1
  local conform_spec
  for _, entry in ipairs(require("plugins.lsp")) do
    if entry[1] == "stevearc/conform.nvim" then
      conform_spec = entry
    end
  end
  local prettier_condition = conform_spec
    and conform_spec.opts
    and conform_spec.opts.formatters
    and conform_spec.opts.formatters.prettier
    and conform_spec.opts.formatters.prettier.condition

  if type(prettier_condition) == "function" then
    local detect_total, detect_avg = measure(1, function()
      prettier_condition(nil, { buf = 0, filename = file_path })
    end)
    report(
      "prettier detect cold",
      1,
      detect_total,
      detect_avg,
      string.format("prettier_executable=%s", prettier_available and "yes" or "no")
    )

    local warm_detect_total, warm_detect_avg = measure(40, function()
      prettier_condition(nil, { buf = 0, filename = file_path })
    end)
    report(
      "prettier detect warm",
      40,
      warm_detect_total,
      warm_detect_avg,
      string.format("prettier_executable=%s", prettier_available and "yes" or "no")
    )
  end

  local cold_total, cold_avg = measure(1, function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "export const value = 1",
      "",
    })
    vim.cmd("silent write")
  end)
  report(
    "write path cold",
    1,
    cold_total,
    cold_avg,
    string.format("prettier_executable=%s", prettier_available and "yes" or "no")
  )

  local total_write, avg_write = measure(3, function(index)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      string.format("export const value = %d", index + 1),
      "",
    })
    vim.cmd("silent write")
  end)

  report(
    "write path warm",
    3,
    total_write,
    avg_write,
    string.format("prettier_executable=%s", prettier_available and "yes" or "no")
  )
end

local function measure_focus()
  vim.cmd.cd(root)

  local sync_total, sync_avg = measure(8, function()
    vim.api.nvim_exec_autocmds("FocusGained", { modeline = false })
  end)
  report("focus sync", 8, sync_total, sync_avg)

  local settle_total, settle_avg = measure(3, function()
    vim.api.nvim_exec_autocmds("FocusGained", { modeline = false })
    sleep(180)
  end)
  io.write("\n")
  report("focus settle wait", 3, settle_total, settle_avg, "includes fixed 180ms wait budget")
end

io.write(string.format("Neovim runtime perf baseline for %s\n", root))
sleep(160)
measure_save()
measure_focus()
LUA
}

profile_lua_cmd() {
  printf '+lua local ok, err = pcall(dofile, [[%s]]); if not ok then vim.api.nvim_err_writeln(tostring(err)); vim.cmd("cquit 1") end' "$PROFILE_LUA"
}

require_tool nvim
require_tool git
write_profile_lua
cd "$ROOT_DIR"

env XDG_CONFIG_HOME="$ROOT_DIR" XDG_STATE_HOME="$TMP_DIR/state" NVIM_PERF_ROOT="$ROOT_DIR" NVIM_PERF_TMP="$TMP_DIR" \
  nvim -i NONE --headless -u "$ROOT_DIR/nvim/init.lua" \
  "$(profile_lua_cmd)" +qa
