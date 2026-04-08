local agent_state = require("config.ops.agent_state")

local M = {}
local runtime = {}

local thread_border = { "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" }

M.providers = {
  claude = { command = "claude", label = "Claude" },
  pi = { command = "pi", label = "Pi" },
}

local function normalized_root(root)
  return agent_state.project_key(root)
end

local function find_thread_root(thread_id)
  for root, project in pairs(agent_state.read_store()) do
    for _, thread in ipairs(project.threads or {}) do
      if thread.id == thread_id then
        return root
      end
    end
  end

  return nil
end

local function pid_alive(pid)
  if type(pid) ~= "number" or pid <= 0 then
    return false
  end

  vim.fn.system({ "kill", "-0", tostring(pid) })
  return vim.v.shell_error == 0
end

local function terminate_pid(pid)
  if not pid_alive(pid) then
    return
  end

  pcall(vim.fn.system, { "kill", "-TERM", tostring(pid) })
  vim.wait(250, function()
    return not pid_alive(pid)
  end, 25)

  if pid_alive(pid) then
    pcall(vim.fn.system, { "kill", "-KILL", tostring(pid) })
  end
end

local function close_buffer_windows(bufnr)
  if not bufnr or bufnr == -1 then
    return
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

local function wipe_buffer(bufnr)
  if not bufnr or bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  close_buffer_windows(bufnr)
  pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end

local function overlay_geometry()
  local available_width = math.max(20, vim.o.columns - 4)
  local preferred_width = math.max(60, math.floor(vim.o.columns * 0.78))
  local width = math.min(preferred_width, available_width)

  local available_height = math.max(6, vim.o.lines - 4)
  local preferred_height = math.max(10, math.floor(vim.o.lines * 0.42))
  local height = math.min(preferred_height, available_height)

  return {
    width = width,
    height = height,
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    row = math.max(0, vim.o.lines - height - 2),
  }
end

local function open_overlay(bufnr)
  local geometry = overlay_geometry()
  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = geometry.width,
    height = geometry.height,
    col = geometry.col,
    row = geometry.row,
    style = "minimal",
    border = thread_border,
  })

  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].winblend = 0
  return winid
end

local function close_thread_overlay(thread_id, winid)
  local entry = runtime[thread_id]
  local target_win = winid or (entry and entry.winid)

  if target_win and vim.api.nvim_win_is_valid(target_win) then
    pcall(vim.api.nvim_win_close, target_win, true)
  end

  if entry and entry.winid == target_win then
    entry.winid = nil
  end
end

local function attach_overlay_shortcuts(thread_id, bufnr, winid)
  local function close()
    close_thread_overlay(thread_id, winid)
  end

  vim.keymap.set("n", "q", close, {
    buffer = bufnr,
    silent = true,
    nowait = true,
    desc = "Close thread overlay",
  })
  vim.keymap.set("n", "<Esc>", close, {
    buffer = bufnr,
    silent = true,
    nowait = true,
    desc = "Close thread overlay",
  })
  vim.keymap.set("t", "<Esc>", close, {
    buffer = bufnr,
    silent = true,
    nowait = true,
    desc = "Close thread overlay",
  })
end

local function locate_persisted_buffer(root, thread_id)
  local threads = agent_state.list_threads(root)
  for _, thread in ipairs(threads) do
    if thread.id == thread_id and thread.bufferName then
      local bufnr = vim.fn.bufnr(thread.bufferName)
      if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
        return bufnr
      end
    end
  end

  return nil
end

local function open_terminal(command, opts, thread)
  local root = normalized_root(opts.root or thread.cwd or opts.cwd)
  local cwd = opts.cwd or thread.cwd or root
  local has_ui = #vim.api.nvim_list_uis() > 0
  local bufnr
  local winid

  if has_ui then
    bufnr = vim.api.nvim_create_buf(false, false)
    winid = open_overlay(bufnr)
  else
    vim.cmd.enew()
    bufnr = vim.api.nvim_get_current_buf()
    winid = vim.api.nvim_get_current_win()
  end

  vim.bo[bufnr].bufhidden = "hide"
  if opts.title then
    pcall(vim.api.nvim_buf_set_name, bufnr, opts.title)
  end

  local job_id = vim.fn.termopen(command, {
    cwd = cwd,
    on_exit = function()
      local entry = runtime[thread.id]
      runtime[thread.id] = nil

      if entry and entry.winid and vim.api.nvim_win_is_valid(entry.winid) then
        pcall(vim.api.nvim_win_close, entry.winid, true)
      end

      pcall(agent_state.update_thread, root, thread.id, { status = "inactive" })
    end,
  })

  if type(job_id) ~= "number" or job_id <= 0 then
    if winid and vim.api.nvim_win_is_valid(winid) then
      pcall(vim.api.nvim_win_close, winid, true)
    end
    wipe_buffer(bufnr)
    pcall(agent_state.update_thread, root, thread.id, { status = "error" })
    error("Failed to start terminal job")
  end

  runtime[thread.id] = {
    jobId = job_id,
    chanId = job_id,
    bufnr = bufnr,
    winid = winid,
    root = root,
  }

  if has_ui then
    attach_overlay_shortcuts(thread.id, bufnr, winid)
    vim.cmd.startinsert()
  end

  local buffer_name = vim.api.nvim_buf_get_name(bufnr)
  return agent_state.update_thread(root, thread.id, {
    status = "running",
    cwd = cwd,
    bufferName = buffer_name ~= "" and buffer_name or nil,
  })
end

