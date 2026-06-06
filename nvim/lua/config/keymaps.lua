local map = vim.keymap.set
local opts = { silent = true }
local telescope_loader = require("config.telescope")

local function lazy_require(plugin, module)
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    lazy.load({ plugins = { plugin } })
  end

  local ok_module, loaded = pcall(require, module)
  if not ok_module then
    vim.notify(module .. " not available", vim.log.levels.ERROR)
    return nil
  end

  return loaded
end

local function next_terminal_title()
  local max_count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    local count = name:match("^term://terminal%-(%d+)$")
    if count then
      max_count = math.max(max_count, tonumber(count))
    end
  end

  return string.format("terminal-%d", max_count + 1)
end

local function open_terminal_tab(command)
  local title = next_terminal_title()

  vim.cmd.tabnew()
  vim.fn.termopen(command ~= "" and command or vim.o.shell)
  vim.api.nvim_buf_set_name(0, "term://" .. title)
  vim.cmd.startinsert()
end

vim.api.nvim_create_user_command("Terminal", function(command_opts)
  open_terminal_tab(command_opts.args)
end, {
  complete = "shellcmd",
  desc = "Open terminal in new tab",
  nargs = "*",
})

vim.cmd([[cnoreabbrev <expr> term getcmdtype() == ':' && getcmdline() == 'term' ? 'Terminal' : 'term']])
vim.cmd([[cnoreabbrev <expr> terminal getcmdtype() == ':' && getcmdline() == 'terminal' ? 'Terminal' : 'terminal']])

-- Lazy-load telescope on first use, but keep first-call behavior reliable
local telescope_modules = nil

local function load_telescope_modules()
  if telescope_modules then
    return telescope_modules
  end

  local builtin = telescope_loader.require("telescope.builtin")
  if not builtin then
    vim.notify("Telescope not available", vim.log.levels.ERROR)
    return nil
  end

  telescope_modules = {
    builtin = builtin,
  }
  return telescope_modules
end

local function telescope_cmd(cmd, picker_opts)
  return function()
    local ts = load_telescope_modules()
    if not ts then
      return
    end

    ts.builtin[cmd](picker_opts or {})
  end
end

local function open_command_palette()
  local ts = load_telescope_modules()
  if not ts then
    return
  end

  ts.builtin.commands({ prompt_title = "Command Palette" })
end

local function map_editor_aliases(lhs_list, rhs, desc)
  for _, lhs in ipairs(lhs_list) do
    map("n", lhs, rhs, vim.tbl_extend("force", opts, { desc = desc }))
  end
end

local quick_open = telescope_cmd("find_files")
local quick_open_hidden = telescope_cmd("find_files", {
  hidden = true,
  find_command = {
    "fd",
    "--type",
    "f",
    "--hidden",
    "--strip-cwd-prefix",
    "--exclude",
    ".git",
    "--exclude",
    "node_modules",
    "--exclude",
    "dist",
    "--exclude",
    "coverage",
    "--exclude",
    ".cache",
    "--exclude",
    "build",
    "--exclude",
    "out",
  },
})
local live_grep_hidden = telescope_cmd("live_grep", {
  additional_args = function()
    return {
      "--hidden",
      "-g", "!.git",
      "-g", "!node_modules",
      "-g", "!dist",
      "-g", "!coverage",
      "-g", "!.cache",
      "-g", "!build",
      "-g", "!out",
    }
  end,
})

vim.api.nvim_create_user_command("CommandPalette", open_command_palette, {
  desc = "Open command palette",
})

map_editor_aliases({ "<D-p>", "<C-p>" }, quick_open, "Quick open")
map_editor_aliases({ "<D-P>", "<D-S-p>", "<C-S-p>" }, open_command_palette, "Command palette")

