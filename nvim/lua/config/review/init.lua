local diff = require("config.review.diff")
local meta = require("config.review.meta")
local annotations = require("config.review.annotations")
local picker = require("config.review.picker")
local providers = require("config.review.providers")
local state = require("config.review.state")
local util = require("config.review.util")

local M = {}

local setup_done = false
local repo_items_cache = {}
local repo_items_cache_ttl = 1000
local review_focus_clear_ttl = 1500
local last_focus_clear_at = 0

local function clear_repo_items_cache()
  repo_items_cache = {}
end

local function split_nul(text)
  local items = {}

  for value in tostring(text or ""):gmatch("([^%z]+)%z") do
    table.insert(items, value)
  end

  return items
end

local function repo_change_signature(repo)
  local commands = {
    { "status", "--porcelain=v1", "--untracked-files=all" },
    { "diff", "--no-ext-diff", "--no-color", "--binary" },
    { "diff", "--cached", "--no-ext-diff", "--no-color", "--binary" },
  }
  local parts = {}

  for _, args in ipairs(commands) do
    local result = vim.system(vim.list_extend({ "git", "-C", repo }, args), { text = true }):wait()
    if result.code ~= 0 then
      return nil
    end

    local label = table.concat(args, " ")
    local output = result.stdout or ""
    table.insert(parts, string.format("%d:%s%d:%s", #label, label, #output, output))
  end

  local untracked_result = vim.system({
    "git",
    "-C",
    repo,
    "ls-files",
    "--others",
    "--exclude-standard",
    "-z",
  }, { text = true }):wait()
  if untracked_result.code ~= 0 then
    return nil
  end

  local untracked_paths = split_nul(untracked_result.stdout or "")
  table.sort(untracked_paths)
  for _, path in ipairs(untracked_paths) do
    local hash_result = vim.system({
      "git",
      "-C",
      repo,
      "hash-object",
      "--",
      path,
    }, { text = true }):wait()
    if hash_result.code ~= 0 then
      return nil
    end

    local hash = vim.trim(hash_result.stdout or "")
    table.insert(parts, string.format("%d:untracked:%s%d:%s", #path, path, #hash, hash))
  end

  return vim.fn.sha256(table.concat(parts, ""))
end

local function refresh_repo_buffers(repo)
  local normalized_repo = util.normalize(repo)
  local prefix = normalized_repo .. "/"

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local normalized_name = name ~= "" and util.normalize(name) or ""

      if normalized_name == normalized_repo or vim.startswith(normalized_name, prefix) then
        pcall(vim.api.nvim_buf_call, bufnr, function()
          vim.cmd("silent! checktime")
        end)
      end
    end
  end
end

local function clear_repo_items_cache_on_focus()
  local now = vim.uv.now()
  if (now - last_focus_clear_at) < review_focus_clear_ttl then
    return
  end

  last_focus_clear_at = now
  clear_repo_items_cache()
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

local function comment_range_label(comment)
  local line = tonumber(comment.line)
  local end_line = tonumber(comment.end_line) or line

  if line and end_line and end_line ~= line then
    return string.format("lines %d-%d", line, end_line)
  end

  return string.format("line %s", line or "?")
end

local function render_item(item)
  local has_note = item.note and item.note ~= ""
  local comments = item.comments or {}
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

  if has_note then
    table.insert(lines, "- Note:")
    util.append_text_lines(lines, item.note, "  ")
  end

  table.insert(lines, "")
  util.append_fenced_block(lines, "diff", item.patch)

  if #comments > 0 then
    vim.list_extend(lines, { "", "## Review comments" })
    for _, comment in ipairs(comments) do
      table.insert(
        lines,
        string.format(
          "- %s %s [%s]:",
          comment.id or "?",
          comment_range_label(comment),
          comment.resolved and "resolved" or "unresolved"
        )
      )
      util.append_text_lines(lines, comment.body or "", "  ")
    end
  end

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
      local surfaced = meta.is_actionable(status)
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

local function current_hunk_item_at_line(line, opts)
  local options = opts or {}

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

  if not options.silent then
    vim.notify("No reviewable git hunk found at the cursor", vim.log.levels.INFO)
  end
  return nil, nil
end

local function current_hunk_item()
  return current_hunk_item_at_line(vim.api.nvim_win_get_cursor(0)[1])
end

local function selected_line_range()
  local start_line = vim.fn.getpos("'<")[2]
  local end_line = vim.fn.getpos("'>")[2]

  if start_line < 1 or end_line < 1 then
    return nil, nil
  end

  if end_line < start_line then
    start_line, end_line = end_line, start_line
  end

  return start_line, end_line
end

local function item_for_line_range(start_line, end_line)
  local context, start_item = current_hunk_item_at_line(start_line, { silent = true })
  if not start_item then
    vim.notify("Select lines inside one reviewable git hunk", vim.log.levels.INFO)
    return nil, nil
  end

  local _, end_item = current_hunk_item_at_line(end_line, { silent = true })
  if not end_item or end_item.fingerprint ~= start_item.fingerprint then
    vim.notify("Review comments can only cover one git hunk at a time", vim.log.levels.WARN)
    return nil, nil
  end

  return context, start_item
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
  annotations.refresh_repo(item.repo)

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
  if items[1] then
    annotations.refresh_repo(items[1].repo)
  end

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

local function finish_comment(item, line, end_line, body, opts)
  local options = opts or {}

  if body == nil then
    if options.on_done then
      options.on_done()
    end
    return
  end

  local _, err = state.add_comment({ repo = item.repo, branch = item.branch }, item, {
    body = body,
    line = line,
    end_line = end_line,
  })
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    if options.on_done then
      options.on_done()
    end
    return
  end

  vim.notify("Review comment added", vim.log.levels.INFO)
  clear_repo_items_cache()
  annotations.refresh_repo(item.repo)

  if options.on_done then
    options.on_done()
  end
end

local function comment_editor_geometry()
  local available_width = math.max(30, vim.o.columns - 6)
  local width = math.min(math.max(72, math.floor(vim.o.columns * 0.72)), available_width)
  local available_height = math.max(8, vim.o.lines - 6)
  local height = math.min(math.max(10, math.floor(vim.o.lines * 0.38)), available_height)

  return {
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2)),
    width = width,
  }
end

local function open_comment_editor(item, line, end_line, target, opts)
  local options = opts or {}
  local origin_win = vim.api.nvim_get_current_win()
  local geometry = comment_editor_geometry()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = vim.api.nvim_open_win(bufnr, true, {
    border = "rounded",
    col = geometry.col,
    height = geometry.height,
    relative = "editor",
    row = geometry.row,
    style = "minimal",
    title = string.format("Review comment %s", target),
    title_pos = "center",
    width = geometry.width,
    zindex = 95,
  })

  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

  local closed = false

  local function close()
    if winid and vim.api.nvim_win_is_valid(winid) then
      pcall(vim.api.nvim_win_close, winid, true)
    end

    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end

    if origin_win and vim.api.nvim_win_is_valid(origin_win) then
      pcall(vim.api.nvim_set_current_win, origin_win)
    end
  end

  local function submit()
    if closed then
      return
    end

    closed = true
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    close()
    finish_comment(item, line, end_line, table.concat(lines, "\n"), options)
  end

  local function cancel()
    if closed then
      return
    end

    closed = true
    close()
    if options.on_done then
      options.on_done()
    end
  end

  for _, mode in ipairs({ "n", "i" }) do
    vim.keymap.set(mode, "<C-s>", submit, {
      buffer = bufnr,
      desc = "Save review comment",
      nowait = true,
      silent = true,
    })
  end

  vim.keymap.set("n", "ZZ", submit, { buffer = bufnr, desc = "Save review comment", nowait = true, silent = true })
  vim.keymap.set("n", "ZQ", cancel, { buffer = bufnr, desc = "Cancel review comment", nowait = true, silent = true })
  vim.keymap.set("n", "q", cancel, { buffer = bufnr, desc = "Cancel review comment", nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = bufnr, desc = "Cancel review comment", nowait = true, silent = true })

  vim.cmd.startinsert()
end

local function prompt_for_comment(item, opts)
  local options = opts or {}
  local line = options.line or item.line_start or 1
  local end_line = options.end_line or line
  if end_line < line then
    line, end_line = end_line, line
  end
  local target = line == end_line and string.format("%s:%d", item.path, line)
    or string.format("%s:%d-%d", item.path, line, end_line)

  if #vim.api.nvim_list_uis() > 0 then
    open_comment_editor(item, line, end_line, target, options)
    return
  end

  vim.ui.input({
    prompt = string.format("Review comment %s: ", target),
  }, function(input)
    finish_comment(item, line, end_line, input, options)
  end)
end

local function unresolved_comments(item, line)
  local comments = {}
  for _, comment in ipairs(item.comments or {}) do
    if comment.resolved ~= true and comment.body and comment.body ~= "" then
      local start_line = tonumber(comment.line)
      local end_line = tonumber(comment.end_line) or start_line
      local contains_line = line ~= nil and start_line and end_line and line >= start_line and line <= end_line
      if line == nil or contains_line then
        table.insert(comments, comment)
      end
    end
  end
  return comments
end

local function resolve_comment(context, item, comment)
  local _, err = state.set_comment_resolved(context, item, comment.id, true)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  vim.notify("Review conversation resolved", vim.log.levels.INFO)
  clear_repo_items_cache()
  annotations.refresh_repo(item.repo)
  return true
end

local function prompt_resolve_comment(context, item, line)
  local candidates = unresolved_comments(item, line)
  if vim.tbl_isempty(candidates) then
    candidates = unresolved_comments(item)
  end

  if vim.tbl_isempty(candidates) then
    vim.notify("No unresolved review comments found for this hunk", vim.log.levels.INFO)
    return
  end

  if #candidates == 1 then
    resolve_comment(context, item, candidates[1])
    return
  end

  vim.ui.select(candidates, {
    prompt = "Resolve review conversation",
    format_item = function(comment)
      local body = (comment.body or ""):gsub("%s+", " ")
      if #body > 80 then
        body = body:sub(1, 77) .. "..."
      end
      return string.format("%s %s: %s", comment.id or "?", comment_range_label(comment), body)
    end,
  }, function(choice)
    if choice then
      resolve_comment(context, item, choice)
    end
  end)
end

local function send_item(item, provider, action, opts)
  local options = opts or {}
  local _, err = providers.dispatch(provider, item, {
    action = action,
    cwd = item.repo,
    open_terminal = true,
    after_exit = options.after_exit,
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
    "- <C-a> add a review comment at the selected hunk start line",
    "- <C-s> set the selected hunk status",
    "- <C-y> accept the selected hunk or the marked set",
    "- <C-c> launch Claude directly with the selected diff prompt",
    "- <C-p> launch Pi directly with the selected diff prompt",
    "- <C-r> refresh the inbox after external changes",
    "- :ReviewInbox [status] filter the inbox by status",
    "- :ReviewInlineAnnotations [on|off|refresh|toggle] controls inline review notes",
    "- :ReviewResolve resolves the current review conversation",
    "- :ReviewAccept sets the current hunk status to accepted",
    "- :ReviewClaudeBatch [status] prepare one prompt for all live hunks with that status",
    "- :ReviewPiBatch [status] prepare one prompt for all live hunks with that status",
    "- :ReviewClaudeReview [status|all] launch a first-pass Claude code review",
    "- :ReviewPiReview [status|all] launch a first-pass Pi code review",
    "- <leader>rA accepts the current hunk quickly",
    "- <leader>rbc and <leader>rbp run the default needs-rework batch commands",
    "- <leader>rvc and <leader>rvp run first-pass review commands",
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

local function reopen_opts_for_item(opts, item)
  local next_opts = vim.deepcopy(opts or {})

  if item and item.fingerprint then
    next_opts.focus_fingerprint = item.fingerprint
  end

  return next_opts
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
    after_exit = function()
      reopen_inbox_later({
        include_stale = false,
        status = normalized_status,
      })
    end,
  })

  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

local function prepare_review(provider, status)
  local normalized_status = normalize_status(status, { allow_all = true })
  if normalized_status == false then
    return
  end

  local context = best_context()
  if not context then
    vim.notify("Open this review command from inside a git repository", vim.log.levels.WARN)
    return
  end

  local items = repo_items(context, {
    include_stale = false,
    status = normalized_status,
  })

  if not items or vim.tbl_isempty(items) then
    local label = normalized_status and string.format(" with status %s", normalized_status) or ""
    vim.notify("No live review hunks found" .. label, vim.log.levels.INFO)
    return
  end

  local selection_label = normalized_status
      and string.format("review status: %s", normalized_status)
    or "all live staged and unstaged hunks"

  local _, err = providers.dispatch_batch(provider, items, {
    action = "review",
    cwd = context.repo,
    open_terminal = true,
    selection_label = selection_label,
    slug = normalized_status or "all",
    status = normalized_status,
    after_exit = function()
      reopen_inbox_later({
        include_stale = false,
        status = normalized_status,
      })
    end,
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

  local status = items[1].status
  local same_status = true

  for index = 2, #items do
    if items[index].status ~= status then
      same_status = false
      break
    end
  end

  local _, err = providers.dispatch_batch(provider, items, {
    action = "revise",
    cwd = items[1].repo,
    open_terminal = true,
    selection_label = "Telescope inbox multi-selection",
    slug = "selection",
    after_exit = function()
      reopen_inbox_later({
        include_stale = false,
        status = same_status and status or nil,
      })
    end,
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

  local line = vim.api.nvim_win_get_cursor(0)[1]
  prompt_for_comment(item, { line = line })
end

function M.annotate_line_range(start_line, end_line)
  if not start_line or not end_line then
    vim.notify("No visual review range found", vim.log.levels.WARN)
    return
  end

  local _, item = item_for_line_range(start_line, end_line)
  if not item then
    return
  end

  prompt_for_comment(item, {
    line = start_line,
    end_line = end_line,
  })
end

function M.annotate_visual_selection()
  local start_line, end_line = selected_line_range()
  M.annotate_line_range(start_line, end_line)
end

function M.resolve_current_comment()
  local context, item = current_hunk_item()
  if not item then
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  prompt_resolve_comment(context, item, line)
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
      prompt_for_comment(item, { line = item.line_start, on_done = function()
        reopen_inbox_later(reopen_opts_for_item(reopen_opts, item))
      end })
    end,
    on_status = function(item)
      prompt_for_status(item, { on_done = function()
        reopen_inbox_later(reopen_opts_for_item(reopen_opts, item))
      end })
    end,
    on_accept = function(selected)
      if set_items_status(selected, "accepted") then
        reopen_inbox_later(reopen_opts_for_item(reopen_opts, #selected == 1 and selected[1] or nil))
      end
    end,
    on_claude = function(selected)
      if #selected > 1 then
        prepare_selected_batch("claude", selected)
        return
      end

      send_item(selected[1], "claude", "revise", {
        after_exit = function()
          reopen_inbox_later(reopen_opts_for_item(reopen_opts, selected[1]))
        end,
      })
    end,
    on_pi = function(selected)
      if #selected > 1 then
        prepare_selected_batch("pi", selected)
        return
      end

      send_item(selected[1], "pi", "revise", {
        after_exit = function()
          reopen_inbox_later(reopen_opts_for_item(reopen_opts, selected[1]))
        end,
      })
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
    focus_fingerprint = open_opts.focus_fingerprint,
    status = status,
  })
end

function M.prepare_batch(provider, status)
  prepare_batch(provider, status)
end

function M.prepare_review(provider, status)
  prepare_review(provider, status)
end

function M.repo_change_signature(repo)
  if not repo or repo == "" then
    return nil
  end

  return repo_change_signature(repo)
end

function M.refresh_after_external_edit(repo, opts)
  if not repo or repo == "" then
    return
  end

  local options = opts or {}

  clear_repo_items_cache()
  diff.clear_cache()
  refresh_repo_buffers(repo)

  local after_signature = repo_change_signature(repo)
  local changed = options.before_signature ~= nil and after_signature ~= nil and options.before_signature ~= after_signature
  local provider = options.provider or "Review"

  if options.before_signature == nil or after_signature == nil then
    vim.notify(
      string.format("%s session closed; local buffers and review state refreshed.", provider),
      vim.log.levels.INFO,
      { title = "Review refresh" }
    )
    return
  end

  vim.notify(
    changed
        and string.format("%s session closed; repo changes detected and local review state refreshed.", provider)
      or string.format("%s session closed; local review state refreshed, no repo change detected.", provider),
    vim.log.levels.INFO,
    { title = "Review refresh" }
  )

  return changed
end

function M.setup()
  if setup_done then
    return
  end

  setup_done = true

  local cache_group = vim.api.nvim_create_augroup("etabli_review_cache", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufDelete", "DirChanged", "ShellCmdPost" }, {
    group = cache_group,
    callback = clear_repo_items_cache,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = cache_group,
    callback = clear_repo_items_cache_on_focus,
  })

  annotations.setup()
end


-- Thin wrappers for lazy-loaded commands (called from init.lua lazy_cmd registrations)
function M.cmd_open_inbox(cmd_opts)
  M.open_inbox({ status = cmd_opts.args })
end

function M.cmd_annotate(cmd_opts)
  if cmd_opts.range and cmd_opts.range > 0 then
    M.annotate_line_range(cmd_opts.line1, cmd_opts.line2)
    return
  end

  M.annotate_current_hunk()
end

function M.cmd_set_status(cmd_opts)
  if cmd_opts.args == "" then
    M.select_current_status()
  else
    M.set_current_status(cmd_opts.args)
  end
end

function M.cmd_resolve_comment()
  M.resolve_current_comment()
end

function M.cmd_send_claude(cmd_opts)
  M.send_current("claude", cmd_opts.args ~= "" and cmd_opts.args or "revise")
end

function M.cmd_send_pi(cmd_opts)
  M.send_current("pi", cmd_opts.args ~= "" and cmd_opts.args or "revise")
end

function M.cmd_inline_annotations(cmd_opts)
  local action = cmd_opts.args
  if action == "on" then
    annotations.set_enabled(true)
    return
  end

  if action == "off" then
    annotations.set_enabled(false)
    return
  end

  if action == "refresh" then
    annotations.refresh_buffer(0, { force = true })
    return
  end

  annotations.toggle()
end

function M.cmd_claude_batch(cmd_opts)
  M.prepare_batch("claude", cmd_opts.args ~= "" and cmd_opts.args or "needs-rework")
end

function M.cmd_pi_batch(cmd_opts)
  M.prepare_batch("pi", cmd_opts.args ~= "" and cmd_opts.args or "needs-rework")
end

function M.cmd_claude_review(cmd_opts)
  M.prepare_review("claude", cmd_opts.args ~= "" and cmd_opts.args or nil)
end

function M.cmd_pi_review(cmd_opts)
  M.prepare_review("pi", cmd_opts.args ~= "" and cmd_opts.args or nil)
end

return M
