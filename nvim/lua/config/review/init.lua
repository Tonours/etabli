local diff = require("config.review.diff")
local annotations = require("config.review.annotations")
local hunk = require("config.review.hunk")
local review_items = require("config.review.items")
local picker = require("config.review.picker")
local providers = require("config.review.providers")
local state = require("config.review.state")
local suggestions = require("config.review.suggestions")
local util = require("config.review.util")
local views = require("config.review.views")

local M = {}

local setup_done = false

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

local function normalize_inbox_target(target)
  if target == nil or target == "" or target == "all" then
    return {}
  end

  if state.is_valid_status(target) then
    return { status = target }
  end

  if review_items.is_valid_filter(target) then
    return { filter = target }
  end

  vim.notify(string.format("Invalid review inbox filter: %s", target), vim.log.levels.ERROR)
  return false
end

local function repo_items(context, opts)
  return review_items.for_context(context, opts)
end

local function current_buffer_review_items()
  if vim.bo.modified then
    vim.notify("Save the current buffer before reviewing its git hunk", vim.log.levels.WARN)
    return nil, nil, nil
  end

  local context = context_for_current_buffer()
  if not context then
    return nil, nil, nil
  end

  local buffer_name = vim.api.nvim_buf_get_name(0)
  local relative_path = util.relative_path(context.repo, buffer_name)
  local items = repo_items(context, { include_stale = false, path = relative_path })
  if not items then
    return nil, nil, nil
  end

  return context, relative_path, items
end

local function current_hunk_item_at_line(line, opts)
  local options = opts or {}
  local context, relative_path, items = current_buffer_review_items()
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
  local context, relative_path, items = current_buffer_review_items()
  if not items then
    return nil, nil
  end

  local start_item
  for _, scope in ipairs(diff.scopes()) do
    for _, item in ipairs(items) do
      if not item.stale and item.path == relative_path and item.scope == scope and diff.hunk_contains_line(item, start_line) then
        start_item = item
        break
      end
    end

    if start_item then
      break
    end
  end

  if not start_item then
    vim.notify("Select lines inside one reviewable git hunk", vim.log.levels.INFO)
    return nil, nil
  end

  if not diff.hunk_contains_line(start_item, end_line) then
    vim.notify("Review comments can only cover one git hunk at a time", vim.log.levels.WARN)
    return nil, nil
  end

  return context, start_item
end

local function set_item_status(item, status)
  local _, err = state.set_status({ repo = item.repo, branch = item.branch }, item, status)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  review_items.clear_cache()
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

  review_items.clear_cache()
  if items[1] then
    annotations.refresh_repo(items[1].repo)
  end

  vim.notify(string.format("Review status set to %s for %d hunk(s)", status, updated), vim.log.levels.INFO)
  return true
end

local function set_item_reviewed(item, reviewed)
  local saved, err = state.set_reviewed({ repo = item.repo, branch = item.branch }, item, reviewed)
  if not saved then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  review_items.clear_cache()
  annotations.refresh_repo(item.repo)

  vim.notify(reviewed == false and "Review hunk marked open" or "Review hunk marked reviewed", vim.log.levels.INFO)
  return true
end

