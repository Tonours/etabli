local prompts = require("config.review.prompts")
local util = require("config.review.util")

local M = {}

local providers = {
  claude = {
    command = "claude",
    label = "Claude",
  },
  pi = {
    command = "pi",
    label = "Pi",
  },
}

local function provider_for(name)
  local provider = providers[name]
  if not provider then
    return nil, string.format("Unknown review provider: %s", name)
  end

  return provider
end

local function launch_argv(provider, prompt)
  return { provider.command, prompt }
end

local function do_open_terminal(command, opts)
  local options = opts or {}
  local executable = vim.islist(command) and command[1] or command

  if vim.fn.executable(executable) ~= 1 then
    return false
  end

  vim.cmd.tabnew()
  vim.fn.termopen(command, {
    cwd = options.cwd,
    on_exit = function()
      if options.on_exit then
        vim.schedule(options.on_exit)
      end
    end,
  })

  if options.title and options.title ~= "" then
    vim.api.nvim_buf_set_name(0, options.title)
  end

  vim.cmd.startinsert()
  return true
end

local function dispatch_prompt(provider, prompt, opts)
  local options = opts or {}

  util.copy_to_registers(prompt)

  local title = options.title or "review.md"
  local cwd = options.cwd
  local open_terminal = options.open_terminal
  local message = options.message
  local before_signature

  if cwd and cwd ~= "" then
    local ok, review = pcall(require, "config.review")
    if ok and review and review.repo_change_signature then
      before_signature = review.repo_change_signature(cwd)
    end
  end

  -- Use schedule for immediate but non-blocking execution
  vim.schedule(function()
    util.open_scratch(title, vim.split(prompt, "\n", { plain = true }), "markdown")

    if open_terminal ~= false then
      if vim.fn.executable(provider.command) == 1 then
        do_open_terminal(launch_argv(provider, prompt), {
          cwd = cwd,
          on_exit = function()
            local ok, review = pcall(require, "config.review")
            if ok and review and review.refresh_after_external_edit then
              review.refresh_after_external_edit(cwd, {
                before_signature = before_signature,
                provider = provider.label,
              })
            end
          end,
          title = string.format("term://review-%s", provider.command),
        })
      else
        vim.notify(
          string.format("%s CLI not found. The prompt was still copied to registers.", provider.label),
          vim.log.levels.WARN
        )
      end
    end
  end)

  vim.notify(message, vim.log.levels.INFO)

  return prompt
end

function M.launch_argv(name, prompt)
  local provider, err = provider_for(name)
  if not provider then
    return nil, err
  end

  return launch_argv(provider, prompt)
end

function M.dispatch(name, item, opts)
  local provider, err = provider_for(name)
  if not provider then
    return nil, err
  end

  local options = opts or {}
  local prompt = prompts.build(item, {
    action = options.action,
    provider = provider.label,
  })

  return dispatch_prompt(provider, prompt, {
    cwd = options.cwd or item.repo,
    title = string.format("review-%s-%s.md", name, options.action or "revise"),
    open_terminal = options.open_terminal,
    message = string.format(
      "Prepared %s prompt for %s, copied it to registers, and launched it directly in the CLI.",
      options.action or "revise",
      provider.label
    ),
  })
end

function M.dispatch_batch(name, items, opts)
  local provider, err = provider_for(name)
  if not provider then
    return nil, err
  end

  if vim.tbl_isempty(items or {}) then
    return nil, "No review hunks matched this batch request"
  end

  local options = opts or {}
  local action = options.action or "revise"
  local prompt = prompts.build_batch(items, {
    action = action,
    provider = provider.label,
    selection_label = options.selection_label or (options.status and string.format("review status: %s", options.status)),
  })

  return dispatch_prompt(provider, prompt, {
    cwd = options.cwd or items[1].repo,
    title = string.format(
      "review-%s-batch-%s-%s.md",
      name,
      util.sanitize_segment(options.slug or options.status or "selection"),
      action
    ),
    open_terminal = options.open_terminal,
    message = string.format(
      "Prepared %s batch prompt for %s (%d hunks), copied it to registers, and launched it directly in the CLI.",
      action,
      provider.label,
      #items
    ),
  })
end

return M
