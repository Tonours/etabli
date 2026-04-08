local review_diff = require("config.review.diff")
local review_state = require("config.review.state")

local M = {}

local state = {
  bufnr = nil,
  winid = nil,
  items = {},
  line_map = {},
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
  vim.bo[bufnr].filetype = "ops-agent-diffs"
  vim.api.nvim_buf_set_name(bufnr, "ops-agent-diffs")

  vim.keymap.set("n", "<CR>", function() M.open_current() end, { buffer = bufnr, silent = true, desc = "Open diff item" })
  vim.keymap.set("n", "R", function() M.refresh() end, { buffer = bufnr, silent = true, desc = "Refresh diff list" })
  vim.keymap.set("n", "Y", function() M.accept_current() end, { buffer = bufnr, silent = true, desc = "Accept" })
  vim.keymap.set("n", "N", function() M.reject_current() end, { buffer = bufnr, silent = true, desc = "Reject" })
  vim.keymap.set("n", "M", function() M.rework_current() end, { buffer = bufnr, silent = true, desc = "Rework" })
  vim.keymap.set("n", "?", function()
    vim.notify("Inbox: <CR> view · Y accept · N reject · M rework", vim.log.levels.INFO)
  end, { buffer = bufnr, silent = true, desc = "Inbox help" })

  state.bufnr = bufnr
  return bufnr
end

local function line_for_item(item)
  local stale = item.stale and " · stale" or ""
  local status = string.upper(item.status or "new")
  return string.format("[%s] %s:%d · %s%s", status, item.path, item.line_start or 1, item.scope, stale)
end

local function render(root)
  local lines = {
    " █ ASYNC REVIEW INBOX ",
    "   <CR> View Diff · [Y] Accept · [N] Reject · [M] Rework",
    "",
  }
  local line_map = {}
  local repo, repo_err = review_diff.repo_root(root)
  if not repo then
    table.insert(lines, repo_err or "No git repository")
    return lines, line_map, {}
  end

  local context, context_err = review_state.context_for_repo(repo)
  if not context then
    table.insert(lines, context_err or "Review context unavailable")
    return lines, line_map, {}
  end

  local items, collect_err = review_diff.collect_all(repo)
  if not items then
    table.insert(lines, collect_err or "Failed to collect diffs")
    return lines, line_map, {}
  end

  local merged = review_state.merge_items(context, items)
  local actionable = 0
  for _, item in ipairs(merged) do
    if item.status == "needs-rework" or item.status == "question" then
      actionable = actionable + 1
    end
  end

  table.insert(lines, string.format("Repo: %s", repo))
  table.insert(lines, string.format("Items: %d · actionable: %d", #merged, actionable))
  table.insert(lines, "")

  if #merged == 0 then
    table.insert(lines, "No pending diffs")
    return lines, line_map, merged
  end

  for _, item in ipairs(merged) do
    table.insert(lines, line_for_item(item))
    line_map[#lines] = item
  end

  return lines, line_map, merged
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
  vim.wo[winid].winfixheight = true
  return bufnr
end

function M.refresh(root)
  local target_root = root or vim.fn.getcwd()
  local bufnr = ensure_buffer()
  local lines, line_map, items = render(target_root)
  state.line_map = line_map
  state.items = items
  set_lines(bufnr, lines)
  return items
end

local function target_window()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(winid)
    local filetype = vim.bo[buf].filetype
    if filetype ~= "NvimTree" and filetype ~= "ops-agent-diffs" and filetype ~= "ops-agent-sidebar" then
      return winid
    end
  end

  return nil
end

function M.open_current()
  local item = state.line_map[vim.api.nvim_win_get_cursor(0)[1]]
  if not item then
    return
  end

  local absolute_path = item.repo .. "/" .. item.path
  if vim.fn.filereadable(absolute_path) ~= 1 then
    vim.notify("Diff item file is no longer available", vim.log.levels.WARN)
    return
  end

  local winid = target_window()
  if winid then
    vim.api.nvim_set_current_win(winid)
  end

  vim.cmd.edit(vim.fn.fnameescape(absolute_path))
  if item.line_start and item.line_start > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { item.line_start, 0 })
  end
end

local function handle_action(action_type)
  local line_num = vim.api.nvim_win_get_cursor(0)[1]
  local item = state.line_map[line_num]
  if not item then return end
  
  local context, err = review_state.context_for_repo(item.repo)
  if not context then return end
  
  if action_type == "accept" then
    review_state.set_status(context, item, "accepted")
    vim.notify("Accepted: " .. item.path, vim.log.levels.INFO)
  elseif action_type == "reject" then
    review_state.set_status(context, item, "ignore")
    vim.notify("Rejected: " .. item.path, vim.log.levels.WARN)
  elseif action_type == "rework" then
    review_state.set_status(context, item, "needs-rework")
    vim.notify("Needs Rework: " .. item.path, vim.log.levels.INFO)
  end
  
  M.refresh()
  
  local new_items_count = #state.items
  if line_num <= new_items_count and line_num > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { line_num, 0 })
  end
end

function M.accept_current() handle_action("accept") end
function M.reject_current() handle_action("reject") end
function M.rework_current() handle_action("rework") end

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
