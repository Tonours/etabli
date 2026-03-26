local diff = require("config.review.diff")
local picker = require("config.review.picker")
local providers = require("config.review.providers")
local state = require("config.review.state")
local util = require("config.review.util")

local M = {}

local provider_actions = { "explain", "revise" }

local function status_complete()
  return state.statuses()
end

local function action_complete()
  return provider_actions
end

local function inbox_complete()
  local choices = state.statuses()
  table.insert(choices, 1, "all")
  return choices
end

local function render_item(item)
  local lines = {
    "# Review Hunk",
    "",
    string.format("- Repo: %s", item.repo),
    string.format("- Branch: %s", item.branch or "unknown"),
    string.format("- File: %s", item.path),
    string.format("- Scope: %s", item.scope),
    string.format("- Status: %s", item.status or "new"),
    string.format("- Stale: %s", item.stale and "yes" or "no"),
  }

  if item.note and item.note ~= "" then
    table.insert(lines, string.format("- Note: %s", item.note))
  end

  table.insert(lines, "")
  table.insert(lines, "```diff")

  for _, line in ipairs(vim.split(item.patch, "\n", { plain = true })) do
    table.insert(lines, line)
  end

  table.insert(lines, "```")

  return lines
end

local function context_for_current_buffer()
  local context, err = state.context_for_buffer(0)
  if not context then
    vim.notify(err, vim.log.levels.WARN)
    return nil
  end

  return context
end

local function context_for_cwd()
  local context = state.context_for_repo(vim.fn.getcwd())
  if not context then
    return nil
  end

  return context
end

local function best_context()
  if vim.api.nvim_buf_get_name(0) ~= "" then
    local buffer_context = state.context_for_buffer(0)
    if buffer_context then
      return buffer_context
    end
  end

  return context_for_cwd()
end

local function normalize_status(status, opts)
  local options = opts or {}

  if status == nil or status == "" or (options.allow_all and status == "all") then
    return nil
  end

  if not state.is_valid_status(status) then
    vim.notify(string.format("Invalid review status: %s", status), vim.log.levels.ERROR)
    return false
  end

  return status
end

local function filter_items(items, opts)
  local options = opts or {}
  local filtered = {}

  for _, item in ipairs(items) do
    local matches_status = options.status == nil or (item.status or "new") == options.status
    local keep_stale = options.include_stale ~= false or not item.stale

    if matches_status and keep_stale then
      table.insert(filtered, item)
    end
  end

  return filtered
end

local function repo_items(context, opts)
  local options = opts or {}
  local items, err = diff.collect_all(context.repo, { path = options.path })
  if not items then
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end

  return filter_items(state.merge_items(context, items), options)
end

local function current_hunk_item()
  if vim.bo.modified then
    vim.notify("Save the current buffer before reviewing its git hunk", vim.log.levels.WARN)
    return nil, nil
  end

  local context = context_for_current_buffer()
  if not context then
    return nil, nil
  end

  local buffer_name = vim.api.nvim_buf_get_name(0)
  local relative_path = util.relative_path(context.repo, buffer_name)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local items = repo_items(context, { include_stale = false, path = relative_path })
  if not items then
    return nil, nil
  end

  for _, scope in ipairs(diff.scopes()) do
    for _, item in ipairs(items) do
      if not item.stale and item.path == relative_path and item.scope == scope and diff.hunk_contains_line(item, line) then
        return context, item
      end
    end
  end

  vim.notify("No reviewable git hunk found at the cursor", vim.log.levels.INFO)
  return nil, nil
end

local function jump_to_item(item)
  local absolute_path = item.repo .. "/" .. item.path
  if vim.fn.filereadable(absolute_path) ~= 1 then
    vim.notify("File for this review item is no longer available", vim.log.levels.WARN)
    util.open_scratch("review-stale.md", render_item(item), "markdown")
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(absolute_path))

  if item.line_start and item.line_start > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { item.line_start, 0 })
  end
end

local function set_item_status(item, status)
  local _, err = state.set_status({ repo = item.repo, branch = item.branch }, item, status)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  vim.notify(string.format("Review status set to %s", status), vim.log.levels.INFO)
end

local function prompt_for_status(item, opts)
  local options = opts or {}

  vim.ui.select(state.statuses(), {
    prompt = "Review status",
  }, function(choice)
    if not choice then
      if options.on_done then
        options.on_done()
      end
      return
    end

    set_item_status(item, choice)

    if options.on_done then
      options.on_done()
    end
  end)
end

local function prompt_for_note(item, opts)
  local options = opts or {}

  vim.ui.input({
    prompt = "Review note: ",
    default = item.note or "",
  }, function(input)
    if input == nil then
      if options.on_done then
        options.on_done()
      end
      return
    end

    local _, err = state.set_note({ repo = item.repo, branch = item.branch }, item, input)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      if options.on_done then
        options.on_done()
      end
      return
    end

    vim.notify("Review note saved", vim.log.levels.INFO)

    if options.on_done then
      options.on_done()
    end
  end)
end

local function send_item(item, provider, action)
  local _, err = providers.dispatch(provider, item, {
    action = action,
    open_terminal = true,
  })

  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

