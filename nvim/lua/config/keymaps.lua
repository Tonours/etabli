local map = vim.keymap.set
local opts = { silent = true }
local remap_opts = { remap = true, silent = true }

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

map("n", "<leader><space>", "<cmd>Telescope find_files<cr>", vim.tbl_extend("force", opts, { desc = "Find files" }))
map("n", "<leader>/", "<cmd>Telescope live_grep<cr>", vim.tbl_extend("force", opts, { desc = "Live grep" }))
map("n", "<leader>.", "<cmd>Telescope buffers<cr>", vim.tbl_extend("force", opts, { desc = "Buffers" }))
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", vim.tbl_extend("force", opts, { desc = "Find files" }))
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", vim.tbl_extend("force", opts, { desc = "Live grep" }))
map("n", "<leader>fw", "<cmd>Telescope grep_string<cr>", vim.tbl_extend("force", opts, { desc = "Grep current word" }))
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", vim.tbl_extend("force", opts, { desc = "Buffers" }))
map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", vim.tbl_extend("force", opts, { desc = "Recent files" }))
map("n", "<leader>fp", function()
  require("config.projects_picker").pick_project_recent_files()
end, vim.tbl_extend("force", opts, { desc = "Project recent files" }))
map("n", "<leader>fe", "<cmd>NvimTreeFocus<cr>", vim.tbl_extend("force", opts, { desc = "Focus explorer" }))
map("n", "<leader>ft", "<cmd>NvimTreeToggle<cr>", vim.tbl_extend("force", opts, { desc = "Toggle explorer" }))

map("n", "<leader>pp", function()
  require("config.projects_picker").pick_project()
end, vim.tbl_extend("force", opts, { desc = "Projects" }))
map("n", "<leader>pw", function()
  require("config.projects_picker").pick_worktree()
end, vim.tbl_extend("force", opts, { desc = "Worktrees" }))
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
  vim.cmd("ProjectInfo")
end, vim.tbl_extend("force", opts, { desc = "Project info" }))

map("n", "<leader>bn", "<cmd>bnext<cr>", vim.tbl_extend("force", opts, { desc = "Next buffer" }))
map("n", "<leader>bp", "<cmd>bprevious<cr>", vim.tbl_extend("force", opts, { desc = "Previous buffer" }))
map("n", "<leader>bd", function()
  require("mini.bufremove").delete(0, false)
end, vim.tbl_extend("force", opts, { desc = "Delete buffer" }))

map("n", "<leader>ss", "<cmd>Telescope lsp_document_symbols<cr>", vim.tbl_extend("force", opts, { desc = "Document symbols" }))
map("n", "<leader>sS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", vim.tbl_extend("force", opts, { desc = "Workspace symbols" }))

map("n", "<leader>dd", "<cmd>Telescope diagnostics bufnr=0<cr>", vim.tbl_extend("force", opts, { desc = "Buffer diagnostics" }))
map("n", "<leader>dD", "<cmd>Telescope diagnostics<cr>", vim.tbl_extend("force", opts, { desc = "Workspace diagnostics" }))
map("n", "<leader>dl", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Line diagnostics" }))
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, vim.tbl_extend("force", opts, { desc = "Previous diagnostic" }))
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, vim.tbl_extend("force", opts, { desc = "Next diagnostic" }))

map("n", "<leader>cf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, vim.tbl_extend("force", opts, { desc = "Format buffer" }))

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