local function set_items_reviewed(items, reviewed)
  local updated = 0

  for _, item in ipairs(items) do
    local saved, err = state.set_reviewed({ repo = item.repo, branch = item.branch }, item, reviewed)
    if not saved then
      vim.notify(err, vim.log.levels.ERROR)
      return false
    end

    updated = updated + 1
  end

  review_items.clear_cache()
  if items[1] then
    annotations.refresh_repo(items[1].repo)
  end

  vim.notify(
    reviewed == false
        and string.format("Marked %d review hunk(s) open", updated)
      or string.format("Marked %d review hunk(s) reviewed", updated),
    vim.log.levels.INFO
  )
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
  local context = { repo = item.repo, branch = item.branch }

  if body == nil then
    if options.on_done then
      options.on_done()
    end
    return
  end

  local has_transaction = state.active_transaction(context) ~= nil
  local save = has_transaction and state.add_draft_comment or state.add_comment
  local _, err = save(context, item, {
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

  vim.notify(has_transaction and "Review draft comment added" or "Review comment added", vim.log.levels.INFO)
  review_items.clear_cache()
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

  pcall(
    vim.api.nvim_buf_set_name,
    bufnr,
    string.format("review-comment://%s-%d", util.sanitize_segment(target), bufnr)
  )
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

  local closed = false
  local group = vim.api.nvim_create_augroup(string.format("etabli_review_comment_%d", bufnr), { clear = true })

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

  local function comment_body()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return table.concat(lines, "\n")
  end

  local function has_comment_body()
    return vim.trim(comment_body()) ~= ""
  end

  local function submit(submit_opts)
    local submit_options = submit_opts or {}
    if closed then
      return
    end

    closed = true
    local body = comment_body()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.bo[bufnr].modified = false
    end

    finish_comment(item, line, end_line, body, options)

    if submit_options.defer_close then
      vim.schedule(close)
    else
      close()
    end
  end

  local function cancel(force)
    if closed then
      return
    end

    if force ~= true and has_comment_body() then
      vim.notify("Review comment not saved. Use :write or ZZ to save, ZQ to discard.", vim.log.levels.WARN)
      return
    end

    closed = true
    close()
    if options.on_done then
      options.on_done()
    end
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    group = group,
    callback = function()
      submit({ defer_close = true })
    end,
  })

  for _, mode in ipairs({ "n", "i" }) do
    vim.keymap.set(mode, "<C-s>", submit, {
      buffer = bufnr,
      desc = "Save review comment",
      nowait = true,
      silent = true,
    })
  end

  vim.keymap.set("n", "ZZ", submit, { buffer = bufnr, desc = "Save review comment", nowait = true, silent = true })
  vim.keymap.set("n", "ZQ", function()
    cancel(true)
  end, { buffer = bufnr, desc = "Discard review comment", nowait = true, silent = true })
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
  review_items.clear_cache()
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
      return string.format("%s %s: %s", comment.id or "?", views.comment_range_label(comment), body)
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
    "# Legacy Review Inbox Help",
    "",
    "- <Tab> or <S-Tab> mark entries for a batch provider action",
    "- <CR> open a diff view for the selected hunk",
    "- <C-a> add a review comment at the selected hunk start line",
    "- <C-s> set the selected hunk status",
    "- <C-y> accept the selected hunk or the marked set",
    "- r or <C-g> mark the selected hunk or marked set as reviewed without accepting it",
    "- <C-c> launch Claude directly with the selected diff prompt",
    "- <C-p> launch Pi directly with the selected diff prompt",
    "- <C-r> refresh the inbox after external changes",
    "- :ReviewLegacyInbox [status|filter] filter the local inbox by status or attention state",
    "- filters: attention, unresolved, stale, changed-since-review, reviewed:false, reviewed:true, current-file",
    "- :ReviewInlineAnnotations [on|off|refresh|toggle] controls inline review notes",
    "- :ReviewInlineAnnotations expand expands or collapses the thread under the cursor",
    "- :ReviewInlineAnnotations compact returns the current buffer to compact inline comments",
    "- :ReviewInbox and :ReviewHunk open or reload Hunk for the current repo",
    "- :ReviewResolve resolves the current review conversation",
    "- :ReviewAccept sets the current hunk status to accepted",
    "- :ReviewMarkReviewed [on|off|toggle] marks the current hunk reviewed without changing status",
    "- :ReviewStart begins a local draft review transaction",
    "- :ReviewPreview shows pending transaction comments",
    "- :ReviewSubmit [comment|approve|request-changes] submits pending transaction comments locally",
    "- :ReviewExport [markdown|json] exports the pending transaction",
    "- :ReviewClaudeBatch [status] prepare one prompt for all live hunks with that status",
    "- :ReviewPiBatch [status] prepare one prompt for all live hunks with that status",
    "- :ReviewClaudeReview [status|all|changed-only] launch a first-pass Claude code review",
    "- :ReviewPiReview [status|all|changed-only] launch a first-pass Pi code review",
    "- :ReviewIngestClaude [file] imports structured Claude findings from a file or unnamed register",
    "- :ReviewIngestPi [file] imports structured Pi findings from a file or unnamed register",
    "- :ReviewCompareAgents compares Pi and Claude findings for the current hunk",
    "- :ReviewSuggestionPreview safely previews the selected suggested change",
    "- :ReviewSuggestionStatus [open|applied|rejected|resolved] updates suggestion state",
    "- <leader>rA accepts the current hunk quickly",
    "- <leader>rbc and <leader>rbp run the default needs-rework batch commands",
    "- <leader>rvc and <leader>rvp run first-pass review commands",
    "- stale new, accepted, and ignored entries are hidden from the legacy inbox to reduce noise",
    "- if you want to inspect them again, open an explicit filter like :ReviewLegacyInbox new",
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

