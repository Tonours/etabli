local M = {}

local setup_done = false

local function ensure_setup()
  if not setup_done and M.setup then
    M.setup()
  end
end

local function diff_mod()
  return require("config.review.diff")
end

local function hunk_mod()
  return require("config.review.hunk")
end

local function items_mod()
  return require("config.review.items")
end

local function state_mod()
  return require("config.review.state")
end

local function util_mod()
  return require("config.review.util")
end

local function context_for_current_buffer()
  local context, err = state_mod().context_for_buffer(0)
  if not context then
    vim.notify(err, vim.log.levels.WARN)
    return nil
  end

  return context
end

local function context_for_cwd()
  return state_mod().context_for_repo(vim.fn.getcwd())
end

local function repo_items(context, opts)
  return items_mod().for_context(context, opts)
end

local function normalize_status(status, opts)
  local options = opts or {}

  if status == nil or status == "" or (options.allow_all and status == "all") then
    return nil
  end

  if not state_mod().is_valid_status(status) then
    vim.notify(string.format("Invalid review status: %s", status), vim.log.levels.ERROR)
    return false
  end

  return status
end

local function refresh_optional_annotations(repo)
  local annotations = package.loaded["config.review.annotations"]
  if annotations and annotations.refresh_repo then
    annotations.refresh_repo(repo)
  end
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
  local relative_path = util_mod().relative_path(context.repo, buffer_name)
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

  for _, scope in ipairs(diff_mod().scopes()) do
    for _, item in ipairs(items) do
      if not item.stale and item.path == relative_path and item.scope == scope and diff_mod().hunk_contains_line(item, line) then
        return context, item
      end
    end
  end

  if not options.silent then
    vim.notify("No reviewable git hunk found at the cursor", vim.log.levels.INFO)
  end
  return nil, nil
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
  for _, scope in ipairs(diff_mod().scopes()) do
    for _, item in ipairs(items) do
      if not item.stale and item.path == relative_path and item.scope == scope and diff_mod().hunk_contains_line(item, start_line) then
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

  if not diff_mod().hunk_contains_line(start_item, end_line) then
    vim.notify("Review comments can only cover one git hunk at a time", vim.log.levels.WARN)
    return nil, nil
  end

  return context, start_item
end

local function latest_matching_comment(saved, line, end_line, body)
  for index = #(saved.comments or {}), 1, -1 do
    local comment = saved.comments[index]
    if comment.line == line and comment.end_line == end_line and comment.body == vim.trim(body or "") then
      return comment
    end
  end

  return nil
end

local function sync_saved_comment_to_hunk(context, item, comment)
  if not comment or not hunk_mod().is_available() or not hunk_mod().session_exists(context.repo) then
    return false
  end

  local result, err = hunk_mod().add_comment(context, {
    author = "User",
    body = comment.body,
    end_line = comment.end_line,
    file = item.path,
    id = "comment:" .. tostring(comment.id or ""),
    line = comment.line,
  })

  if not result then
    vim.notify(string.format("Review comment saved locally; Hunk sync failed: %s", err), vim.log.levels.WARN)
    return false
  end

  return true
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

  local has_transaction = state_mod().active_transaction(context) ~= nil
  local save = has_transaction and state_mod().add_draft_comment or state_mod().add_comment
  local saved, err = save(context, item, {
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

  local hunk_synced = false
  if not has_transaction then
    hunk_synced = sync_saved_comment_to_hunk(context, item, latest_matching_comment(saved, line, end_line, body))
  end

  local message = has_transaction and "Review draft comment added"
    or (hunk_synced and "Review comment added to Hunk and local state" or "Review comment added")
  vim.notify(message, vim.log.levels.INFO)
  M.clear_cache()
  refresh_optional_annotations(item.repo)

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
    border = "single",
    col = geometry.col,
    height = geometry.height,
    relative = "editor",
    row = geometry.row,
    style = "minimal",
    title = string.format("Hunk review comment %s", target),
    title_pos = "center",
    width = geometry.width,
    zindex = 95,
  })

  pcall(
    vim.api.nvim_buf_set_name,
    bufnr,
    string.format("hunk-review-comment://%s-%d", util_mod().sanitize_segment(target), bufnr)
  )
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

  local closed = false
  local group = vim.api.nvim_create_augroup(string.format("etabli_hunk_review_comment_%d", bufnr), { clear = true })

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
      desc = "Save Hunk review comment",
      nowait = true,
      silent = true,
    })
  end

  vim.keymap.set("n", "ZZ", submit, { buffer = bufnr, desc = "Save Hunk review comment", nowait = true, silent = true })
  vim.keymap.set("n", "ZQ", function()
    cancel(true)
  end, { buffer = bufnr, desc = "Discard Hunk review comment", nowait = true, silent = true })
  vim.keymap.set("n", "q", cancel, { buffer = bufnr, desc = "Cancel Hunk review comment", nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = bufnr, desc = "Cancel Hunk review comment", nowait = true, silent = true })

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
    prompt = string.format("Hunk review comment %s: ", target),
  }, function(input)
    finish_comment(item, line, end_line, input, options)
  end)
