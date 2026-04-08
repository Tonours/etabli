local M = {}

M.default_side = "right"
M.width = 30

local width_group = vim.api.nvim_create_augroup("etabli_nvim_tree_width", { clear = true })
local configured_side = M.default_side

local function open_node_in_tab_or_toggle_dir()
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    return
  end

  local node = api.tree.get_node_under_cursor()
  if not node then
    return
  end

  if node.type == "directory" then
    api.node.open.edit(node)
    return
  end

  api.node.open.tab_drop(node)
end

local function tree_on_attach(bufnr)
  local api = require("nvim-tree.api")
  api.config.mappings.default_on_attach(bufnr)

  local function opts(desc)
    return {
      buffer = bufnr,
      desc = "nvim-tree: " .. desc,
      noremap = true,
      nowait = true,
      silent = true,
    }
  end

  vim.keymap.set("n", "<CR>", open_node_in_tab_or_toggle_dir, opts("Open: Tab / Toggle Dir"))
  vim.keymap.set("n", "o", open_node_in_tab_or_toggle_dir, opts("Open: Tab / Toggle Dir"))
  vim.keymap.set("n", "<2-LeftMouse>", open_node_in_tab_or_toggle_dir, opts("Open: Tab / Toggle Dir"))
end

local function ensure_loaded()
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    lazy.load({ plugins = { "nvim-tree.lua" } })
  end

  local ok_tree, tree = pcall(require, "nvim-tree")
  if not ok_tree then
    return nil
  end

  return tree
end

local function set_window_width(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  if vim.api.nvim_win_get_width(win) ~= M.width then
    vim.api.nvim_win_set_width(win, M.width)
  end
end

function M.find_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "NvimTree" then
      return win
    end
  end

  return nil
end

function M.opts(side)
  local view_side = side or configured_side or M.default_side
  return {
    hijack_cursor = false,
    on_attach = tree_on_attach,
    sync_root_with_cwd = true,
    tab = {
      sync = {
        open = true,
      },
    },
    git = {
      enable = false,
    },
    diagnostics = {
      enable = false,
    },
    update_focused_file = {
      enable = true,
      update_root = false,
      debounce_delay = 10,
    },
    view = {
      side = view_side,
      signcolumn = "no",
      width = M.width,
      preserve_window_proportions = true,
    },
    renderer = {
      group_empty = true,
      highlight_opened_files = "name",
      indent_width = 1,
      root_folder_label = false,
      icons = {
        show = {
          git = false,
        },
      },
    },
    actions = {
      open_file = {
        quit_on_open = false,
        resize_window = false,
        window_picker = {
          enable = false,
        },
      },
    },
    filters = {
      dotfiles = false,
    },
  }
end

function M.setup(side)
  local tree = ensure_loaded()
  if not tree then
    return false
  end

  local opts = type(side) == "table" and side or M.opts(side)
  configured_side = opts.view.side or configured_side
  tree.setup(opts)

  vim.api.nvim_create_autocmd("FileType", {
    group = width_group,
    pattern = "NvimTree",
    callback = function(args)
      local win = vim.fn.bufwinid(args.buf)
      if win ~= -1 then
        set_window_width(win)
      end
    end,
  })

  local win = M.find_window()
  if win then
    set_window_width(win)
  end

  return true
end

function M.current_side()
  return configured_side
end

function M.open(side)
  if side then
    M.apply(side)
  elseif not ensure_loaded() then
    return nil
  end

  local existing = M.find_window()
  if existing then
    set_window_width(existing)
    return existing
  end

  vim.cmd("NvimTreeOpen")
  local win = M.find_window()
  set_window_width(win)
  return win
end

function M.focus()
  local win = M.open()
  if win then
    vim.api.nvim_set_current_win(win)
  end
  return win
end

function M.close()
  if M.find_window() then
    vim.cmd("NvimTreeClose")
  end
end

function M.apply(side)
  local target_side = side or M.default_side
  local current_win = vim.api.nvim_get_current_win()
  local was_open = M.find_window() ~= nil

  if was_open then
    M.close()
  end

  if not M.setup(target_side) then
    return false
  end

  if was_open then
    M.open(target_side)
  end

  if vim.api.nvim_win_is_valid(current_win) then
    vim.api.nvim_set_current_win(current_win)
  end

  return true
end

return M