local function normalize_review_target(target)
  if target == nil or target == "" or target == "all" then
    return {
      label = "all live staged and unstaged hunks",
      slug = "all",
    }
  end

  if target == "changed-only" then
    return {
      filter = "changed-since-review",
      label = "changed since last review",
      slug = "changed-only",
    }
  end

  local normalized_status = normalize_status(target)
  if normalized_status == false then
    return false
  end

  return {
    label = string.format("review status: %s", normalized_status),
    slug = normalized_status,
    status = normalized_status,
  }
end

local function prepare_review(provider, target)
  local review_target = normalize_review_target(target)
  if review_target == false then
    return
  end

  local context = best_context()
  if not context then
    vim.notify("Open this review command from inside a git repository", vim.log.levels.WARN)
    return
  end

  if hunk.is_available() then
    local prompt = hunk.review_prompt(provider, context, {
      target_label = review_target.label or "all live staged and unstaged hunks",
    })
    local dispatched, err = providers.dispatch_prompt(provider, prompt, {
      cwd = context.repo,
      open_terminal = true,
      title = string.format(
        "review-%s-hunk-%s.md",
        provider,
        util.sanitize_segment(review_target.slug or review_target.status or "all")
      ),
      message = string.format("Prepared Hunk HITL review prompt for %s and copied it to registers.", provider),
      after_exit = function()
        review_items.clear_cache()
        annotations.refresh_repo(context.repo)
      end,
    })

    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    if dispatched then
      state.record_agent_run(context, {
        provider = provider,
        mode = "hunk-review",
        scope = review_target.label,
        prompt_hash = vim.fn.sha256(dispatched),
        diff_signature = review_items.repo_change_signature(context.repo),
        result = "running",
      })
    end

    return
  end

  local items = repo_items(context, {
    filter = review_target.filter,
    include_stale = false,
    status = review_target.status,
  })

  if not items or vim.tbl_isempty(items) then
    local label = review_target.label and string.format(" for %s", review_target.label) or ""
    vim.notify("No live review hunks found" .. label, vim.log.levels.INFO)
    return
  end

  local prompt, err = providers.dispatch_batch(provider, items, {
    action = "review",
    cwd = context.repo,
    open_terminal = true,
    selection_label = review_target.label,
    slug = review_target.slug,
    status = review_target.status,
    after_exit = function()
      reopen_inbox_later({
        filter = review_target.filter,
        include_stale = false,
        status = review_target.status,
      })
    end,
  })

  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  if prompt then
    state.record_agent_run(context, {
      provider = provider,
      mode = "review",
      scope = review_target.label,
      prompt_hash = vim.fn.sha256(prompt),
      diff_signature = review_items.repo_change_signature(context.repo),
      result = "running",
    })
  end
end

