local M = {}

local function adapter_mod()
  return require("config.review.hunk_local_adapter")
end

local function hunk_mod()
  return require("config.review.hunk")
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

function M.open_inbox(opts)
  local open_opts = type(opts) == "string" and { status = opts } or (opts or {})
  local context = adapter_mod().best_context()
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
  local context = adapter_mod().best_context()
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
    local file = adapter_mod().relative_path(context.repo, buffer_name)
    if hunk_mod().open_or_navigate(context, { file = file, line = line }) then
      return
    end
  end

  hunk_mod().open_or_reload(context, "diff --watch", { notify = false })
end

function M.annotate_current_hunk()
  adapter_mod().annotate_current_hunk()
end

function M.annotate_line_range(start_line, end_line)
  adapter_mod().annotate_line_range(start_line, end_line)
end

function M.annotate_visual_selection()
  adapter_mod().annotate_visual_selection()
end

function M.prepare_review(provider, target)
  local review_target = adapter_mod().review_target(target)
  if review_target == false then
    return
  end

  local context = adapter_mod().best_context()
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
    adapter_mod().record_agent_run(context, {
      provider = provider,
      mode = "hunk-review",
      scope = review_target.label,
      prompt_hash = vim.fn.sha256(dispatched),
      diff_signature = adapter_mod().repo_change_signature(context.repo),
      result = "running",
    })
  end
end

function M.open_hunk(raw_args)
  local context = adapter_mod().best_context()
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
  local context = adapter_mod().best_context()
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
    local context = adapter_mod().best_context()
    local buffer_name = vim.api.nvim_buf_get_name(0)
    if context and buffer_name ~= "" then
      path = adapter_mod().relative_path(context.repo, buffer_name)
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
