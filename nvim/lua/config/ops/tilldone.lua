local M = {}

local function get_sanitized_cwd()
  local cwd = vim.fn.getcwd()
  return cwd:gsub("[^a-zA-Z0-9._-]+", "_")
end

local function read_json_file(path)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  local ok, content = pcall(vim.fn.readfile, path)
  if not ok or not content then
    return nil
  end

  local decoded_ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
  if not decoded_ok or not data then
    return nil
  end

  return data
end

local function get_tilldone_ops_path()
  local home = vim.fn.expand("~")
  return string.format("%s/.pi/status/%s.tilldone-ops.json", home, get_sanitized_cwd())
end

local function get_ops_task_path()
  local home = vim.fn.expand("~")
  return string.format("%s/.pi/status/%s.task.json", home, get_sanitized_cwd())
end

function M.read_tilldone_state()
  return read_json_file(get_tilldone_ops_path())
end

function M.read_ops_task()
  return read_json_file(get_ops_task_path())
end

function M.get_statusline()
  local tilldone = M.read_tilldone_state()
  local task = M.read_ops_task()

  if tilldone and tilldone.tasks and #tilldone.tasks > 0 then
    local remaining = 0
    for _, entry in ipairs(tilldone.tasks) do
      if entry.status ~= "done" then
        remaining = remaining + 1
      end
    end

    local active_task = nil
    for _, entry in ipairs(tilldone.tasks) do
      if entry.id == tilldone.activeTaskId then
        active_task = entry
        break
      end
    end

    if active_task then
      local text = active_task.text
      if #text > 30 then
        text = text:sub(1, 27) .. "..."
      end
      return string.format("TD: %s (#%d, %d/%d)", text, active_task.id, remaining, #tilldone.tasks)
    end

    return string.format("TD: %d/%d tasks", remaining, #tilldone.tasks)
  end

  if task and task.tilldone and task.tilldone.taskCount > 0 then
    local tilldone_task = task.tilldone
    if tilldone_task.activeTaskText then
      local text = tilldone_task.activeTaskText
      if #text > 30 then
        text = text:sub(1, 27) .. "..."
      end
      return string.format("TD: %s (#%d, %d/%d)", text, tilldone_task.activeTaskId, tilldone_task.remainingCount, tilldone_task.taskCount)
    end

    return string.format("TD: %d/%d tasks", tilldone_task.remainingCount, tilldone_task.taskCount)
  end

  return nil
end

function M.show_float()
  local tilldone = M.read_tilldone_state()
  if not tilldone or not tilldone.tasks or #tilldone.tasks == 0 then
    vim.notify("No TillDone tasks found for this project", vim.log.levels.INFO)
    return
  end

  local lines = {}
  local highlights = {}
  table.insert(lines, tilldone.listTitle or "TillDone Tasks")
  table.insert(highlights, { "Title", #lines, 0, -1 })

  if tilldone.listDescription then
    table.insert(lines, tilldone.listDescription)
    table.insert(highlights, { "Comment", #lines, 0, -1 })
  end

  table.insert(lines, "")

  local done, inprogress, idle = 0, 0, 0
  for _, task in ipairs(tilldone.tasks) do
    if task.status == "done" then
      done = done + 1
    elseif task.status == "inprogress" then
      inprogress = inprogress + 1
    else
      idle = idle + 1
    end
  end

  table.insert(lines, string.format("Done: %d | Active: %d | Idle: %d", done, inprogress, idle))
  table.insert(highlights, { "Comment", #lines, 0, -1 })
  table.insert(lines, "")

  local icons = { done = "✓", inprogress = "●", idle = "○" }
  local groups = { done = "DiagnosticOk", inprogress = "DiagnosticInfo", idle = "Comment" }

  for _, task in ipairs(tilldone.tasks) do
    table.insert(lines, string.format("%s #%d: %s", icons[task.status] or "○", task.id, task.text))
    local group = groups[task.status] or "Normal"
    if task.id == tilldone.activeTaskId then
      group = "DiagnosticInfo"
    end
    table.insert(highlights, { group, #lines, 0, -1 })
  end

  table.insert(lines, "")
  table.insert(lines, "Press q to close")
  table.insert(highlights, { "Comment", #lines, 0, -1 })

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, highlight in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, -1, highlight[1], highlight[2] - 1, highlight[3], highlight[4])
  end

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.min(width + 4, 60),
    height = math.min(#lines + 2, 20),
    col = math.floor((vim.o.columns - math.min(width + 4, 60)) / 2),
    row = math.floor((vim.o.lines - math.min(#lines + 2, 20)) / 2),
    style = "minimal",
    border = "rounded",
    title = " TillDone ",
    title_pos = "center",
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<cr>", { noremap = true, silent = true })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  return win
end

function M.get_next_action()
  local task = M.read_ops_task()
  local tilldone = M.read_tilldone_state()
  local actions = {}

  if task and task.nextAction and task.nextAction ~= "" then
    table.insert(actions, { source = "OPS", text = task.nextAction })
  end

  if task and task.tilldone and task.tilldone.activeTaskText then
    table.insert(actions, {
      source = "TillDone",
      text = string.format("%s (#%d)", task.tilldone.activeTaskText, task.tilldone.activeTaskId),
    })
  end

  if tilldone and tilldone.activeTaskId then
    for _, entry in ipairs(tilldone.tasks or {}) do
      if entry.id == tilldone.activeTaskId then
        local duplicate = false
        for _, action in ipairs(actions) do
          if action.text:find(entry.text, 1, true) then
            duplicate = true
            break
          end
        end

        if not duplicate then
          table.insert(actions, {
            source = "TillDone",
            text = string.format("%s (#%d)", entry.text, entry.id),
          })
        end
        break
      end
    end
  end

  return actions
end

function M.show_next_action()
  local actions = M.get_next_action()
  if #actions == 0 then
    vim.notify("No next action defined. Check PLAN.md or TillDone tasks.", vim.log.levels.INFO)
    return
  end

  local lines = {}
  for _, action in ipairs(actions) do
    table.insert(lines, string.format("[%s] %s", action.source, action.text))
  end
  vim.notify("Next actions:\n" .. table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.setup()
  vim.api.nvim_create_user_command("TillDoneShow", M.show_float, {
    desc = "Show TillDone tasks in a floating window",
  })

  vim.api.nvim_create_user_command("TillDoneNext", M.show_next_action, {
    desc = "Show next action from TillDone and OPS",
  })
end

return M