local function read_agent_output_source(source)
  local target = vim.trim(source or "")
  if target ~= "" then
    local path = vim.fn.expand(target)
    local ok_read, lines = pcall(vim.fn.readfile, path)
    if not ok_read then
      return nil, string.format("Could not read agent output file: %s", path)
    end

    return table.concat(lines, "\n"), path
  end

  local register_text = vim.fn.getreg('"')
  if register_text == "" then
    return nil, "No agent output path was provided and the unnamed register is empty"
  end

  return register_text, "unnamed register"
end

local function ingest_provider_output(provider, source)
  local context = best_context()
  if not context then
    vim.notify("Import agent review output from inside a git repository", vim.log.levels.WARN)
    return
  end

  local output, source_label = read_agent_output_source(source)
  if not output then
    vim.notify(source_label, vim.log.levels.ERROR)
    return
  end

  local summary, err = state.ingest_agent_output(context, provider, output, {
    diff_signature = review_items.repo_change_signature(context.repo),
    scope = source_label,
  })
  if not summary then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  review_items.clear_cache()
  annotations.refresh_repo(context.repo)
  vim.notify(
    string.format(
      "Imported %d/%d %s finding(s), skipped %d",
      summary.imported,
      summary.parsed,
      provider,
      summary.skipped
    ),
    vim.log.levels.INFO
  )
end

local function select_suggestion(item, on_choice)
  local candidates = suggestions.for_item(item)
  if vim.tbl_isempty(candidates) then
    vim.notify("No suggested changes found for this hunk", vim.log.levels.INFO)
    return
  end

  if #candidates == 1 then
    on_choice(candidates[1])
    return
  end

  vim.ui.select(candidates, {
    prompt = "Suggested change",
    format_item = suggestions.format_candidate,
  }, function(choice)
    if choice then
      on_choice(choice)
    end
  end)
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

function M.show_legacy_current_hunk()
  local _, item = current_hunk_item()
  if not item then
    return
  end

  util.open_scratch("review-current-hunk.md", views.render_item(item), "markdown")
end

function M.show_current_hunk()
  local context = best_context()
  if hunk.is_available() then
    if not context then
      vim.notify("Open the current Hunk review from inside a git repository", vim.log.levels.WARN)
      return
    end

    local buffer_name = vim.api.nvim_buf_get_name(0)
    if buffer_name ~= "" then
      local line = vim.api.nvim_win_get_cursor(0)[1]
      local file = util.relative_path(context.repo, buffer_name)
      if hunk.open_or_navigate(context, { file = file, line = line }) then
        return
      end
    end

    hunk.open_or_reload(context, "diff --watch", { notify = false })
    return
  end

  M.show_legacy_current_hunk()
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

function M.mark_current_reviewed(reviewed)
  local _, item = current_hunk_item()
  if not item then
    return
  end

  local next_reviewed = reviewed
  if next_reviewed == nil then
    next_reviewed = item.reviewed ~= true
  end

  set_item_reviewed(item, next_reviewed)
end

function M.start_transaction()
  local context = best_context()
  if not context then
    vim.notify("Open a review transaction from inside a git repository", vim.log.levels.WARN)
    return
  end

  local transaction, err = state.start_transaction(context)
  if not transaction then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  vim.notify(string.format("Review transaction %s started", transaction.id or "?"), vim.log.levels.INFO)
end

function M.preview_transaction()
  local context = best_context()
  if not context then
    vim.notify("Open a review transaction preview from inside a git repository", vim.log.levels.WARN)
    return
  end

  local transaction = state.active_transaction(context)
  if not transaction then
    vim.notify("No active review transaction", vim.log.levels.INFO)
    return
  end

  util.open_scratch("review-transaction.md", views.render_transaction(transaction), "markdown")
end

