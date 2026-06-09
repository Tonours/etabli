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

local tracked_repos = {}

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

local function track_repo(repo)
  if repo and repo ~= "" then
    tracked_repos[normalize(repo)] = true
  end
end

local function is_diff_review(raw_args)
  local args = hunk_mod().parse_args(raw_args)
  return args ~= nil and args[1] == "diff"
end

local function persist_repo(repo)
  if not repo or repo == "" then
    return
  end

  if not hunk_mod().is_available() or not hunk_mod().session_exists(repo) then
    return
  end

  pcall(function()
    adapter_mod().persist_repo(repo, { silent = true })
  end)
end

local function rehydrate_repo(repo, opts)
  if not repo or repo == "" then
    return
  end

  local options = opts or {}
  local attempts = options.attempts or 8
  local delay_ms = options.delay_ms or 250
  local first_delay_ms = options.first_delay_ms or delay_ms

  local function attempt(index)
    if hunk_mod().is_available() and hunk_mod().session_exists(repo) then
      pcall(function()
        adapter_mod().rehydrate_repo(repo, { silent = true })
      end)
      return
    end

    if index < attempts then
      vim.defer_fn(function()
        attempt(index + 1)
      end, delay_ms)
    end
  end

  vim.defer_fn(function()
    attempt(1)
  end, first_delay_ms)
end

local function open_or_reload_hunk(context, raw_args, opts)
  local options = opts or {}
  if not context or not context.repo then
    return hunk_mod().open_or_reload(context, raw_args, { notify = options.notify })
  end

  track_repo(context.repo)
  local had_session = hunk_mod().is_available() and hunk_mod().session_exists(context.repo)
  if had_session then
    persist_repo(context.repo)
  end

  local opened = hunk_mod().open_or_reload(context, raw_args, { notify = options.notify })
  if opened and is_diff_review(raw_args) then
    if had_session then
      pcall(function()
        adapter_mod().rehydrate_repo(context.repo, { silent = true })
      end)
    else
      rehydrate_repo(context.repo, { first_delay_ms = options.first_delay_ms, silent = true })
    end
  end

  return opened
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

  vim.notify("Hunk review supports only all or changed-only. Legacy status filters require opt-in local commands.", vim.log.levels.ERROR)
  return false
end

local function help_lines()
  return {
    "# Hunk Review Help",
    "",
    "Default flow",
    "- :ReviewInbox or <leader>ri opens the watched Hunk diff for this repo",
    "- :ReviewCurrentHunk or <leader>rh focuses the current file line in Hunk",
    "- :ReviewAnnotate or <leader>ra adds an inline Hunk review comment",
    "- visual <leader>ra adds a range comment",
    "- :ReviewHunkSync [pull|push|both] or <leader>rs syncs Hunk notes and local state",
    "- :ReviewHunkNextComment / :ReviewHunkPrevComment or <leader>rn / <leader>rN navigate comments",
    "- :ReviewClaudeReview [all|changed-only] or <leader>rc starts a Claude HITL review pass",
    "- :ReviewPiReview [all|changed-only] or <leader>rp starts a Pi HITL review pass",
    "",
    "Review loop",
    "1. Open :ReviewInbox",
    "2. Use :ReviewAnnotate from file buffers for precise line or range comments",
    "3. Run Claude or Pi only when you want a read-only first pass",
    "4. Inspect agent comments as evidence, then accept, revise, or ignore manually",
    "5. Run :ReviewHunkSync pull before closing Hunk if comments were added outside Etabli",
    "",
    "Notes",
    "- Hunk is the default review surface; legacy local review commands are opt-in",
    "- Claude and Pi prompts stay interactive through terminal paste",
    "- If Hunk is not running, review commands open the watched diff first",
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
    if open_or_reload_hunk(context, "diff --watch", { notify = false }) then
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

    local persisted = adapter_mod().persist_repo(target.context, { silent = true })
    local message = persisted and "Review comment added to Hunk and persisted locally."
      or "Review comment added to Hunk. Run :ReviewHunkSync pull before closing Hunk to persist it locally."
    vim.notify(message, vim.log.levels.INFO)
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
    vim.notify("Hunk is the default review inbox; legacy status filters require opt-in legacy commands.", vim.log.levels.INFO)
  end

  open_or_reload_hunk(context, "diff --watch", { notify = false })
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

  open_or_reload_hunk(context, "diff --watch", { notify = false })
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
    if open_or_reload_hunk(context, "diff --watch", { notify = false }) then
      vim.notify(
        string.format("Hunk review opened. Run :Review%sReview again after the session is ready.", provider == "pi" and "Pi" or "Claude"),
        vim.log.levels.INFO
      )
    end
    return
  end

  persist_repo(context.repo)
  local reloaded, reload_err = hunk_mod().reload(context, "diff --watch")
  if not reloaded then
    vim.notify(reload_err, vim.log.levels.ERROR)
    return
  end
  adapter_mod().rehydrate_repo(context, { silent = true })

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
      local loaded_adapter = package.loaded["config.review.hunk_local_adapter"]
      if loaded_adapter and loaded_adapter.after_provider_exit then
        loaded_adapter.after_provider_exit(context.repo)
      end
    end,
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

function M.sync_hunk(action)
  adapter_mod().sync_hunk(action)
end

function M.help_lines()
  return vim.deepcopy(help_lines())
end

function M.show_help(opts)
  local options = opts or {}
  if #vim.api.nvim_list_uis() == 0 then
    util_mod().open_scratch("hunk-review-help.md", help_lines(), "markdown")
    return
  end

  util_mod().open_overlay("Hunk Review Help", help_lines(), {
    filetype = "markdown",
    on_close = options.on_close,
    origin_win = options.origin_win,
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
  local loaded_adapter = package.loaded["config.review.hunk_local_adapter"]
  if not repo or repo == "" then
    return
  end

  local options = opts or {}
  local after_signature = M.repo_change_signature(repo)
  local changed = options.before_signature ~= nil and after_signature ~= nil and options.before_signature ~= after_signature
  local provider = options.provider or "Review"

  vim.cmd.checktime()

  if hunk_mod().is_available() and hunk_mod().session_exists(repo) then
    if loaded_adapter and loaded_adapter.persist_repo then
      loaded_adapter.persist_repo(repo, { silent = true })
    end
    hunk_mod().reload({ repo = repo }, "diff --watch")
  end

  if loaded_adapter and loaded_adapter.refresh_after_external_edit then
    loaded_adapter.refresh_after_external_edit(repo, vim.tbl_extend("force", options, { silent = true }))
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

function M.setup()
  local group = vim.api.nvim_create_augroup("etabli_hunk_durable_review", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinLeave", "TermClose" }, {
    group = group,
    callback = function(args)
      local repo = vim.b[args.buf] and vim.b[args.buf].etabli_hunk_repo
      if repo and repo ~= "" then
        persist_repo(repo)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for repo in pairs(tracked_repos) do
        persist_repo(repo)
      end
    end,
  })
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

function M.cmd_sync_hunk(cmd_opts)
  M.sync_hunk(cmd_opts.args)
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
