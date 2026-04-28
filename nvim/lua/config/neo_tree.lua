local M = {}

local autocmds_registered = false
local sidebar_width = 34

local function is_neo_tree_window(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  return vim.bo[bufnr].filetype == "neo-tree"
end

local function neo_tree_window()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_neo_tree_window(winid) then
      return winid
    end
  end

  return nil
end

local function normal_window_count()
  local count = 0

  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_neo_tree_window(winid) then
      count = count + 1
    end
  end

  return count
end

local function clamp_sidebar_width()
  return math.max(24, math.min(sidebar_width, vim.o.columns - 20))
end

local function fix_sidebar_width()
  local winid = neo_tree_window()
  if not winid then
    return
  end

  vim.wo[winid].winfixwidth = true
  pcall(vim.api.nvim_win_set_width, winid, clamp_sidebar_width())
end

local function ensure_editor_window()
  if #vim.api.nvim_list_uis() == 0 or vim.v.exiting ~= vim.NIL then
    return
  end

  local tree_win = neo_tree_window()
  if not tree_win or normal_window_count() > 0 then
    fix_sidebar_width()
    return
  end

  vim.api.nvim_set_current_win(tree_win)
  vim.cmd("topleft vertical new")
  vim.bo.buflisted = false
  vim.wo.winfixwidth = false
  fix_sidebar_width()
end

local function ensure_loaded()
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    lazy.load({ plugins = { "neo-tree.nvim" } })
  end

  local ok_command, command = pcall(require, "neo-tree.command")
  if not ok_command then
    vim.notify("neo-tree not available", vim.log.levels.ERROR)
    return nil
  end

  return command
end

local function execute(opts)
  local command = ensure_loaded()
  if not command then
    return false
  end

  command.execute(vim.tbl_extend("force", {
    position = "right",
    source = "filesystem",
  }, opts or {}))

  return true
end

local function should_auto_open(bufnr)
  if #vim.api.nvim_list_uis() == 0 then
    return false
  end

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.o.diff then
    return false
  end

  local buftype = vim.bo[bufnr].buftype
  if buftype ~= "" then
    return false
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == "gitcommit" or filetype == "gitrebase" or filetype == "help" or filetype == "qf" then
    return false
  end

  return true
end

local function keep_focus(callback)
  local current_win = vim.api.nvim_get_current_win()
  callback()

  if vim.api.nvim_win_is_valid(current_win) then
    vim.api.nvim_set_current_win(current_win)
  end
end

function M.ensure_visible()
  if not should_auto_open(vim.api.nvim_get_current_buf()) then
    return false
  end

  keep_focus(function()
    execute({})
    fix_sidebar_width()
  end)

  return true
end

function M.focus()
  execute({})
  fix_sidebar_width()
end

function M.reveal_current_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    M.focus()
    return
  end

  execute({
    reveal = true,
    reveal_force_cwd = true,
  })
end

function M.setup_autocmds()
  if autocmds_registered then
    return
  end

  autocmds_registered = true

  local group = vim.api.nvim_create_augroup("etabli_neo_tree", { clear = true })
  local function open_sidebar()
    vim.schedule(function()
      M.ensure_visible()
    end)
  end

  local function preserve_sidebar_layout()
    vim.schedule(function()
      ensure_editor_window()
    end)
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = open_sidebar,
  })

  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = open_sidebar,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "neo-tree",
    callback = fix_sidebar_width,
  })

  vim.api.nvim_create_autocmd({ "WinClosed", "BufWinLeave", "TabEnter" }, {
    group = group,
    callback = preserve_sidebar_layout,
  })
end

return M