function M.submit_transaction(verdict)
  local context = best_context()
  if not context then
    vim.notify("Submit a review transaction from inside a git repository", vim.log.levels.WARN)
    return
  end

  local result, err = state.submit_transaction(context, verdict)
  if not result then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  review_items.clear_cache()
  annotations.refresh_repo(context.repo)
  vim.notify(
    string.format(
      "Review transaction submitted as %s: %d comment(s) across %d hunk(s)",
      result.verdict,
      result.submitted_comments,
      result.submitted_items
    ),
    vim.log.levels.INFO
  )
end

function M.export_transaction(format)
  local context = best_context()
  if not context then
    vim.notify("Export a review transaction from inside a git repository", vim.log.levels.WARN)
    return
  end

  local transaction = state.active_transaction(context)
  if not transaction then
    vim.notify("No active review transaction", vim.log.levels.INFO)
    return
  end

  local target_format = format == "json" and "json" or "markdown"
  if target_format == "json" then
    util.open_scratch("review-transaction.json", { vim.json.encode(transaction) }, "json")
    return
  end

  util.open_scratch("review-transaction.md", views.render_transaction(transaction), "markdown")
end

function M.send_current(provider, action)
  local _, item = current_hunk_item()
  if not item then
    return
  end

  send_item(item, provider, action)
end

function M.ingest_agent_output(provider, source)
  ingest_provider_output(provider, source)
end

function M.compare_current_agents()
  local _, item = current_hunk_item()
  if not item then
    return
  end

  if vim.tbl_isempty(item.agent_findings or {}) then
    vim.notify("No agent findings found for this hunk", vim.log.levels.INFO)
    return
  end

  util.open_scratch("review-agent-findings.md", views.render_agent_compare(item), "markdown")
end

function M.preview_current_suggestion()
  local _, item = current_hunk_item()
  if not item then
    return
  end

  select_suggestion(item, function(candidate)
    util.open_scratch("review-suggestion.md", suggestions.preview_lines(item, candidate), "markdown")
  end)
end

function M.set_current_suggestion_status(status)
  local context, item = current_hunk_item()
  if not item then
    return
  end

  select_suggestion(item, function(candidate)
    local _, err = state.set_agent_finding_status(context, item, candidate.id, status)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    review_items.clear_cache()
    annotations.refresh_repo(item.repo)
    vim.notify(string.format("Suggested change marked %s", status), vim.log.levels.INFO)
  end)
end

function M.open_legacy_inbox(opts)
  local open_opts = type(opts) == "string" and { status = opts } or (opts or {})
  local target = normalize_inbox_target(open_opts.filter or open_opts.status)
  if target == false then
    return
  end
  local status = target.status
  local filter = target.filter

  local context = best_context()

  if not context then
    vim.notify("Open the inbox from inside a git repository", vim.log.levels.WARN)
    return
  end

  local items = repo_items(context, {
    filter = filter,
    include_stale = open_opts.include_stale ~= false,
    path = filter == "current-file" and open_opts.path or nil,
    sort = open_opts.sort or "attention",
    status = status,
  })
  if not items or vim.tbl_isempty(items) then
    local label = status and string.format(" with status %s", status) or (filter and string.format(" with filter %s", filter) or "")
    vim.notify("No reviewable staged or unstaged hunks found" .. label, vim.log.levels.INFO)
    return
  end

  local reopen_opts = {
    filter = filter,
    include_stale = open_opts.include_stale,
    path = open_opts.path,
    sort = open_opts.sort,
    status = status,
  }

  picker.open(items, {
    on_select = views.open_item_diff,
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
    on_reviewed = function(selected)
      if set_items_reviewed(selected, true) then
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
    filter = filter,
    focus_fingerprint = open_opts.focus_fingerprint,
    status = status,
  })
end

function M.open_inbox(opts)
  local open_opts = type(opts) == "string" and { status = opts } or (opts or {})
  if open_opts.legacy == true or not hunk.is_available() then
    M.open_legacy_inbox(open_opts)
    return
  end

  local context = best_context()
  if not context then
    vim.notify("Open the review inbox from inside a git repository", vim.log.levels.WARN)
    return
  end

  local target = normalize_inbox_target(open_opts.filter or open_opts.status)
  if target == false then
    return
  end

  if target.status or target.filter then
    vim.notify("Hunk is the default review inbox; legacy status filters are available with :ReviewLegacyInbox.", vim.log.levels.INFO)
  end

  hunk.open_or_reload(context, "diff --watch", { notify = false })
