local function fail(message)
  vim.api.nvim_err_writeln("hunk lazy smoke failed: " .. message)
  vim.cmd("cquit 1")
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

local function assert_not_loaded(name)
  assert_true(package.loaded[name] == nil, name .. " should not be loaded by the default Hunk path")
end

vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
vim.cmd("cd " .. vim.fn.fnameescape(vim.env.XDG_CONFIG_HOME or vim.fn.getcwd()))

assert_not_loaded("config.review")
assert_not_loaded("config.review.hunk_local_adapter")
assert_not_loaded("config.review.items")
assert_not_loaded("config.review.providers")
assert_not_loaded("config.review.state")

local hunk = require("config.review.hunk")
local hunk_flow = require("config.review.hunk_flow")
local original_is_available = hunk.is_available
local original_open_or_reload = hunk.open_or_reload
local opened = 0

hunk.is_available = function()
  return true
end

hunk.open_or_reload = function(context, raw_args)
  assert_true(context.repo ~= nil and context.repo ~= "", "Hunk inbox should resolve a git repo directly")
  assert_true(raw_args == "diff --watch", "Hunk inbox should open the live watched diff")
  opened = opened + 1
  return true
end

local ok, err = pcall(function()
  hunk_flow.open_inbox()
  hunk_flow.open_inbox({ status = "needs-rework" })
end)

hunk.open_or_reload = original_open_or_reload
hunk.is_available = original_is_available

assert_true(ok, err or "default Hunk inbox failed")
assert_true(opened == 2, "Hunk inbox should open for default and legacy-compatible arguments")
assert_not_loaded("config.review")
assert_not_loaded("config.review.hunk_local_adapter")
assert_not_loaded("config.review.items")
assert_not_loaded("config.review.providers")
assert_not_loaded("config.review.state")

print("hunk lazy smoke ok")
