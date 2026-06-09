local M = {}

local function adapter_mod()
  return require("config.review.hunk_local_adapter")
end

local function hunk_mod()
  return require("config.review.hunk")
end

local function comment_editor_mod()
  return require("config.review.hunk_comment_editor")
end

local function providers_mod()
  return require("config.review.providers")
end

local function util_mod()
  return require("config.review.util")
end

local function hunk_missing()
  vim.notify("Hunk CLI not found. Rerun scripts/install.sh or install with: npm i -g hunkdiff", vim.log.levels.WARN)
end

local function normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function current_target_path()
  local buffer_name = vim.api.nvim_buf_get_name(0)
  if buffer_name ~= "" then
    return buffer_name
  end

  return vim.fn.getcwd()
end

local function git_root(path)
  local target = path ~= "" and path or vim.fn.getcwd()
  local start = vim.fn.isdirectory(target) == 1 and target or vim.fs.dirname(target)
  if not start or start == "" then
    start = vim.fn.getcwd()
  end

  local root = vim.fs.root(start, ".git")
  return root and normalize(root) or nil
end

local function hunk_context()
  local root = git_root(current_target_path())
  if not root then
    return nil
  end

  return { repo = root }
end

local function relative_path(root, path)
  local normalized_root = normalize(root)
  local normalized_path = normalize(path)
  local prefix = normalized_root .. "/"

  if normalized_path == normalized_root then
    return "."
  end

  if vim.startswith(normalized_path, prefix) then
    return normalized_path:sub(#prefix + 1)
  end

  return normalized_path
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

local function direct_comment_target(line, end_line)
  local context = hunk_context()
  if not context then
    vim.notify("Add Hunk review comments from inside a git repository", vim.log.levels.WARN)
    return nil
  end

  if not hunk_mod().is_available() or not hunk_mod().session_exists(context.repo) then
    return nil
  end

  local buffer_name = vim.api.nvim_buf_get_name(0)
  if buffer_name == "" then
    vim.notify("Open a file buffer before adding a Hunk review comment", vim.log.levels.WARN)
    return nil
  end

  local comment_line = tonumber(line) or vim.api.nvim_win_get_cursor(0)[1]
  local comment_end_line = tonumber(end_line) or comment_line
  if comment_end_line < comment_line then
    comment_line, comment_end_line = comment_end_line, comment_line
  end

  local file = relative_path(context.repo, buffer_name)
  local label = comment_line == comment_end_line and string.format("%s:%d", file, comment_line)
    or string.format("%s:%d-%d", file, comment_line, comment_end_line)

  return {
    context = context,
    end_line = comment_end_line,
    file = file,
    label = label,
    line = comment_line,
  }
end

local function add_direct_comment(line, end_line)
  local target = direct_comment_target(line, end_line)
  if not target then
    return false
  end

  comment_editor_mod().prompt(target.label, function(body)
    if body == nil then
      return
    end

    local result, err = hunk_mod().add_comment(target.context, {
      author = "User",
      body = body,
      end_line = target.end_line,
      file = target.file,
      focus = true,
      line = target.line,
    })
    if not result then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    vim.notify("Review comment added to Hunk. Run :ReviewHunkSync pull before closing Hunk to persist it locally.", vim.log.levels.INFO)
  end)

  return true
end

function M.open_inbox(opts)
  local open_opts = type(opts) == "string" and { status = opts } or (opts or {})
  local context = hunk_context()
  if not context then
    vim.notify("Open the review inbox from inside a git repository", vim.log.levels.WARN)
    return
  end

  if not hunk_mod().is_available() then
    hunk_missing()
    return
  end

  local target = adapter_mod().inbox_target(open_opts.filter or open_opts.status)
  if target == false then
    return
  end

  if target.status or target.filter then
    vim.notify("Hunk is the default review inbox; legacy status filters require opt-in legacy commands.", vim.log.levels.INFO)
  end

  hunk_mod().open_or_reload(context, "diff --watch", { notify = false })
end

function M.show_current_hunk()
  local context = hunk_context()
  if not context then
    vim.notify("Open the current Hunk review from inside a git repository", vim.log.levels.WARN)
    return
  end

  if not hunk_mod().is_available() then
    hunk_missing()
    return
  end

  local buffer_name = vim.api.nvim_buf_get_name(0)
  if buffer_name ~= "" then
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local file = relative_path(context.repo, buffer_name)
    if hunk_mod().open_or_navigate(context, { file = file, line = line }) then
      return
    end
  end

  hunk_mod().open_or_reload(context, "diff --watch", { notify = false })
end

function M.annotate_current_hunk()
  if add_direct_comment(vim.api.nvim_win_get_cursor(0)[1]) then
    return
  end

  adapter_mod().annotate_current_hunk()
end

function M.annotate_line_range(start_line, end_line)
  if add_direct_comment(start_line, end_line) then
    return
  end

  adapter_mod().annotate_line_range(start_line, end_line)
end

function M.annotate_visual_selection()
  local start_line, end_line = selected_line_range()
  M.annotate_line_range(start_line, end_line)
end

function M.prepare_review(provider, target)
  local review_target = adapter_mod().review_target(target)
  if review_target == false then
    return
  end

  local context = hunk_context()
  if not context then
    vim.notify("Open this review command from inside a git repository", vim.log.levels.WARN)
    return
  end

  if not hunk_mod().is_available() then
    hunk_missing()
    return
  end

  local prompt = hunk_mod().review_prompt(provider, context, {
    target_label = review_target.label or "all live staged and unstaged hunks",
  })
  local dispatched, err = providers_mod().dispatch_prompt(provider, prompt, {
    cwd = context.repo,
    open_terminal = true,
    title = string.format(
      "review-%s-hunk-%s.md",
      provider,
      util_mod().sanitize_segment(review_target.slug or review_target.status or "all")
    ),
    message = string.format("Prepared Hunk HITL review prompt for %s and copied it to registers.", provider),
    after_exit = function()
      adapter_mod().after_provider_exit(context.repo)
    end,
  })

  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  if dispatched then
    local record_context = adapter_mod().best_context()
    if record_context then
      adapter_mod().record_agent_run(record_context, {
        provider = provider,
        mode = "hunk-review",
        scope = review_target.label,
        prompt_hash = vim.fn.sha256(dispatched),
        diff_signature = adapter_mod().repo_change_signature(context.repo),
        result = "running",
      })
    end
  end
end

function M.open_hunk(raw_args)
  local context = hunk_context()
  if not hunk_mod().is_available() then
    hunk_missing()
    return
  end

  hunk_mod().open_or_reload(context, raw_args, { notify = false })
end

function M.sync_hunk(action)
  adapter_mod().sync_hunk(action)
end

function M.navigate_hunk_comment(direction)
  local context = hunk_context()
  if not context then
    vim.notify("Navigate Hunk review comments from inside a git repository", vim.log.levels.WARN)
    return
  end

  if not hunk_mod().is_available() then
    hunk_missing()
    return
  end

  if not hunk_mod().session_exists(context.repo) then
    vim.notify("No active Hunk session for this repository. Run :ReviewHunk first.", vim.log.levels.WARN)
    return
  end

  local _, err = hunk_mod().navigate_comment(context, direction)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

function M.repo_change_signature(repo)
  return adapter_mod().repo_change_signature(repo)
end

function M.refresh_after_external_edit(repo, opts)
  return adapter_mod().refresh_after_external_edit(repo, opts)
end

function M.setup()
  adapter_mod().setup()
end

function M.cmd_open_inbox(cmd_opts)
  local filter = cmd_opts.args == "current-file" and "current-file" or nil
  local path

  if filter then
    local context = hunk_context()
    local buffer_name = vim.api.nvim_buf_get_name(0)
    if context and buffer_name ~= "" then
      path = relative_path(context.repo, buffer_name)
    end
  end

  M.open_inbox({ filter = filter, path = path, status = cmd_opts.args })
end

function M.cmd_annotate(cmd_opts)
  if cmd_opts.range and cmd_opts.range > 0 then
    M.annotate_line_range(cmd_opts.line1, cmd_opts.line2)
    return
  end

  M.annotate_current_hunk()
end

function M.cmd_open_hunk(cmd_opts)
  M.open_hunk(cmd_opts.args)
end

function M.cmd_sync_hunk(cmd_opts)
  M.sync_hunk(cmd_opts.args)
end

function M.cmd_hunk_next_comment()
  M.navigate_hunk_comment("next")
end

function M.cmd_hunk_prev_comment()
  M.navigate_hunk_comment("prev")
end

function M.cmd_claude_review(cmd_opts)
  M.prepare_review("claude", cmd_opts.args ~= "" and cmd_opts.args or nil)
end

function M.cmd_pi_review(cmd_opts)
  M.prepare_review("pi", cmd_opts.args ~= "" and cmd_opts.args or nil)
end

return M
