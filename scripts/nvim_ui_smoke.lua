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
assert_true(neo_tree_spec.opts.popup_border_style == "single", "neo-tree popups should use single-line borders")
assert_true(
  bufferline_spec.opts.options.offsets[1].text == "files",
  "bufferline sidebar label should use compact lowercase chrome"
)
assert_true(bufferline_spec.opts.options.name_formatter == nil, "bufferline must not special-case review buffers")

local which_key_specs = require("plugins.which-key")
assert_true(which_key_specs[1].opts.win.border == "single", "which-key should use single-line borders")
for _, entry in ipairs(which_key_specs[1].opts.spec) do
  if type(entry) == "table" and entry.group == "Review" then
    fail("which-key must not define a Review group")
  end
end

local editor_specs = require("plugins.editor")
local gitsigns_spec = editor_specs[2]
assert_true(gitsigns_spec.opts.preview_config.border == "single", "gitsigns preview should use single-line borders")

local telescope_specs = require("plugins.telescope")
require("config.pack").load("telescope.nvim")
local ok_telescope_opts, telescope_opts = pcall(telescope_specs[1].opts)
assert_true(ok_telescope_opts, "telescope options should be inspectable in the UI smoke")
assert_true(telescope_opts.defaults.border == true, "telescope should render explicit borders")
assert_true(
  telescope_opts.defaults.borderchars[1] == "─",
  "telescope should use single-line border characters"
)

print("nvim UI smoke ok")
