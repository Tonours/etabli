local agent_threads = require("config.ops.agent_threads")
local projects = require("config.projects")

local M = {}

local state = {
  bufnr = nil,
  winid = nil,
  actions = {},
  expanded = {},
}

local function set_lines(bufnr, lines)
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].readonly = true
end

local function ensure_buffer()
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    return state.bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "ops-agent-sidebar"
  vim.api.nvim_buf_set_name(bufnr, "ops-agent-sidebar")

  vim.keymap.set("n", "<CR>", function() M.activate_current() end, { buffer = bufnr, silent = true, desc = "Activate/Toggle" })
  vim.keymap.set("n", "<Tab>", function() M.activate_current() end, { buffer = bufnr, silent = true, desc = "Toggle fold" })
  vim.keymap.set("n", "C", function() M.create_thread("claude") end, { buffer = bufnr, silent = true, desc = "New Claude" })
  vim.keymap.set("n", "P", function() M.create_thread("pi") end, { buffer = bufnr, silent = true, desc = "New Pi" })
  vim.keymap.set("n", "d", function() M.delete_current() end, { buffer = bufnr, silent = true, desc = "Delete thread" })
  vim.keymap.set("n", "R", function() M.refresh() end, { buffer = bufnr, silent = true, desc = "Refresh sidebar" })
  vim.keymap.set("n", "?", function()
    vim.notify("Sidebar: <CR> activate · C/P new thread · d delete · R refresh", vim.log.levels.INFO)
  end, { buffer = bufnr, silent = true, desc = "Sidebar help" })

  state.bufnr = bufnr
  return bufnr
end

local function current_action()
  return state.actions[vim.api.nvim_win_get_cursor(0)[1]]
end

local function render(root)
  local lines = {
    " █ AGENT WORKSPACES",
    "   [<CR>] Expand/Open · [C] New Claude · [P] New Pi",
    "   [d] Delete thread  · [R] Refresh",
    "",
  }
  local actions = {}
  local current_root = projects.current_root()
  if state.expanded[current_root] == nil then
    state.expanded[current_root] = true
  end

  local entries = projects.list_projects()
  if #entries == 0 then
    table.insert(lines, "No tracked projects")
    return lines, actions
  end

  for _, entry in ipairs(entries) do
    local project_root = entry.value
    local tail = vim.fn.fnamemodify(project_root, ":t")
    local is_current = project_root == current_root
    local is_expanded = state.expanded[project_root]

    local threads = agent_threads.list_project_threads(project_root)
    local expand_icon = is_expanded and "▼" or "▶"
    local marker = is_current and "★" or " "

    table.insert(lines, string.format(" %s %s %s (%d thread%s)", marker, expand_icon, tail, #threads, #threads == 1 and "" or "s"))
    actions[#lines] = { kind = "project", root = project_root }

    if is_expanded then
      if #threads == 0 then
        table.insert(lines, "      └─ No threads yet (press C or P)")
      else
        local active = agent_threads.active_thread(project_root)
        for i, thread in ipairs(threads) do
          local is_active = active and active.id == thread.id
          local prefix = is_active and "●" or "○"
          local tree_char = (i == #threads) and "└─" or "├─"
          
          table.insert(lines, string.format("      %s %s %s [%s] %s", tree_char, prefix, thread.title, thread.provider, thread.status))
          actions[#lines] = { kind = "thread", root = project_root, thread = thread }
        end
      end
    end
    table.insert(lines, "")
  end

  return lines, actions
end

function M.mount(winid)
  local bufnr = ensure_buffer()
  state.winid = winid
  vim.api.nvim_win_set_buf(winid, bufnr)
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].wrap = false
  vim.wo[winid].cursorline = true
  vim.wo[winid].winfixwidth = true
  return bufnr
end

function M.refresh(root)
  local bufnr = ensure_buffer()
  local lines, actions = render(root or vim.fn.getcwd())
  state.actions = actions
  set_lines(bufnr, lines)
end

function M.activate_current()
  local action = current_action()
  if not action then
    return
  end

  if action.kind == "project" then
    state.expanded[action.root] = not state.expanded[action.root]
    M.refresh(vim.fn.getcwd())
    return
  end

  agent_threads.set_active_thread(action.thread.id, action.root)
  M.refresh(action.root)
  vim.notify(string.format("Active thread: %s", action.thread.title), vim.log.levels.INFO)
  
  -- Open thread in dedicated overlay to preserve code tabs/windows
  agent_threads.focus_thread(action.thread.id)
end

function M.delete_current()
  local action = current_action()
  if not action or action.kind ~= "thread" then
    vim.notify("Please select a thread to delete", vim.log.levels.WARN)
    return
  end
  
  local title = action.thread.title or "Untitled"
  vim.ui.input({ prompt = string.format("Delete thread '%s'? (y/n) ", title) }, function(input)
    if input and input:lower() == "y" then
      agent_threads.remove_thread(action.thread.id, action.root)
      M.refresh(vim.fn.getcwd())
      vim.notify("Thread deleted", vim.log.levels.INFO)
    end
  end)
end

function M.create_thread(provider)
  local action = current_action()
  local root = (action and action.root) or projects.current_root()
  local ok, thread = pcall(agent_threads.create_thread, provider, {
    root = root,
    cwd = root,
  })
  if not ok then
    vim.notify(thread, vim.log.levels.ERROR)
    return
  end

  M.refresh(root)
  vim.notify(string.format("Started %s thread: %s", provider, thread.title), vim.log.levels.INFO)
end

function M.focus()
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_set_current_win(state.winid)
    return true
  end

  return false
end

function M.buffer()
  return state.bufnr
end

function M.window()
  return state.winid
end

return M