local function show_inbox_help()
  util.open_scratch("review-inbox-help.md", {
    "# Review Inbox Help",
    "",
    "- <CR> jump to the selected hunk",
    "- <C-a> add or edit the selected hunk note",
    "- <C-s> set the selected hunk status",
    "- <C-c> prepare a Claude revise prompt for the selected hunk",
    "- <C-p> prepare a Pi revise prompt for the selected hunk",
    "- <C-r> refresh the inbox after external changes",
    "- :ReviewInbox [status] filter the inbox by status",
    "- :ReviewClaudeBatch [status] prepare one prompt for all live hunks with that status",
    "- :ReviewPiBatch [status] prepare one prompt for all live hunks with that status",
  }, "markdown")
end

local function reopen_inbox_later(opts)
  local next_opts = vim.deepcopy(opts or {})

  vim.schedule(function()
    M.open_inbox(next_opts)
  end)
end

local function prepare_batch(provider, status)
  local normalized_status = normalize_status(status or "needs-rework")
  if normalized_status == false then
    return
  end

  local context = best_context()
  if not context then
    vim.notify("Open this batch command from inside a git repository", vim.log.levels.WARN)
    return
  end

  local items = repo_items(context, {
    include_stale = false,
    status = normalized_status,
  })

  if not items or vim.tbl_isempty(items) then
    vim.notify(string.format("No live review hunks with status %s", normalized_status), vim.log.levels.INFO)
    return
  end

  local _, err = providers.dispatch_batch(provider, items, {
    action = "revise",
    open_terminal = true,
    status = normalized_status,
  })

  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

function M.show_current_hunk()
  local _, item = current_hunk_item()
  if not item then
    return
  end

  util.open_scratch("review-current-hunk.md", render_item(item), "markdown")
end

function M.annotate_current_hunk()
  local _, item = current_hunk_item()
  if not item then
    return
  end

  prompt_for_note(item)
end

function M.select_current_status()
  local _, item = current_hunk_item()
  if not item then
    return
  end

  prompt_for_status(item)
end

function M.set_current_status(status)
  local _, item = current_hunk_item()
  if not item then
    return
  end

  set_item_status(item, status)
end

function M.send_current(provider, action)
  local _, item = current_hunk_item()
  if not item then
    return
  end

  send_item(item, provider, action)
end

function M.open_inbox(opts)
  local open_opts = type(opts) == "string" and { status = opts } or (opts or {})
  local status = normalize_status(open_opts.status, { allow_all = true })
  if status == false then
    return
  end

  local context = best_context()

  if not context then
    vim.notify("Open the inbox from inside a git repository", vim.log.levels.WARN)
    return
  end

  local items = repo_items(context, {
    include_stale = open_opts.include_stale ~= false,
    status = status,
  })
  if not items or vim.tbl_isempty(items) then
    local label = status and string.format(" with status %s", status) or ""
    vim.notify("No reviewable staged or unstaged hunks found" .. label, vim.log.levels.INFO)
    return
  end

  local reopen_opts = {
    include_stale = open_opts.include_stale,
    status = status,
  }

  picker.open(items, {
    on_select = jump_to_item,
    on_annotate = function(item)
      prompt_for_note(item, { on_done = function()
        reopen_inbox_later(reopen_opts)
      end })
    end,
    on_status = function(item)
      prompt_for_status(item, { on_done = function()
        reopen_inbox_later(reopen_opts)
      end })
    end,
    on_claude = function(item)
      send_item(item, "claude", "revise")
    end,
    on_pi = function(item)
      send_item(item, "pi", "revise")
    end,
    on_refresh = function()
      M.open_inbox(reopen_opts)
    end,
    on_help = show_inbox_help,
  }, {
    status = status,
  })
end

function M.prepare_batch(provider, status)
  prepare_batch(provider, status)
end

function M.setup()
  vim.api.nvim_create_user_command("ReviewInbox", function(command_opts)
    M.open_inbox({ status = command_opts.args })
  end, {
    complete = inbox_complete,
    desc = "Open the review inbox",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("ReviewCurrentHunk", function()
    M.show_current_hunk()
  end, { desc = "Preview the current review hunk" })

  vim.api.nvim_create_user_command("ReviewAnnotate", function()
    M.annotate_current_hunk()
  end, { desc = "Annotate the current review hunk" })

  vim.api.nvim_create_user_command("ReviewStatus", function(command_opts)
    if command_opts.args == "" then
      M.select_current_status()
      return
    end

    M.set_current_status(command_opts.args)
  end, {
    complete = status_complete,
    desc = "Set the review status for the current hunk",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("ReviewClaude", function(command_opts)
    M.send_current("claude", command_opts.args ~= "" and command_opts.args or "revise")
  end, {
    complete = action_complete,
    desc = "Send the current hunk review prompt to Claude",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("ReviewPi", function(command_opts)
    M.send_current("pi", command_opts.args ~= "" and command_opts.args or "revise")
  end, {
    complete = action_complete,
    desc = "Send the current hunk review prompt to Pi",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("ReviewClaudeBatch", function(command_opts)
    M.prepare_batch("claude", command_opts.args ~= "" and command_opts.args or "needs-rework")
  end, {
    complete = status_complete,
    desc = "Prepare one Claude prompt for all hunks with a review status",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("ReviewPiBatch", function(command_opts)
    M.prepare_batch("pi", command_opts.args ~= "" and command_opts.args or "needs-rework")
  end, {
    complete = status_complete,
    desc = "Prepare one Pi prompt for all hunks with a review status",
    nargs = "?",
  })
end

return M
