local function fail(message)
  vim.api.nvim_err_writeln("nvim UI smoke failed: " .. message)
  vim.cmd("cquit 1")
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

if vim.fn.exists("&winborder") == 1 then
  assert_true(vim.o.winborder == "single", "global float border should use single-line chrome")
end

local ui_specs = require("plugins.ui")
local neo_tree_spec = ui_specs[2]
local bufferline_spec = ui_specs[3]
assert_true(neo_tree_spec.opts.popup_border_style == "single", "neo-tree popups should match review borders")
assert_true(
  bufferline_spec.opts.options.offsets[1].text == "files",
  "bufferline sidebar label should use the same compact lowercase chrome as review"
)

local which_key_specs = require("plugins.which-key")
assert_true(which_key_specs[1].opts.win.border == "single", "which-key should match review borders")

local editor_specs = require("plugins.editor")
local gitsigns_spec = editor_specs[2]
assert_true(gitsigns_spec.opts.preview_config.border == "single", "gitsigns preview should match review borders")

local telescope_specs = require("plugins.telescope")
local ok_telescope_opts, telescope_opts = pcall(telescope_specs[1].opts)
if ok_telescope_opts then
  assert_true(telescope_opts.defaults.border == true, "telescope should render explicit borders")
  assert_true(
    telescope_opts.defaults.borderchars[1] == "─",
    "telescope should use single-line border characters"
  )
end

print("nvim UI smoke ok")