end

local function hunk_comment_payloads_with_options(items, opts)
  local options = opts or {}
  local payloads = {}

  for _, item in ipairs(items or {}) do
    if not item.stale then
      for _, comment in ipairs(item.comments or {}) do
        local comment_id = tostring(comment.id or "")
        if
          comment.resolved ~= true
          and comment.body
          and comment.body ~= ""
          and (options.include_hunk_comments == true or not vim.startswith(comment_id, "hunk_"))
        then
          table.insert(payloads, {
            author = "User",
            body = comment.body,
            end_line = comment.end_line,
            file = item.path,
            id = "comment:" .. comment_id,
            line = comment.line,
          })
        end
      end

      for _, finding in ipairs(item.agent_findings or {}) do
        if finding.status == nil or finding.status == "open" then
          local details = {}
          if finding.severity and finding.severity ~= "" then
            table.insert(details, "Severity: " .. finding.severity)
          end
          if finding.issue and finding.issue ~= "" then
            table.insert(details, "Issue: " .. finding.issue)
          end
          if finding.impact and finding.impact ~= "" then
            table.insert(details, "Impact: " .. finding.impact)
          end
          if finding.suggested_fix and finding.suggested_fix ~= "" then
            table.insert(details, "Suggested fix: " .. finding.suggested_fix)
          end

          table.insert(payloads, {
            author = finding.provider or "agent",
            body = finding.review_comment,
            end_line = finding.end_line,
            file = item.path,
            id = "finding:" .. tostring(finding.id or ""),
            line = finding.line or item.line_start,
            rationale = table.concat(details, "\n"),
          })
        end
      end
    end
  end

  return payloads
end

local function comment_summary(body)
  local lines = vim.split(tostring(body or ""), "\n", { plain = true })
  return vim.trim((lines[1] or ""):gsub("%s+", " "))
end

local function comment_key(file, line, body)
  local normalized_file = tostring(file or "")
  local normalized_line = tostring(tonumber(line) or "")
  local normalized_summary = comment_summary(body)
  if normalized_file == "" or normalized_line == "" or normalized_summary == "" then
    return nil
  end

  return table.concat({ normalized_file, normalized_line, normalized_summary }, "\0")
end

local function hunk_note_line(note)
  local range = note and (note.newRange or note.oldRange) or nil
  if type(range) == "table" then
    return tonumber(range[1])
  end

  return tonumber(note and (note.newLine or note.oldLine))
end

local function hunk_marker(body)
  return tostring(body or ""):match("Etabli id:%s*([^%s]+)")
end

