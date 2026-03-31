local map = vim.keymap.set
local opts = { silent = true }
local remap_opts = { remap = true, silent = true }
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

-- Cache for terminal title calculation
local terminal_title_cache = nil
local last_buffer_count = 0
local terminal_scan_cache = {}
local terminal_scan_version = 0

-- Track terminal buffers more efficiently
local function update_terminal_scan_cache()
  local buffers = vim.api.nvim_list_bufs()
  local current_version = #buffers

  if current_version == terminal_scan_version and terminal_scan_cache then
    return terminal_scan_cache
  end

  local max_count = 0
  for _, buf in ipairs(buffers) do
    local name = vim.api.nvim_buf_get_name(buf)
    local count = name:match("^term://terminal%-(%d+)$")
    if count then
      max_count = math.max(max_count, tonumber(count))
    end
  end

  terminal_scan_cache = { max_count = max_count, buf_count = current_version }
  terminal_scan_version = current_version
  return terminal_scan_cache
end

local function next_terminal_title()
  -- Get buffer list once
  local buffers = vim.api.nvim_list_bufs()
  local current_buffer_count = #buffers

  -- Invalidate cache if buffer count changed
  if terminal_title_cache and current_buffer_count == last_buffer_count then
    return terminal_title_cache
  end

  local scan = update_terminal_scan_cache()
  local max_count = scan.max_count

  last_buffer_count = current_buffer_count
  terminal_title_cache = string.format("terminal-%d", max_count + 1)
  return terminal_title_cache
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

local function telescope_cmd(cmd)
  return function()
    local ts = load_telescope_modules()
    if not ts then
      return
    end

    ts.builtin[cmd]()
  end
end

map("n", "<leader><space>", telescope_cmd("find_files"), vim.tbl_extend("force", opts, { desc = "Find files" }))
map("n", "<leader>/", telescope_cmd("live_grep"), vim.tbl_extend("force", opts, { desc = "Live grep" }))
map("n", "<leader>.", telescope_cmd("buffers"), vim.tbl_extend("force", opts, { desc = "Buffers" }))
map("n", "<leader>ff", telescope_cmd("find_files"), vim.tbl_extend("force", opts, { desc = "Find files" }))
map("n", "<leader>fg", telescope_cmd("live_grep"), vim.tbl_extend("force", opts, { desc = "Live grep" }))
map("n", "<leader>fw", telescope_cmd("grep_string"), vim.tbl_extend("force", opts, { desc = "Grep current word" }))
map("n", "<leader>fb", telescope_cmd("buffers"), vim.tbl_extend("force", opts, { desc = "Buffers" }))
map("n", "<leader>fr", telescope_cmd("oldfiles"), vim.tbl_extend("force", opts, { desc = "Recent files" }))
map("n", "<leader>fp", function()
  vim.schedule(function()
    require("config.projects_picker").pick_project_recent_files()
  end)
end, vim.tbl_extend("force", opts, { desc = "Project recent files" }))
map("n", "<leader>fe", "<cmd>NvimTreeFocus<cr>", vim.tbl_extend("force", opts, { desc = "Focus explorer" }))
map("n", "<leader>ft", "<cmd>NvimTreeToggle<cr>", vim.tbl_extend("force", opts, { desc = "Toggle explorer" }))