local function create_runtime_thread(command, opts)
  local root = normalized_root(opts.root or opts.cwd)
  local thread = agent_state.create_thread({
    root = root,
    provider = opts.provider or "pi",
    title = opts.title,
    cwd = opts.cwd or root,
    status = "idle",
    notes = opts.notes,
  })

  return open_terminal(command, opts, thread)
end

function M.create_thread(provider, opts)
  opts = opts or {}
  local provider_config = M.providers[provider]
  if not provider_config then
    error("Unknown provider: " .. tostring(provider))
  end
  if vim.fn.executable(provider_config.command) ~= 1 then
    error("Missing executable: " .. provider_config.command)
  end

  opts.provider = provider
  opts.title = opts.title or (provider_config.label .. " thread")
  return create_runtime_thread(provider_config.command, opts)
end

function M.create_for_test(command, opts)
  opts = opts or {}
  return create_runtime_thread(command, opts)
end

function M.is_live(thread_id)
  local entry = runtime[thread_id]
  if not entry then
    return false
  end

  local ok, result = pcall(vim.fn.jobwait, { entry.jobId }, 0)
  return ok and type(result) == "table" and result[1] == -1
end

function M.list_project_threads(root)
  local project_root = normalized_root(root)
  local threads = agent_state.list_threads(project_root)

  for _, thread in ipairs(threads) do
    if M.is_live(thread.id) then
      thread.status = "running"
    elseif thread.status == "running" then
      agent_state.update_thread(project_root, thread.id, { status = "inactive" })
      thread.status = "inactive"
    end
  end

  return threads
end

function M.send_to_thread(thread_id, prompt)
  if not M.is_live(thread_id) then
    local root = find_thread_root(thread_id)
    if root then
      pcall(agent_state.update_thread, root, thread_id, { status = "inactive" })
    end
    error("Thread is not live: " .. tostring(thread_id))
  end

  local entry = runtime[thread_id]
  vim.api.nvim_chan_send(entry.chanId, prompt .. "\n")
  return agent_state.update_thread(entry.root, thread_id, {
    lastPrompt = prompt,
    status = "running",
  })
end

function M.active_thread(root)
  local project_root = normalized_root(root)
  M.list_project_threads(project_root)
  local thread = agent_state.get_active_thread(project_root)
  if not thread then
    return nil
  end

  if M.is_live(thread.id) then
    thread.status = "running"
    return thread
  end

  if thread.status == "running" then
    return agent_state.update_thread(project_root, thread.id, { status = "inactive" })
  end

  return thread
end

function M.set_active_thread(thread_id, root)
  local project_root = root or (runtime[thread_id] and runtime[thread_id].root) or find_thread_root(thread_id)
  if not project_root then
    return false
  end

  return agent_state.set_active_thread(project_root, thread_id)
end

function M.stop_thread(thread_id)
  local entry = runtime[thread_id]
  if not entry then
    local root = find_thread_root(thread_id)
    if root then
      pcall(agent_state.update_thread, root, thread_id, { status = "inactive" })
    end
    return false
  end

  local pid = vim.fn.jobpid(entry.jobId)
  pcall(vim.fn.jobstop, entry.jobId)
  pcall(vim.fn.jobwait, { entry.jobId }, 250)
  terminate_pid(pid)

  if entry.winid and vim.api.nvim_win_is_valid(entry.winid) then
    pcall(vim.api.nvim_win_close, entry.winid, true)
  end

  wipe_buffer(entry.bufnr)
  runtime[thread_id] = nil
  return agent_state.update_thread(entry.root, thread_id, { status = "inactive" }) ~= nil
end

function M.remove_thread(thread_id, root)
  local project_root = root or (runtime[thread_id] and runtime[thread_id].root) or find_thread_root(thread_id)
  if not project_root then
    return false
  end

  local fallback_bufnr = locate_persisted_buffer(project_root, thread_id)
  M.stop_thread(thread_id)
  wipe_buffer(fallback_bufnr)
  runtime[thread_id] = nil
  return agent_state.remove_thread(project_root, thread_id)
end

function M.focus_thread(thread_id, target_win)
  local entry = runtime[thread_id]
  local bnr = nil

  if entry and entry.winid and vim.api.nvim_win_is_valid(entry.winid) then
    vim.api.nvim_set_current_win(entry.winid)
    return true
  end

  if entry and vim.api.nvim_buf_is_valid(entry.bufnr) then
    bnr = entry.bufnr
  else
    local root = find_thread_root(thread_id)
    if root then
      bnr = locate_persisted_buffer(root, thread_id)
    end
  end

  if bnr and bnr ~= -1 and vim.api.nvim_buf_is_valid(bnr) then
    if target_win and vim.api.nvim_win_is_valid(target_win) then
      vim.api.nvim_win_set_buf(target_win, bnr)
      vim.api.nvim_set_current_win(target_win)
      return true
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == bnr then
        vim.api.nvim_set_current_win(win)
        if entry then
          entry.winid = win
        end
        return true
      end
    end

    if #vim.api.nvim_list_uis() > 0 then
      local winid = open_overlay(bnr)
      attach_overlay_shortcuts(thread_id, bnr, winid)
      if entry then
        entry.winid = winid
      end
      return true
    end

    vim.cmd("botright split")
    vim.api.nvim_set_current_buf(bnr)
    if entry then
      entry.winid = vim.api.nvim_get_current_win()
    end
    return true
  end

  vim.notify("Thread buffer is no longer available (it may have been closed).", vim.log.levels.WARN)
  return false
end

M.list_threads = M.list_project_threads

return M