local function existing_hunk_note_index(context)
  local model, err = hunk_mod().review_model(context, { include_notes = true })
  if not model then
    return nil, err
  end

  local index = {
    keys = {},
    markers = {},
  }
  for _, note in ipairs((model.review or {}).reviewNotes or {}) do
    local key = comment_key(note.filePath, hunk_note_line(note), note.body)
    if key then
      index.keys[key] = true
    end

    local marker = hunk_marker(note.body)
    if marker then
      index.markers[marker] = true
    end
  end

  return index
end

local function comment_exists(comments, id)
  for _, comment in ipairs(comments or {}) do
    if comment.id == id then
      return true
    end
  end

  return false
end

local function item_for_hunk_note(items, note)
  local file_path = note.filePath
  local range = note.newRange or note.oldRange
  local line = type(range) == "table" and tonumber(range[1]) or nil
  local fallback

  for _, item in ipairs(items or {}) do
    if not item.stale and item.path == file_path then
      fallback = fallback or item
      if line and diff_mod().hunk_contains_line(item, line) then
        return item, line, tonumber(range[2]) or line
      end
    end
  end

  if fallback then
    return fallback, line or fallback.line_start, line or fallback.line_start
  end

  return nil
end

local function pull_hunk_notes(context)
  local model, err = hunk_mod().review_model(context, { include_notes = true })
  if not model then
    return nil, err
  end

  local items = repo_items(context, { include_stale = false })
  local imported = 0
  local skipped = 0

  for _, note in ipairs((model.review or {}).reviewNotes or {}) do
    local item, line, end_line = item_for_hunk_note(items, note)
    local body = note.body or ""
    local exported_marker = hunk_marker(body)
    if exported_marker then
      skipped = skipped + 1
    elseif body == "" or not item or not line then
      skipped = skipped + 1
    else
      local note_key = note.noteId or table.concat({
        note.filePath or "",
        tostring(line or ""),
        body,
      }, "\0")
      local comment_id = "hunk_" .. vim.fn.sha256(note_key):sub(1, 12)
      local comments = vim.deepcopy(item.comments or {})
      if comment_exists(comments, comment_id) then
        skipped = skipped + 1
      else
        table.insert(comments, {
          body = body,
          created_at = note.createdAt,
          end_line = end_line,
          id = comment_id,
          line = line,
          resolved = false,
          updated_at = note.createdAt,
        })

        local saved, save_err = state_mod().save_item(context, item, { comments = comments })
        if not saved then
          return nil, save_err
        end
        imported = imported + 1
      end
    end
  end

  M.clear_cache()
  refresh_optional_annotations(context.repo)
  return { imported = imported, skipped = skipped }
end

local function push_hunk_notes(context, opts)
  local options = opts or {}
  if not hunk_mod().session_exists(context.repo) then
    return nil, "No active Hunk session for this repository. Run :ReviewHunk first."
  end

  local items = repo_items(context, { include_stale = false })
  local payloads = hunk_comment_payloads_with_options(items, {
    include_hunk_comments = options.include_hunk_comments == true,
  })
  local existing, existing_err = existing_hunk_note_index(context)
  if not existing then
    return nil, existing_err
  end

  local filtered = {}
  local skipped_existing = 0
  for _, payload in ipairs(payloads) do
    local key = comment_key(payload.file, payload.line, payload.body)
    local marker = payload.id and tostring(payload.id) or nil
    if marker and existing.markers[marker] then
      skipped_existing = skipped_existing + 1
    elseif key and existing.keys[key] then
      skipped_existing = skipped_existing + 1
    else
      table.insert(filtered, payload)
    end
  end

  if vim.tbl_isempty(filtered) then
    return { applied = 0, skipped = skipped_existing }
  end

  local result, err = hunk_mod().apply_comments(context, filtered, { dedupe = false })
  if not result then
    return nil, err
  end

  result.skipped = (result.skipped or 0) + skipped_existing
  return result
end

