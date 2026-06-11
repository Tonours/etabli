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

local function context_for_cwd()
  return state_mod().context_for_repo(vim.fn.getcwd())
end

local function repo_items(context, opts)
  return items_mod().for_context(context, opts)
end

local function refresh_optional_annotations(repo)
  local annotations = package.loaded["config.review.annotations"]
  if annotations and annotations.refresh_repo then
    annotations.refresh_repo(repo)
  end
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