end

function M.prepare_batch(provider, status)
  prepare_batch(provider, status)
end

function M.prepare_review(provider, status)
  prepare_review(provider, status)
end

function M.open_hunk(raw_args)
  local context = best_context()
  hunk.open_or_reload(context, raw_args, { notify = false })
end

function M.repo_change_signature(repo)
  return review_items.repo_change_signature(repo)
end

function M.refresh_after_external_edit(repo, opts)
  if not repo or repo == "" then
    return
  end

  local options = opts or {}

  review_items.clear_cache()
  review_items.refresh_buffers(repo)

  local after_signature = review_items.repo_change_signature(repo)
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
    callback = review_items.clear_cache,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = cache_group,
    callback = review_items.clear_cache_on_focus,
  })

  annotations.setup()
end


-- Thin wrappers for lazy-loaded commands (called from init.lua lazy_cmd registrations)
function M.cmd_open_inbox(cmd_opts)
  local filter = cmd_opts.args == "current-file" and "current-file" or nil
  local path

  if filter then
    local context = best_context()
    local buffer_name = vim.api.nvim_buf_get_name(0)
    if context and buffer_name ~= "" then
      path = util.relative_path(context.repo, buffer_name)
    end
  end

  M.open_inbox({ filter = filter, path = path, status = cmd_opts.args })
end

function M.cmd_open_legacy_inbox(cmd_opts)
  local filter = cmd_opts.args == "current-file" and "current-file" or nil
  local path

  if filter then
    local context = best_context()
    local buffer_name = vim.api.nvim_buf_get_name(0)
    if context and buffer_name ~= "" then
      path = util.relative_path(context.repo, buffer_name)
    end
  end

  M.open_legacy_inbox({ filter = filter, path = path, status = cmd_opts.args })
end

function M.cmd_show_legacy_current_hunk()
  M.show_legacy_current_hunk()
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

function M.cmd_mark_reviewed(cmd_opts)
  local action = cmd_opts.args
  if action == "" or action == "on" then
    M.mark_current_reviewed(true)
    return
  end

  if action == "off" then
    M.mark_current_reviewed(false)
    return
  end

  if action == "toggle" then
    M.mark_current_reviewed()
    return
  end

  vim.notify(string.format("Invalid review mark action: %s", action), vim.log.levels.ERROR)
end

function M.cmd_start_transaction()
  M.start_transaction()
end

function M.cmd_preview_transaction()
  M.preview_transaction()
end

function M.cmd_submit_transaction(cmd_opts)
  M.submit_transaction(cmd_opts.args ~= "" and cmd_opts.args or "comment")
end

function M.cmd_export_transaction(cmd_opts)
  M.export_transaction(cmd_opts.args ~= "" and cmd_opts.args or "markdown")
end

function M.cmd_ingest_claude(cmd_opts)
  M.ingest_agent_output("claude", cmd_opts.args)
end

function M.cmd_ingest_pi(cmd_opts)
  M.ingest_agent_output("pi", cmd_opts.args)
end

function M.cmd_compare_agents()
  M.compare_current_agents()
end

function M.cmd_preview_suggestion()
  M.preview_current_suggestion()
end

function M.cmd_suggestion_status(cmd_opts)
  local status = cmd_opts.args ~= "" and cmd_opts.args or "open"
  M.set_current_suggestion_status(status)
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

  if action == "expand" then
    annotations.expand_current_thread(0)
    return
  end

  if action == "compact" then
    annotations.compact_buffer(0)
    return
  end

  annotations.toggle()
end

function M.cmd_open_hunk(cmd_opts)
  M.open_hunk(cmd_opts.args)
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