map("n", "<leader><space>", quick_open, vim.tbl_extend("force", opts, { desc = "Find files" }))
map("n", "<leader>/", telescope_cmd("live_grep"), vim.tbl_extend("force", opts, { desc = "Live grep" }))
map("n", "<leader>.", telescope_cmd("buffers"), vim.tbl_extend("force", opts, { desc = "Buffers" }))
map("n", "<leader>ff", quick_open, vim.tbl_extend("force", opts, { desc = "Find files" }))
map("n", "<leader>fF", quick_open_hidden, vim.tbl_extend("force", opts, { desc = "Find files incl. hidden" }))
map("n", "<leader>fg", telescope_cmd("live_grep"), vim.tbl_extend("force", opts, { desc = "Live grep" }))
map("n", "<leader>fG", live_grep_hidden, vim.tbl_extend("force", opts, { desc = "Live grep incl. hidden" }))
map("n", "<leader>fw", telescope_cmd("grep_string"), vim.tbl_extend("force", opts, { desc = "Grep current word" }))
map("n", "<leader>fb", telescope_cmd("buffers"), vim.tbl_extend("force", opts, { desc = "Buffers" }))
map("n", "<leader>fo", telescope_cmd("oldfiles"), vim.tbl_extend("force", opts, { desc = "Recent files" }))
map("n", "<leader>fr", function()
  local grug_far = lazy_require("grug-far.nvim", "grug-far")
  if grug_far then
    grug_far.open()
  end
end, vim.tbl_extend("force", opts, { desc = "Find and replace" }))
map("x", "<leader>fr", function()
  local grug_far = lazy_require("grug-far.nvim", "grug-far")
  if grug_far then
    grug_far.with_visual_selection()
  end
end, vim.tbl_extend("force", opts, { desc = "Find and replace selection" }))
map("x", "<Tab>", ">gv", vim.tbl_extend("force", opts, { desc = "Indent selection" }))
map("x", "<S-Tab>", "<gv", vim.tbl_extend("force", opts, { desc = "Unindent selection" }))
map("n", "<leader>fp", function()
  vim.schedule(function()
    require("config.projects_picker").pick_project_recent_files()
  end)
end, vim.tbl_extend("force", opts, { desc = "Project recent files" }))
map("n", "<leader>fe", function()
  require("config.neo_tree").reveal_current_file()
end, vim.tbl_extend("force", opts, { desc = "Reveal current file" }))
map("n", "<leader>ft", function()
  require("config.neo_tree").focus()
end, vim.tbl_extend("force", opts, { desc = "Focus file sidebar" }))

map("n", "<leader>pp", function()
  -- Use schedule for immediate but non-blocking execution
  vim.schedule(function()
    require("config.projects_picker").pick_project()
  end)
end, vim.tbl_extend("force", opts, { desc = "Projects" }))
map("n", "<leader>pr", function()
  require("config.projects").root_current_buffer()
end, vim.tbl_extend("force", opts, { desc = "Project root" }))
map("n", "<leader>ps", function()
  require("config.projects").save_session()
end, vim.tbl_extend("force", opts, { desc = "Save project session" }))
map("n", "<leader>pl", function()
  require("config.projects").load_session()
end, vim.tbl_extend("force", opts, { desc = "Load project session" }))
map("n", "<leader>pi", function()
  require("config.project_runtime").project_info()
end, vim.tbl_extend("force", opts, { desc = "Project info" }))

map("n", "<leader>bn", "<cmd>bnext<cr>", vim.tbl_extend("force", opts, { desc = "Next buffer" }))
map("n", "<leader>bp", "<cmd>bprevious<cr>", vim.tbl_extend("force", opts, { desc = "Previous buffer" }))
map("n", "<leader>bd", function()
  vim.schedule(function()
    local bufremove = lazy_require("mini.bufremove", "mini.bufremove")
    if bufremove then
      bufremove.delete(0, false)
    end
  end)
end, vim.tbl_extend("force", opts, { desc = "Delete buffer" }))

map("n", "<leader>ss", function()
  local ts = load_telescope_modules()
  if ts then
    ts.builtin.lsp_document_symbols()
  end
end, vim.tbl_extend("force", opts, { desc = "Document symbols" }))
map("n", "<leader>sS", function()
  local ts = load_telescope_modules()
  if ts then
    ts.builtin.lsp_dynamic_workspace_symbols()
  end
end, vim.tbl_extend("force", opts, { desc = "Workspace symbols" }))

map("n", "<leader>dd", function()
  local ts = load_telescope_modules()
  if ts then
    ts.builtin.diagnostics({ bufnr = 0 })
  end
end, vim.tbl_extend("force", opts, { desc = "Buffer diagnostics" }))
map("n", "<leader>dD", telescope_cmd("diagnostics"), vim.tbl_extend("force", opts, { desc = "Workspace diagnostics" }))
map("n", "<leader>dl", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Line diagnostics" }))
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, vim.tbl_extend("force", opts, { desc = "Previous diagnostic" }))
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, vim.tbl_extend("force", opts, { desc = "Next diagnostic" }))

map("n", "<leader>cf", function()
  local conform = lazy_require("conform.nvim", "conform")
  if conform then
    conform.format({ async = true, lsp_format = "fallback" })
  end
end, vim.tbl_extend("force", opts, { desc = "Format buffer" }))

