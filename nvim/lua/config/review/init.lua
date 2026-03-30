local diff = require("config.review.diff")
local picker = require("config.review.picker")
local providers = require("config.review.providers")
local state = require("config.review.state")
local util = require("config.review.util")

local M = {}

local commands_registered = false
local provider_actions = { "explain", "revise" }
local repo_items_cache = {}
local repo_items_cache_ttl = 1000

local function clear_repo_items_cache()
  repo_items_cache = {}
end

local function repo_items_cache_key(context, opts)
  local options = opts or {}
  return table.concat({
    context.repo,
    context.branch,
    options.path or "",
  }, "\0")
end

local function cached_repo_items(context, opts)
  local key = repo_items_cache_key(context, opts)
  local cached = repo_items_cache[key]
  if cached and (vim.loop.now() - cached.at) < repo_items_cache_ttl then
    return cached.items
  end

  local items, err = diff.collect_all(context.repo, { path = opts.path })
  if not items then
    return nil, err
  end

  local merged = state.merge_items(context, items)
  repo_items_cache[key] = {
    at = vim.loop.now(),
    items = merged,
  }

  return merged
end

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
  -- Pre-calculate lines for better performance with exact allocation
  local patch_lines = vim.split(item.patch, "\n", { plain = true })
  local has_note = item.note and item.note ~= ""
  -- Pre-allocate with exact size: 11 base + patch_lines + (1 if note)
  local lines = vim.list_extend({
    "# Review Hunk",
    "",
    string.format("- Repo: %s", item.repo),
    string.format("- Branch: %s", item.branch or "unknown"),
    string.format("- File: %s", item.path),
    string.format("- Scope: %s", item.scope),
    string.format("- Status: %s", item.status or "new"),
    string.format("- Stale: %s", item.stale and "yes" or "no"),
  }, has_note and {
    string.format("- Note: %s", item.note),
    "",
    "```diff",
  } or {
    "",
    "```diff",
  })

  vim.list_extend(lines, patch_lines)
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

local function git_show_lines(repo, spec)
  local result = vim.system({ "git", "-C", repo, "show", spec }, { text = true }):wait()
  if result.code ~= 0 then
    return {}
  end

  local stdout = result.stdout or ""
  if stdout == "" then
    return {}
  end

  return vim.split(stdout, "\n", { plain = true })
end

local function buffer_filetype(path)
  return vim.filetype.match({ filename = path }) or ""
end

local function set_scratch_buffer(buf, name, lines, filetype)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.bo[buf].filetype = filetype or ""
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].readonly = true
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
  local target_status = options.status
  local include_stale = options.include_stale ~= false
  local include_resolved_stale = options.include_resolved_stale
  local target_status_nil = target_status == nil

  for _, item in ipairs(items) do
    local status = item.status or "new"
    local is_stale = item.stale

    -- Status match check
    local matches_status = target_status_nil or status == target_status
    if not matches_status then
      goto continue
    end

    -- Stale checks combined for efficiency
    if is_stale then
      local surfaced = vim.tbl_contains({ "needs-rework", "question" }, status)
      if not include_stale then
        if not surfaced then
          goto continue
        end
      elseif not include_resolved_stale and target_status_nil and not surfaced then
        goto continue
      end
    end

    table.insert(filtered, item)
    ::continue::
  end

  return filtered
end

local function repo_items(context, opts)
  local options = opts or {}
  local items, err = cached_repo_items(context, options)
  if not items then
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end

  return filter_items(items, options)
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

local function open_item_diff(item)
  if item.stale then
    vim.notify("This review item is stale, so the live diff no longer exists. Showing the stored patch instead.", vim.log.levels.INFO)
    util.open_scratch("review-stale.md", render_item(item), "markdown")
    return
  end

  local absolute_path = item.repo .. "/" .. item.path
  local left_label = item.scope == "staged" and "HEAD" or "INDEX"
  local left_spec = item.scope == "staged" and ("HEAD:" .. item.path) or (":" .. item.path)
  local left_lines = git_show_lines(item.repo, left_spec)
  local filetype = buffer_filetype(item.path)

  vim.cmd.tabnew()

  local left_buf = vim.api.nvim_get_current_buf()
  set_scratch_buffer(left_buf, string.format("review-%s-%s", util.sanitize_segment(left_label:lower()), item.path), left_lines, filetype)

  vim.cmd.vsplit()

  local right_buf = vim.api.nvim_get_current_buf()
  if vim.fn.filereadable(absolute_path) == 1 then
    vim.cmd.edit(vim.fn.fnameescape(absolute_path))
  else
    set_scratch_buffer(
      right_buf,
      string.format("review-working-%s", item.path),
      {},
      filetype
    )
  end

  vim.wo.wrap = false
  vim.cmd.diffthis()

  vim.cmd.wincmd("h")
  vim.wo.wrap = false
  vim.cmd.diffthis()

  vim.cmd.wincmd("l")
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

  clear_repo_items_cache()

  vim.notify(string.format("Review status set to %s", status), vim.log.levels.INFO)
