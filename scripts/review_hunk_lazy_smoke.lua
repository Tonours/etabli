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
local original_session_exists = hunk.session_exists
local original_add_comment = hunk.add_comment
local original_review_prompt = hunk.review_prompt
local opened = 0
local add_attempted = false
local prompt_attempted = false

hunk.is_available = function()
  return true
end
hunk.session_exists = function()
  return false
end
hunk.add_comment = function()
  add_attempted = true
  return { result = { commentId = "unexpected" } }
end
hunk.review_prompt = function()
  prompt_attempted = true
  return "unexpected"
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
  vim.cmd.edit(vim.fn.fnameescape((vim.env.XDG_CONFIG_HOME or vim.fn.getcwd()) .. "/README.md"))
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  hunk_flow.annotate_current_hunk()
  hunk_flow.prepare_review("claude")
end)

hunk.review_prompt = original_review_prompt
hunk.add_comment = original_add_comment
hunk.session_exists = original_session_exists
hunk.open_or_reload = original_open_or_reload
hunk.is_available = original_is_available

assert_true(ok, err or "default Hunk inbox failed")
assert_true(opened == 4, "Hunk inbox, no-session annotation, and no-session agent review should open the live watched diff")
assert_true(not add_attempted, "Hunk annotation should not add a comment before a live session exists")
assert_true(not prompt_attempted, "Hunk agent review should not dispatch a prompt before a live session exists")
assert_not_loaded("config.review")
assert_not_loaded("config.review.hunk_local_adapter")
assert_not_loaded("config.review.items")
assert_not_loaded("config.review.providers")
assert_not_loaded("config.review.state")

print("hunk lazy smoke ok")
