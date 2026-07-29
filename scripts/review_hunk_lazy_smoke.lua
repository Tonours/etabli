-- Asserts the in-nvim review/ADE surface is gone (post code-first minimal IDE).
local function fail(message)
  vim.api.nvim_err_writeln("review absence smoke failed: " .. message)
  vim.cmd("cquit 1")
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })

local review_modules = {
  "config.review",
  "config.review.hunk",
  "config.review.hunk_flow",
  "config.review.hunk_rail",
  "config.review.hunk_comment_editor",
  "config.review.providers",
  "config.review.util",
  "config.review.items",
  "config.review.state",
  "config.review.hunk_local_adapter",
}

for _, name in ipairs(review_modules) do
  assert_true(package.loaded[name] == nil, name .. " must not be loaded")
  local ok = pcall(require, name)
  assert_true(not ok, name .. " must not be require-able")
end

local banned_commands = {
  "ReviewInbox",
  "ReviewCurrentHunk",
  "ReviewAnnotate",
  "ReviewHunk",
  "ReviewHunkNextComment",
  "ReviewHunkPrevComment",
  "ReviewHelp",
  "ReviewContext",
  "ReviewClaudeReview",
  "ReviewPiReview",
}

local registered = vim.api.nvim_get_commands({})
for _, command in ipairs(banned_commands) do
  assert_true(registered[command] == nil, ":" .. command .. " must not exist")
end

-- which-key must not declare a Review group
local which_key_specs = require("plugins.which-key")
local spec = which_key_specs[1].opts.spec
for _, entry in ipairs(spec) do
  if type(entry) == "table" and entry.group == "Review" then
    fail("which-key must not define a Review group")
  end
end

-- bufferline must not special-case hunkreview
local ui_specs = require("plugins.ui")
for _, plugin in ipairs(ui_specs) do
  local opts = plugin.opts
  if type(opts) == "table" and opts.options and opts.options.name_formatter then
    fail("bufferline must not keep a review name_formatter")
  end
end

print("review absence smoke ok")