end

local function set_items_status(items, status)
  local updated = 0

  for _, item in ipairs(items) do
    local saved, err = state.set_status({ repo = item.repo, branch = item.branch }, item, status)
    if not saved then
      vim.notify(err, vim.log.levels.ERROR)
      return false
    end

    updated = updated + 1
  end

  clear_repo_items_cache()

  vim.notify(string.format("Review status set to %s for %d hunk(s)", status, updated), vim.log.levels.INFO)
  return true
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
    clear_repo_items_cache()

    if options.on_done then
      options.on_done()
    end
  end)
end

local function send_item(item, provider, action)
  local _, err = providers.dispatch(provider, item, {
    action = action,
    cwd = item.repo,
    open_terminal = true,
  })

  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

local function show_inbox_help(opts)
  local lines = {
    "# Review Inbox Help",
    "",
    "- <Tab> or <S-Tab> mark entries for a batch provider action",
    "- <CR> open a diff view for the selected hunk",
    "- <C-a> add or edit the selected hunk note",
    "- <C-s> set the selected hunk status",
    "- <C-y> accept the selected hunk or the marked set",
    "- <C-c> launch Claude directly with the selected diff prompt",
    "- <C-p> launch Pi directly with the selected diff prompt",
    "- <C-r> refresh the inbox after external changes",
    "- :ReviewInbox [status] filter the inbox by status",
    "- :ReviewAccept sets the current hunk status to accepted",
    "- :ReviewClaudeBatch [status] prepare one prompt for all live hunks with that status",
    "- :ReviewPiBatch [status] prepare one prompt for all live hunks with that status",
    "- <leader>rA accepts the current hunk quickly",
    "- <leader>rbc and <leader>rbp run the default needs-rework batch commands",
    "- stale new, accepted, and ignored entries are hidden from the default inbox to reduce noise",
    "- if you want to inspect them again, open an explicit filter like :ReviewInbox new",
  }

  local options = opts or {}
  if options.overlay then
    util.open_overlay("Review Inbox Help", lines, {
      filetype = "markdown",
      on_close = options.on_close,
      origin_win = options.origin_win,
    })
    return
  end

  util.open_scratch("review-inbox-help.md", lines, "markdown")
end

local function reopen_inbox_later(opts)
  local next_opts = vim.deepcopy(opts or {})

  -- Use schedule for immediate but non-blocking execution
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
    cwd = context.repo,
    open_terminal = true,
    selection_label = string.format("review status: %s", normalized_status),
    slug = normalized_status,
    status = normalized_status,
  })

  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

local function prepare_selected_batch(provider, items)
  if vim.tbl_isempty(items or {}) then
    vim.notify("Select at least one review hunk", vim.log.levels.INFO)
    return
  end

  local _, err = providers.dispatch_batch(provider, items, {
    action = "revise",
    cwd = items[1].repo,
    open_terminal = true,
    selection_label = "Telescope inbox multi-selection",
    slug = "selection",
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

function M.accept_current_hunk()
  M.set_current_status("accepted")
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
    on_select = open_item_diff,
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
    on_accept = function(selected)
      if set_items_status(selected, "accepted") then
        reopen_inbox_later(reopen_opts)
      end
    end,
    on_claude = function(selected)
      if #selected > 1 then
        prepare_selected_batch("claude", selected)
        return
      end

      send_item(selected[1], "claude", "revise")
    end,
    on_pi = function(selected)
      if #selected > 1 then
        prepare_selected_batch("pi", selected)
        return
      end

      send_item(selected[1], "pi", "revise")
    end,
    on_refresh = function()
      M.open_inbox(reopen_opts)
    end,
    on_help = function(help_opts)
      show_inbox_help(vim.tbl_extend("force", help_opts or {}, {
        on_close = function()
          reopen_inbox_later(reopen_opts)
        end,
      }))
    end,
  }, {
    status = status,
  })
end

function M.prepare_batch(provider, status)
  prepare_batch(provider, status)
end

function M.setup()
  if commands_registered then
    return
  end

  commands_registered = true

  local cache_group = vim.api.nvim_create_augroup("etabli_review_cache", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufDelete", "DirChanged", "FocusGained", "ShellCmdPost" }, {
    group = cache_group,
    callback = clear_repo_items_cache,
  })

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

  vim.api.nvim_create_user_command("ReviewAccept", function()
    M.accept_current_hunk()
  end, { desc = "Accept the current review hunk" })

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
