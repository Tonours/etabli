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

local overlay_border = { "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" }
local terminal_paste_delay_ms = 350

local function overlay_geometry()
  local available_width = math.max(20, vim.o.columns - 4)
  local preferred_width = math.max(60, math.floor(vim.o.columns * 0.8))
  local width = math.min(preferred_width, available_width)

  local available_height = math.max(6, vim.o.lines - 4)
  local preferred_height = math.max(10, math.floor(vim.o.lines * 0.45))
  local height = math.min(preferred_height, available_height)

  return {
    width = width,
    height = height,
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    row = math.max(0, vim.o.lines - height - 2),
  }
end

local function open_overlay_terminal_window()
  local bufnr = vim.api.nvim_create_buf(false, false)
  local geometry = overlay_geometry()
  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = geometry.width,
    height = geometry.height,
    col = geometry.col,
    row = geometry.row,
    style = "minimal",
    border = overlay_border,
  })

  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].winblend = 0

  return bufnr, winid
end

local function close_overlay_window(winid, bufnr)
  if winid and vim.api.nvim_win_is_valid(winid) then
    pcall(vim.api.nvim_win_close, winid, true)
  end

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

local function attach_overlay_shortcuts(bufnr, winid)
  local function close()
    close_overlay_window(winid, bufnr)
  end

  vim.keymap.set("n", "q", close, {
    buffer = bufnr,
    silent = true,
    nowait = true,
    desc = "Close provider overlay",
  })
  vim.keymap.set("n", "<Esc>", close, {
    buffer = bufnr,
    silent = true,
    nowait = true,
    desc = "Close provider overlay",
  })
  vim.keymap.set("t", "<Esc>", close, {
    buffer = bufnr,
    silent = true,
    nowait = true,
    desc = "Close provider overlay",
  })
end

local function provider_for(name)
  local provider = providers[name]
  if not provider then
    return nil, string.format("Unknown review provider: %s", name)
  end

  return provider
end

local function terminal_safe_input(input)
  local text = tostring(input or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  return text:gsub("[%z\1-\8\11\12\14-\31\127]", function(value)
    return string.format("\\x%02x", value:byte())
  end)
end

local function launch_spec(provider, prompt)
  return {
    command = { provider.command },
    input = terminal_safe_input(prompt),
    mode = "terminal-paste",
  }
end

local function bracketed_paste_input(input)
  return "\027[200~" .. input .. "\027[201~\r"
end

local function do_open_terminal(command, opts)
  local options = opts or {}
  local executable = vim.islist(command) and command[1] or command

  if vim.fn.executable(executable) ~= 1 then
    return false
  end

  local has_ui = #vim.api.nvim_list_uis() > 0
  local bufnr
  local winid

  if has_ui then
    bufnr, winid = open_overlay_terminal_window()
    attach_overlay_shortcuts(bufnr, winid)
  else
    vim.cmd.enew()
    bufnr = vim.api.nvim_get_current_buf()
    winid = vim.api.nvim_get_current_win()
  end

  vim.bo[bufnr].bufhidden = "hide"

  if options.title and options.title ~= "" then
    pcall(vim.api.nvim_buf_set_name, bufnr, options.title)
  end

  local ok_termopen, job_id = pcall(vim.fn.termopen, command, {
    cwd = options.cwd,
    on_exit = function()
      if options.on_exit then
        vim.schedule(options.on_exit)
      end
    end,
  })

  if not ok_termopen or type(job_id) ~= "number" or job_id <= 0 then
    close_overlay_window(winid, bufnr)
    return false
  end

  if has_ui then
    vim.cmd.startinsert()
  end

  if options.input and options.input ~= "" then
    vim.defer_fn(function()
      pcall(vim.api.nvim_chan_send, job_id, bracketed_paste_input(options.input))
    end, options.input_delay_ms or terminal_paste_delay_ms)
  end

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
  local can_open_terminal = open_terminal ~= false and vim.fn.executable(provider.command) == 1

  if can_open_terminal and cwd and cwd ~= "" then
    local ok, hunk_flow = pcall(require, "config.review.hunk_flow")
    if ok and hunk_flow and hunk_flow.repo_change_signature then
      before_signature = hunk_flow.repo_change_signature(cwd)
    end
  end

  vim.schedule(function()
    util.open_scratch(title, vim.split(prompt, "\n", { plain = true }), "markdown")

    if open_terminal == false then
      return
    end

    if can_open_terminal then
      local spec = launch_spec(provider, prompt)
      local launched = do_open_terminal(spec.command, {
        cwd = cwd,
        input = spec.input,
        input_delay_ms = terminal_paste_delay_ms,
        on_exit = function()
          local ok, hunk_flow = pcall(require, "config.review.hunk_flow")
          if ok and hunk_flow and hunk_flow.refresh_after_external_edit then
            hunk_flow.refresh_after_external_edit(cwd, {
              before_signature = before_signature,
              provider = provider.label,
            })
          end

          if options.after_exit then
            options.after_exit()
          end
        end,
        title = string.format("term://review-%s", provider.command),
      })

      if not launched then
        vim.notify(
          string.format("%s CLI could not be opened. The prompt was still copied to registers.", provider.label),
          vim.log.levels.WARN
        )
        return
      end

      if spec.mode == "terminal-paste" then
        vim.notify(
          string.format(
            "%s prompt uses terminal paste to keep the CLI interactive and avoid prompt argv exposure.",
            provider.label
          ),
          vim.log.levels.INFO
        )
      end
      return
    end

    vim.notify(
      string.format("%s CLI not found. The prompt was still copied to registers.", provider.label),
      vim.log.levels.WARN
    )
  end)

  vim.notify(message, vim.log.levels.INFO)

  return prompt
end

function M.launch_argv(name, prompt)
  local provider, err = provider_for(name)
  if not provider then
    return nil, err
  end

  return launch_spec(provider, prompt).command
end

function M.launch_spec(name, prompt)
  local provider, err = provider_for(name)
  if not provider then
    return nil, err
  end

  local spec = launch_spec(provider, prompt)
  return vim.deepcopy(spec)
end

function M.dispatch_prompt(name, prompt, opts)
  local provider, err = provider_for(name)
  if not provider then
    return nil, err
  end

  local options = opts or {}
  return dispatch_prompt(provider, prompt, {
    after_exit = options.after_exit,
    cwd = options.cwd,
    title = options.title or string.format("review-%s.md", name),
    open_terminal = options.open_terminal,
    message = options.message
      or string.format("Prepared Hunk review prompt for %s and copied it to registers.", provider.label),
  })
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
    after_exit = options.after_exit,
    cwd = options.cwd or item.repo,
    title = string.format("review-%s-%s.md", name, options.action or "revise"),
    open_terminal = options.open_terminal,
    message = string.format(
      "Prepared %s prompt for %s and copied it to registers.",
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
    after_exit = options.after_exit,
    cwd = options.cwd or items[1].repo,
    title = string.format(
      "review-%s-batch-%s-%s.md",
      name,
      util.sanitize_segment(options.slug or options.status or "selection"),
      action
    ),
    open_terminal = options.open_terminal,
    message = string.format(
      "Prepared %s batch prompt for %s (%d hunks) and copied it to registers.",
      action,
      provider.label,
      #items
    ),
  })
end

return M