map("n", "<leader>pp", function()
  -- Use schedule for immediate but non-blocking execution
  vim.schedule(function()
    require("config.projects_picker").pick_project()
  end)
end, vim.tbl_extend("force", opts, { desc = "Projects" }))
map("n", "<leader>pw", function()
  vim.schedule(function()
    require("config.projects_picker").pick_worktree()
  end)
end, vim.tbl_extend("force", opts, { desc = "Worktrees" }))
map("n", "<leader>pW", function()
  vim.schedule(function()
    require("config.projects_picker").create_worktree()
  end)
end, vim.tbl_extend("force", opts, { desc = "New worktree" }))
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
map("n", "<leader>pa", function()
  require("config.ops").show_status()
end, vim.tbl_extend("force", opts, { desc = "OPS status" }))
map("n", "<leader>pA", function()
  require("config.ops").resume()
end, vim.tbl_extend("force", opts, { desc = "OPS resume" }))
map("n", "<leader>pn", function()
  require("config.ops").show_next()
end, vim.tbl_extend("force", opts, { desc = "OPS next" }))
map("n", "<leader>pd", function()
  require("config.ops").show_doctor()
end, vim.tbl_extend("force", opts, { desc = "OPS doctor" }))
map("n", "<leader>pf", function()
  require("config.ops").refresh_review()
end, vim.tbl_extend("force", opts, { desc = "OPS refresh review" }))
map("n", "<leader>pm", function()
  require("config.ops").show_mode()
end, vim.tbl_extend("force", opts, { desc = "OPS mode" }))
map("n", "<leader>po", function()
  require("config.ops").open_plan()
end, vim.tbl_extend("force", opts, { desc = "OPS open plan" }))
map("n", "<leader>ph", function()
  require("config.ops").open_handoff()
end, vim.tbl_extend("force", opts, { desc = "OPS handoff" }))
map("n", "<leader>pR", function()
  require("config.ops").open_review()
end, vim.tbl_extend("force", opts, { desc = "OPS review" }))

map("n", "<leader>as", function()
  require("config.ops").show_status()
end, vim.tbl_extend("force", opts, { desc = "OPS status" }))
map("n", "<leader>au", function()
  require("config.ops").resume()
end, vim.tbl_extend("force", opts, { desc = "OPS resume" }))
map("n", "<leader>an", function()
  require("config.ops").show_next()
end, vim.tbl_extend("force", opts, { desc = "OPS next" }))
map("n", "<leader>ad", function()
  require("config.ops").show_doctor()
end, vim.tbl_extend("force", opts, { desc = "OPS doctor" }))
map("n", "<leader>af", function()
  require("config.ops").refresh_review()
end, vim.tbl_extend("force", opts, { desc = "OPS refresh review" }))
map("n", "<leader>am", function()
  require("config.ops").show_mode()
end, vim.tbl_extend("force", opts, { desc = "OPS mode" }))
map("n", "<leader>ap", function()
  require("config.ops").open_plan()
end, vim.tbl_extend("force", opts, { desc = "OPS open plan" }))
map("n", "<leader>ah", function()
  require("config.ops").open_handoff()
end, vim.tbl_extend("force", opts, { desc = "OPS handoff" }))
map("n", "<leader>ar", function()
  require("config.ops").open_review()
end, vim.tbl_extend("force", opts, { desc = "OPS review" }))

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
end, vim.tbl_extend("force", opts, { desc = "Annotate current hunk" }))
map("n", "<leader>rs", function()
  require("config.review").select_current_status()
end, vim.tbl_extend("force", opts, { desc = "Set review status" }))
map("n", "<leader>rA", function()
  require("config.review").accept_current_hunk()
end, vim.tbl_extend("force", opts, { desc = "Accept current hunk" }))
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

map("n", "<leader>mn", "<Plug>(VM-Find-Under)", vim.tbl_extend("force", remap_opts, { desc = "Multi-cursor next" }))
map("n", "<leader>mj", "<Plug>(VM-Add-Cursor-Down)", vim.tbl_extend("force", remap_opts, { desc = "Multi-cursor down" }))
map("n", "<leader>mk", "<Plug>(VM-Add-Cursor-Up)", vim.tbl_extend("force", remap_opts, { desc = "Multi-cursor up" }))

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

-- Invalidate terminal title cache on buffer delete (debounced)
local invalidate_timer = nil
local invalidate_debounce_ms = 750 -- Increased debounce for less frequent recalculation

vim.api.nvim_create_autocmd({ "BufDelete", "BufAdd" }, {
  callback = function()
    -- Debounce cache invalidation to avoid frequent recalculation
    if invalidate_timer then
      vim.fn.timer_stop(invalidate_timer)
    end
    invalidate_timer = vim.fn.timer_start(invalidate_debounce_ms, function()
      terminal_title_cache = nil
      terminal_scan_cache = {}
      terminal_scan_version = 0
      invalidate_timer = nil
    end)
  end,
})
