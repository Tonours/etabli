local agent_diffs = require("config.ops.agent_diffs")
local agent_sidebar = require("config.ops.agent_sidebar")
local nvim_tree = require("config.ops.nvim_tree")

local M = {}

local state = {
  enabled = false,
  tabpage = nil,
  main_win = nil,
  diff_win = nil,
  sidebar_win = nil,
}

local function valid_win(winid)
  return winid and vim.api.nvim_win_is_valid(winid)
end

local function in_active_tab(winid)
  return valid_win(winid) and vim.api.nvim_win_get_tabpage(winid) == state.tabpage
end

local function close_win(winid)
  if in_active_tab(winid) then
    pcall(vim.api.nvim_win_close, winid, true)
  end
end

local function ensure_sidebar_win()
  if in_active_tab(state.sidebar_win) then
    return state.sidebar_win
  end

  vim.cmd("topleft vsplit")
  state.sidebar_win = vim.api.nvim_get_current_win()
  
  -- Sidebar fixe d'une largeur classique
  vim.api.nvim_win_set_width(state.sidebar_win, 45)
  vim.wo[state.sidebar_win].winfixwidth = true

  agent_sidebar.mount(state.sidebar_win)
  return state.sidebar_win
end

local function refresh_panels()
  if in_active_tab(state.diff_win) then
    agent_diffs.mount(state.diff_win)
    agent_diffs.refresh(vim.fn.getcwd())
  end
  agent_sidebar.mount(state.sidebar_win)
  agent_sidebar.refresh(vim.fn.getcwd())
end

local function ensure_layout()
  state.tabpage = vim.api.nvim_get_current_tabpage()
  state.main_win = valid_win(state.main_win) and state.main_win or vim.api.nvim_get_current_win()

  ensure_sidebar_win()
  refresh_panels()
  -- Note: We intentionally DO NOT restore_focus to main_win here. 
  -- In Mission Control mode, the floating dashboard demands the focus.
end

local function setup_refresh_autocmds()
  local group = vim.api.nvim_create_augroup("etabli_ops_agent_layout", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWritePost", "DirChanged" }, {
    group = group,
    callback = function()
      if state.enabled then
        vim.schedule(function()
          pcall(M.refresh)
        end)
      end
    end,
  })
end

function M.open()
  if state.enabled then
    ensure_layout()
    return
  end

  state.enabled = true
  ensure_layout()
  
  local buf = agent_sidebar.buffer()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.keymap.set("n", "<Esc>", function()
      M.close()
    end, { buffer = buf, silent = true, desc = "Close Mission Control" })
    vim.keymap.set("n", "q", function()
      M.close()
    end, { buffer = buf, silent = true, desc = "Close Mission Control" })
  end
end

function M.refresh()
  if not state.enabled then
    return false
  end

  ensure_layout()
  return true
end

function M.close()
  if not state.enabled then
    return
  end

  close_win(state.sidebar_win)
  
  -- Diff window will be handled via <leader>ri eventually, but let's hide it too if closing the mode
  close_win(state.diff_win)
  state.diff_win = nil
  state.sidebar_win = nil
  state.enabled = false
  
  if valid_win(state.main_win) then
    pcall(vim.api.nvim_set_current_win, state.main_win)
  end
end

function M.toggle()
  if state.enabled then
    M.close()
  else
    M.open()
  end
end

function M.focus_diffs()
  if valid_win(state.diff_win) then
    vim.api.nvim_set_current_win(state.diff_win)
    return
  end
  
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.4)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor(vim.o.lines - height - 3)

  local buf = vim.api.nvim_create_buf(false, true)
  state.diff_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = { "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" },
  })
  
  vim.wo[state.diff_win].winblend = 0

  agent_diffs.mount(state.diff_win)
  agent_diffs.refresh(vim.fn.getcwd())
  
  vim.keymap.set("n", "<Esc>", function()
    close_win(state.diff_win)
    state.diff_win = nil
    if valid_win(state.main_win) then
      pcall(vim.api.nvim_set_current_win, state.main_win)
    end
  end, { buffer = buf, silent = true })
  
  vim.keymap.set("n", "q", function()
    close_win(state.diff_win)
    state.diff_win = nil
    if valid_win(state.main_win) then
      pcall(vim.api.nvim_set_current_win, state.main_win)
    end
  end, { buffer = buf, silent = true })
end

function M.focus_sidebar()
  M.open()
end

function M.is_enabled()
  return state.enabled
end

function M.state()
  return {
    enabled = state.enabled,
    tabpage = state.tabpage,
    main_win = state.main_win,
    diff_win = state.diff_win,
    sidebar_win = state.sidebar_win,
  }
end

setup_refresh_autocmds()

return M