function M.best_context()
  ensure_setup()

  local hunk_repo = vim.b.etabli_hunk_repo
  if hunk_repo and hunk_repo ~= "" then
    local hunk_context = state_mod().context_for_repo(hunk_repo)
    if hunk_context then
      return hunk_context
    end
  end

  if vim.api.nvim_buf_get_name(0) ~= "" then
    local buffer_context = state_mod().context_for_buffer(0)
    if buffer_context then
      return buffer_context
    end
  end

  return context_for_cwd()
end

function M.relative_path(repo, path)
  return util_mod().relative_path(repo, path)
end

function M.inbox_target(target)
  if target == nil or target == "" or target == "all" then
    return {}
  end

  if state_mod().is_valid_status(target) then
    return { status = target }
  end

  if items_mod().is_valid_filter(target) then
    return { filter = target }
  end

  vim.notify(string.format("Invalid review inbox filter: %s", target), vim.log.levels.ERROR)
  return false
end

function M.review_target(target)
  if target == nil or target == "" or target == "all" then
    return {
      label = "all live staged and unstaged hunks",
      slug = "all",
    }
  end

  if target == "changed-only" then
    return {
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

function M.annotate_current_hunk()
  ensure_setup()

  local _, item = current_hunk_item_at_line(vim.api.nvim_win_get_cursor(0)[1])
  if not item then
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  prompt_for_comment(item, { line = line })
end

function M.annotate_line_range(start_line, end_line)
  ensure_setup()

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

function M.sync_hunk(action)
  ensure_setup()

  local mode = action == "" and "pull" or (action or "pull")
  if mode ~= "push" and mode ~= "pull" and mode ~= "both" then
    vim.notify(string.format("Invalid Hunk sync action: %s", mode), vim.log.levels.ERROR)
    return
  end

  local context = M.best_context()
  if not context then
    vim.notify("Sync Hunk review notes from inside a git repository", vim.log.levels.WARN)
    return
  end

  if not hunk_mod().is_available() then
    vim.notify("Hunk CLI not found. Rerun scripts/install.sh or install with: npm i -g hunkdiff", vim.log.levels.WARN)
    return
  end

  local pulled
  local pushed
  if mode == "pull" or mode == "both" then
    local pull_err
    pulled, pull_err = pull_hunk_notes(context)
    if not pulled then
      vim.notify(pull_err, vim.log.levels.ERROR)
      return
    end
  end

  if mode == "push" or mode == "both" then
    local pushed_result, push_err = push_hunk_notes(context, { include_hunk_comments = true })
    if not pushed_result then
      vim.notify(push_err, vim.log.levels.ERROR)
      return
    end
    pushed = pushed_result
  end

  local parts = {}
  if pulled then
    table.insert(parts, string.format("pulled %d Hunk note(s), skipped %d", pulled.imported, pulled.skipped))
  end
  if pushed then
    table.insert(parts, string.format("pushed %d local note(s), skipped %d", pushed.applied, pushed.skipped))
  end
  vim.notify("Hunk review sync: " .. table.concat(parts, "; "), vim.log.levels.INFO)
end

local function context_for_repo_like(repo_or_context)
  if type(repo_or_context) == "table" and repo_or_context.repo then
    if repo_or_context.branch then
      return repo_or_context
    end

    local context = state_mod().context_for_repo(repo_or_context.repo)
    if context then
      for key, value in pairs(repo_or_context) do
        if context[key] == nil then
          context[key] = value
        end
      end
    end
    return context
  end

  if type(repo_or_context) == "string" and repo_or_context ~= "" then
    return state_mod().context_for_repo(repo_or_context)
  end

  return M.best_context()
end

function M.persist_repo(repo_or_context, opts)
  ensure_setup()

  local options = opts or {}
  local context = context_for_repo_like(repo_or_context)
  if not context then
    return nil, "Persist Hunk review notes from inside a git repository"
  end

  if not hunk_mod().is_available() or not hunk_mod().session_exists(context.repo) then
    return { imported = 0, no_session = true, skipped = 0 }
  end

  local pulled, err = pull_hunk_notes(context)
  if not pulled then
    if options.silent ~= true then
      vim.notify(err, vim.log.levels.WARN)
    end
    return nil, err
  end

  if options.silent ~= true and pulled.imported > 0 then
    vim.notify(string.format("Persisted %d Hunk note(s)", pulled.imported), vim.log.levels.INFO)
  end
  return pulled
end

function M.rehydrate_repo(repo_or_context, opts)
  ensure_setup()

  local options = opts or {}
  local context = context_for_repo_like(repo_or_context)
  if not context then
    return nil, "Rehydrate Hunk review notes from inside a git repository"
  end

  if not hunk_mod().is_available() or not hunk_mod().session_exists(context.repo) then
    return { applied = 0, no_session = true, skipped = 0 }
  end

  local pushed, err = push_hunk_notes(context, { include_hunk_comments = true })
  if not pushed then
    if options.silent ~= true then
      vim.notify(err, vim.log.levels.WARN)
    end
    return nil, err
  end

  if options.silent ~= true and pushed.applied > 0 then
    vim.notify(string.format("Rehydrated %d local Hunk note(s)", pushed.applied), vim.log.levels.INFO)
  end
  return pushed
end

function M.schedule_rehydrate(repo_or_context, opts)
  ensure_setup()

  local options = opts or {}
  local attempts = options.attempts or 8
  local delay_ms = options.delay_ms or 250
  local first_delay_ms = options.first_delay_ms or delay_ms

  local function attempt(index)
    local result = M.rehydrate_repo(repo_or_context, { silent = true })
    if result and result.no_session and index < attempts then
      vim.defer_fn(function()
        attempt(index + 1)
      end, delay_ms)
    end
  end

  vim.defer_fn(function()
    attempt(1)
  end, first_delay_ms)
end

function M.clear_cache()
  ensure_setup()

  items_mod().clear_cache()
end

function M.repo_change_signature(repo)
  ensure_setup()

  return items_mod().repo_change_signature(repo)
end

function M.record_agent_run(context, attrs)
  ensure_setup()

  return state_mod().record_agent_run(context, attrs)
end

function M.refresh_after_external_edit(repo, opts)
  ensure_setup()

  if not repo or repo == "" then
    return
  end

  local options = opts or {}

  M.clear_cache()
  items_mod().refresh_buffers(repo)

  local after_signature = items_mod().repo_change_signature(repo)
  local changed = options.before_signature ~= nil and after_signature ~= nil and options.before_signature ~= after_signature
  local provider = options.provider or "Review"

  if options.before_signature == nil or after_signature == nil then
    if options.silent ~= true then
      vim.notify(
        string.format("%s session closed; local buffers and review state refreshed.", provider),
        vim.log.levels.INFO,
        { title = "Review refresh" }
      )
    end
    return
  end

  if options.silent ~= true then
    vim.notify(
      changed
          and string.format("%s session closed; repo changes detected and local review state refreshed.", provider)
        or string.format("%s session closed; local review state refreshed, no repo change detected.", provider),
      vim.log.levels.INFO,
      { title = "Review refresh" }
    )
  end

  return changed
end

function M.after_provider_exit(repo)
  ensure_setup()

  M.clear_cache()
  refresh_optional_annotations(repo)
end

function M.setup()
  if setup_done then
    return
  end

  setup_done = true

  local cache_group = vim.api.nvim_create_augroup("etabli_hunk_review_cache", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufDelete", "DirChanged", "ShellCmdPost" }, {
    group = cache_group,
    callback = function()
      M.clear_cache()
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = cache_group,
    callback = function()
      items_mod().clear_cache_on_focus()
    end,
  })
end

return M
