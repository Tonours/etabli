local M = {}

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
  local hunk_repo = vim.b.etabli_hunk_repo
  if hunk_repo and hunk_repo ~= "" then
    return { repo = normalize(hunk_repo) }
  end

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

local function git_output(repo, args)
  local command = { "git", "-C", repo }
  vim.list_extend(command, args)
  local output = vim.fn.system(command)
  if vim.v.shell_error ~= 0 then
    return ""
  end

  return output
end

local function default_diff_command()
  return hunk_mod().default_diff_command()
end

local function open_or_reload_hunk(context, raw_args, opts)
  return hunk_mod().open_or_reload(context, raw_args, opts)
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
      label = "changed since last review",
      slug = "changed-only",
    }
  end

  vim.notify("Hunk review supports only all or changed-only.", vim.log.levels.ERROR)
  return false
end

local function help_lines()
  return {
    "Hunk review",
    "",
    "State     Hunk owns review sessions and notes",
    "Flow      inbox -> annotate -> agent pass",
    "Layout    adaptive split, no-wrap, line-numbered diff",
    "",
    "Keys",
    "  <leader>ri  :ReviewInbox                 open watched review",
    "  <leader>rh  :ReviewCurrentHunk           focus current line",
    "  <leader>ra  :ReviewAnnotate              add line comment",
    "  visual ra   :ReviewAnnotate              add range comment",
    "  <leader>rj  :ReviewHunkNextComment       next thread",
    "  <leader>rk  :ReviewHunkPrevComment       previous thread",
    "  <leader>rx  :ReviewContext               open context rail",
    "",
    "Agents",
    "  <leader>rc  :ReviewClaudeReview          Claude HITL review",
    "  <leader>rp  :ReviewPiReview              Pi HITL review",
    "  mode        all | changed-only            review target",
    "  prompt      interactive terminal paste     no prompt argv",
    "",
    "Model",
    "  Hunk persists sessions and notes itself",
    "  Agent findings are evidence tags, never auto-accepted",
  }
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

  if not hunk_mod().is_available() then
    hunk_missing()
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

  if not hunk_mod().session_exists(context.repo) then
    if open_or_reload_hunk(context, default_diff_command(), { notify = false }) then
      vim.notify("Hunk review opened. Run :ReviewAnnotate again after the session is ready.", vim.log.levels.INFO)
    end
    return nil
  end

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

    vim.notify("Review comment added to Hunk.", vim.log.levels.INFO)
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

  local target = open_opts.filter or open_opts.status
  if target and target ~= "" and target ~= "all" then
    vim.notify("Hunk is the review inbox; status filters are not supported.", vim.log.levels.INFO)
  end

  open_or_reload_hunk(context, default_diff_command(), { notify = false })
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
    if hunk_mod().session_exists(context.repo) then
      local ok, err = hunk_mod().navigate(context, file, line)
      if ok then
        return
      end

      vim.notify(err, vim.log.levels.WARN)
    end
  end

  open_or_reload_hunk(context, default_diff_command(), { notify = false })
end

function M.annotate_current_hunk()
  add_direct_comment(vim.api.nvim_win_get_cursor(0)[1])
end

function M.annotate_line_range(start_line, end_line)
  add_direct_comment(start_line, end_line)
end

function M.annotate_visual_selection()
  local start_line, end_line = selected_line_range()
  M.annotate_line_range(start_line, end_line)
end

function M.prepare_review(provider, target)
  local review_target = normalize_review_target(target)
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

  if not hunk_mod().session_exists(context.repo) then
    if open_or_reload_hunk(context, default_diff_command(), { notify = false }) then
      vim.notify(
        string.format("Hunk review opened. Run :Review%sReview again after the session is ready.", provider == "pi" and "Pi" or "Claude"),
        vim.log.levels.INFO
      )
    end
    return
  end

  local reloaded, reload_err = hunk_mod().reload(context, default_diff_command())
  if not reloaded then
    vim.notify(reload_err, vim.log.levels.ERROR)
    return
  end

  local prompt = hunk_mod().review_prompt(provider, context, {
    target_label = review_target.label or "all live staged and unstaged hunks",
  })
  local dispatched, err = providers_mod().dispatch_prompt(provider, prompt, {
    cwd = context.repo,
    env = hunk_mod().env(),
    open_terminal = true,
    title = string.format(
      "review-%s-hunk-%s.md",
      provider,
      util_mod().sanitize_segment(review_target.slug or review_target.status or "all")
    ),
    message = string.format("Prepared Hunk HITL review prompt for %s and copied it to registers.", provider),
  })

  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  return dispatched
end

function M.open_hunk(raw_args)
  local context = hunk_context()
  if not hunk_mod().is_available() then
    hunk_missing()
    return
  end

  open_or_reload_hunk(context, raw_args, { notify = false })
end

function M.open_context_rail()
  local context = hunk_context()
  if not context then
    vim.notify("Open the Hunk context rail from inside a git repository", vim.log.levels.WARN)
    return
  end
  if not hunk_mod().is_available() then
    hunk_missing()
    return
  end

  require("config.review.hunk_rail").open(context, {
    min_columns = 1,
    origin_win = vim.api.nvim_get_current_win(),
  })
end

function M.help_lines()
  return vim.deepcopy(help_lines())
end

function M.show_help(opts)
  local options = opts or {}
  if #vim.api.nvim_list_uis() == 0 then
    util_mod().open_scratch("hunk-review-help.txt", help_lines(), "text")
    return
  end

  util_mod().open_overlay("Hunk Review Help", help_lines(), {
    filetype = "text",
    footer = "q close",
    min_width = 68,
    on_close = options.on_close,
    origin_win = options.origin_win,
    placement = "right",
    title_pos = "left",
    width = 84,
  })
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
  if not repo or repo == "" then
    return nil
  end

  return vim.fn.sha256(table.concat({
    git_output(repo, { "status", "--porcelain=v1", "-z" }),
    git_output(repo, { "diff", "--cached", "--no-ext-diff", "--no-color", "--binary" }),
    git_output(repo, { "diff", "--no-ext-diff", "--no-color", "--binary" }),
  }, "\0"))
end

function M.refresh_after_external_edit(repo, opts)
  if not repo or repo == "" then
    return
  end

  local options = opts or {}
  local after_signature = M.repo_change_signature(repo)
  local changed = options.before_signature ~= nil and after_signature ~= nil and options.before_signature ~= after_signature
  local provider = options.provider or "Review"

  vim.cmd.checktime()

  if hunk_mod().is_available() and hunk_mod().session_exists(repo) then
    hunk_mod().reload({ repo = repo }, default_diff_command())
  end

  if options.before_signature == nil or after_signature == nil then
    vim.notify(
      string.format("%s session closed; local buffers refreshed.", provider),
      vim.log.levels.INFO,
      { title = "Review refresh" }
    )
    return
  end

  vim.notify(
    changed
        and string.format("%s session closed; repo changes detected and Hunk refreshed.", provider)
      or string.format("%s session closed; Hunk refreshed, no repo change detected.", provider),
    vim.log.levels.INFO,
    { title = "Review refresh" }
  )

  return changed
end

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

function M.cmd_open_hunk(cmd_opts)
  M.open_hunk(cmd_opts.args)
end

function M.cmd_help()
  M.show_help()
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