map("n", "<leader>ri", function()
  require("config.review").open_inbox()
end, vim.tbl_extend("force", opts, { desc = "Review inbox" }))
map("n", "<leader>rh", function()
  require("config.review").show_current_hunk()
end, vim.tbl_extend("force", opts, { desc = "Review current hunk" }))
map("n", "<leader>ra", function()
  require("config.review").annotate_current_hunk()
end, vim.tbl_extend("force", opts, { desc = "Comment current review line" }))
map("x", "<leader>ra", function()
  require("config.review").annotate_visual_selection()
end, vim.tbl_extend("force", opts, { desc = "Comment selected review range" }))
map("n", "<leader>rr", function()
  require("config.review").resolve_current_comment()
end, vim.tbl_extend("force", opts, { desc = "Resolve review conversation" }))
map("n", "<leader>rs", function()
  require("config.review").select_current_status()
end, vim.tbl_extend("force", opts, { desc = "Set review status" }))
map("n", "<leader>rA", function()
  require("config.review").accept_current_hunk()
end, vim.tbl_extend("force", opts, { desc = "Accept current hunk" }))
map("n", "<leader>rl", function()
  require("config.review").cmd_inline_annotations({ args = "toggle" })
end, vim.tbl_extend("force", opts, { desc = "Toggle review inline annotations" }))

-- Quick navigation between hunks (similar to diagnostics [d ]d)
map("n", "[h", function()
  local gitsigns = lazy_require("gitsigns.nvim", "gitsigns")
  if gitsigns then
    gitsigns.prev_hunk()
  end
end, vim.tbl_extend("force", opts, { desc = "Previous hunk" }))
map("n", "]h", function()
  local gitsigns = lazy_require("gitsigns.nvim", "gitsigns")
  if gitsigns then
    gitsigns.next_hunk()
  end
end, vim.tbl_extend("force", opts, { desc = "Next hunk" }))
map("n", "<leader>rc", function()
  require("config.review").send_current("claude", "revise")
end, vim.tbl_extend("force", opts, { desc = "Claude revise hunk" }))
map("n", "<leader>rC", function()
  require("config.review").send_current("claude", "explain")
end, vim.tbl_extend("force", opts, { desc = "Claude explain hunk" }))
map("n", "<leader>rp", function()
  require("config.review").send_current("pi", "revise")
end, vim.tbl_extend("force", opts, { desc = "Pi revise hunk" }))
map("n", "<leader>rP", function()
  require("config.review").send_current("pi", "explain")
end, vim.tbl_extend("force", opts, { desc = "Pi explain hunk" }))
map("n", "<leader>rbc", function()
  require("config.review").prepare_batch("claude", "needs-rework")
end, vim.tbl_extend("force", opts, { desc = "Claude batch rework" }))
map("n", "<leader>rbp", function()
  require("config.review").prepare_batch("pi", "needs-rework")
end, vim.tbl_extend("force", opts, { desc = "Pi batch rework" }))
map("n", "<leader>rvc", function()
  require("config.review").prepare_review("claude")
end, vim.tbl_extend("force", opts, { desc = "Claude review pass" }))
map("n", "<leader>rvp", function()
  require("config.review").prepare_review("pi")
end, vim.tbl_extend("force", opts, { desc = "Pi review pass" }))

map("n", "<leader>wv", "<cmd>vsplit<cr>", vim.tbl_extend("force", opts, { desc = "Vertical split" }))
map("n", "<leader>wh", "<cmd>split<cr>", vim.tbl_extend("force", opts, { desc = "Horizontal split" }))
map("n", "<leader>wo", "<cmd>only<cr>", vim.tbl_extend("force", opts, { desc = "Only window" }))

map("n", "<C-h>", "<C-w>h", vim.tbl_extend("force", opts, { desc = "Window left" }))
map("n", "<C-j>", "<C-w>j", vim.tbl_extend("force", opts, { desc = "Window down" }))
map("n", "<C-k>", "<C-w>k", vim.tbl_extend("force", opts, { desc = "Window up" }))
map("n", "<C-l>", "<C-w>l", vim.tbl_extend("force", opts, { desc = "Window right" }))

map("n", "<leader>tn", "<cmd>tabnew<cr>", vim.tbl_extend("force", opts, { desc = "New tab" }))
map("n", "<leader>to", "<cmd>tabonly<cr>", vim.tbl_extend("force", opts, { desc = "Only tab" }))
map("n", "<leader>tx", "<cmd>tabclose<cr>", vim.tbl_extend("force", opts, { desc = "Close tab" }))
map("n", "<leader>tl", "<cmd>tabnext<cr>", vim.tbl_extend("force", opts, { desc = "Next tab" }))
map("n", "<leader>th", "<cmd>tabprevious<cr>", vim.tbl_extend("force", opts, { desc = "Previous tab" }))
