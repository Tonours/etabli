local M = {}

local autocmds_registered = false

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
  end)

  return true
end

function M.focus()
  execute({})
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

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = open_sidebar,
  })

  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = open_sidebar,
  })
end

return M
