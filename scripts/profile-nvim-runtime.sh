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

local function setup_tab_fixture()
  local fixture_root = vim.fs.joinpath(tmp, "redraw")
  local paths = {
    vim.fs.joinpath(fixture_root, "alpha", "src", "index.ts"),
    vim.fs.joinpath(fixture_root, "beta", "src", "index.ts"),
    vim.fs.joinpath(fixture_root, "gamma", "src", "index.ts"),
    vim.fs.joinpath(fixture_root, "alpha", "tests", "main.ts"),
    vim.fs.joinpath(fixture_root, "beta", "tests", "main.ts"),
    vim.fs.joinpath(fixture_root, "gamma", "tests", "main.ts"),
    vim.fs.joinpath(fixture_root, "alpha", "docs", "readme.md"),
    vim.fs.joinpath(fixture_root, "beta", "docs", "readme.md"),
  }

  for _, path in ipairs(paths) do
    write_file(path, { "export const value = 1", "" })
  end

  vim.cmd.cd(fixture_root)
  vim.cmd.edit(vim.fn.fnameescape(paths[1]))
  for index = 2, #paths do
    vim.cmd.tabnew()
    vim.cmd.edit(vim.fn.fnameescape(paths[index]))
  end

  require("config.statusline").invalidate()
end

local function measure_redraw()
  setup_tab_fixture()

  local statusline = require("config.statusline")

  local total_tabline, avg_tabline = measure(120, function()
    statusline.invalidate()
    statusline.tabline()
  end)
  report("tabline redraw", 120, total_tabline, avg_tabline, "8 tabs / duplicate names")

  vim.cmd.cd(root)
  local total_project, avg_project = measure(250, function()
    statusline.invalidate()
    statusline.project_label()
  end)
  report("project label", 250, total_project, avg_project)
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
  local conform_plugin = require("lazy.core.config").plugins["conform.nvim"]
  local prettier_condition = conform_plugin
    and conform_plugin.opts
    and conform_plugin.opts.formatters
    and conform_plugin.opts.formatters.prettier
    and conform_plugin.opts.formatters.prettier.condition

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

local function measure_repo_root_misses()
  local outside_root = vim.fs.joinpath(tmp, "outside-git")
  local outside_file = vim.fs.joinpath(outside_root, "notes.txt")
  write_file(outside_file, { "outside" })

  local diff = require("config.review.diff")

  local cold_total, cold_avg = measure(1, function()
    diff.repo_root(outside_file)
  end)
  report("repo root miss cold", 1, cold_total, cold_avg, "non-git file")

  local warm_total, warm_avg = measure(50, function()
    diff.repo_root(outside_file)
  end)
  report("repo root miss warm", 50, warm_total, warm_avg, "negative cache")
end

local function measure_review()
  local review_root = vim.fs.joinpath(tmp, "review-project")
  local files = {
    vim.fs.joinpath(review_root, "src", "alpha.ts"),
    vim.fs.joinpath(review_root, "src", "beta.ts"),
    vim.fs.joinpath(review_root, "docs", "notes.md"),
  }

  for index, path in ipairs(files) do
    write_file(path, {
      string.format("export const value%d = %d", index, index),
      string.format("export const next%d = %d", index, index + 1),
      "",
    })
  end

  git(review_root, { "init" })
  git(review_root, { "add", "." })
  git(review_root, {
    "-c",
    "user.name=Nvim Perf",
    "-c",
    "user.email=nvim-perf@example.com",
    "commit",
    "-m",
    "initial",
  })

  for index, path in ipairs(files) do
    write_file(path, {
      string.format("export const value%d = %d", index, index * 10),
      string.format("export const next%d = %d", index, index + 1),
      "",
    })
  end

  local diff = require("config.review.diff")
  local review_items = require("config.review.items")
  local state = require("config.review.state")
  local annotations = require("config.review.annotations")
  local context = assert(state.context_for_repo(review_root))
  local items = assert(diff.collect_all(review_root))

  for _, item in ipairs(items) do
    assert(state.set_status(context, item, "needs-rework"))
  end

  vim.cmd.cd(review_root)
  vim.cmd.edit(vim.fn.fnameescape(files[1]))
  vim.cmd.vsplit(vim.fn.fnameescape(files[2]))
  vim.cmd.tabnew()
  vim.cmd.edit(vim.fn.fnameescape(files[3]))

  diff.clear_cache()

  local signature_total, signature_avg = measure(8, function()
    review_items.repo_change_signature(review_root)
  end)
  report("review signature", 8, signature_total, signature_avg, "raw diff + content hashes")

  local cold_total, cold_avg = measure(1, function()
    annotations.refresh_repo(review_root)
  end)
  report("review refresh cold", 1, cold_total, cold_avg, "3 buffers / 3 files")

  local warm_total, warm_avg = measure(8, function()
    annotations.refresh_repo(review_root)
  end)
  report("review refresh warm", 8, warm_total, warm_avg, "cached diff / grouped render")

  state.clear(context)
end

io.write(string.format("Neovim runtime perf baseline for %s\n", root))
sleep(160)
measure_redraw()
measure_save()
measure_repo_root_misses()
measure_review()
measure_focus()
LUA
}

require_tool nvim
require_tool git
write_profile_lua
cd "$ROOT_DIR"

env XDG_CONFIG_HOME="$ROOT_DIR" XDG_STATE_HOME="$TMP_DIR/state" NVIM_PERF_ROOT="$ROOT_DIR" NVIM_PERF_TMP="$TMP_DIR" \
  nvim -i NONE --headless -u "$ROOT_DIR/nvim/init.lua" \
  "+lua dofile([[$PROFILE_LUA]])" +qa
