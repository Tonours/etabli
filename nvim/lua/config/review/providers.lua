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

local function open_terminal(command)
  if vim.fn.exists(":Terminal") == 2 then
    vim.api.nvim_cmd({ cmd = "Terminal", args = { command } }, {})
    return true
  end

  if vim.fn.executable(command) ~= 1 then
    return false
  end

  vim.cmd.tabnew()
  vim.fn.termopen(command)
  vim.cmd.startinsert()
  return true
end

local function dispatch_prompt(provider, prompt, opts)
  local options = opts or {}

  util.copy_to_registers(prompt)
  util.open_scratch(options.title or "review.md", vim.split(prompt, "\n", { plain = true }), "markdown")

  if options.open_terminal ~= false then
    if vim.fn.executable(provider.command) == 1 then
      open_terminal(provider.command)
    else
      vim.notify(
        string.format("%s CLI not found. The prompt was still copied to registers.", provider.label),
        vim.log.levels.WARN
      )
    end
  end

  vim.notify(options.message, vim.log.levels.INFO)

  return prompt
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
    title = string.format("review-%s-%s.md", name, options.action or "revise"),
    open_terminal = options.open_terminal,
    message = string.format("Prepared %s prompt for %s and copied it to registers.", options.action or "revise", provider.label),
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
  local status = options.status or "needs-rework"
  local prompt = prompts.build_batch(items, {
    action = action,
    provider = provider.label,
    status = status,
  })

  return dispatch_prompt(provider, prompt, {
    title = string.format(
      "review-%s-batch-%s-%s.md",
      name,
      util.sanitize_segment(status),
      action
    ),
    open_terminal = options.open_terminal,
    message = string.format(
      "Prepared %s batch prompt for %s (%d hunks, status=%s) and copied it to registers.",
      action,
      provider.label,
      #items,
      status
    ),
  })
end

return M
