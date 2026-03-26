local M = {}

local function render_preview(item)
  local lines = {
    "# Review Hunk",
    string.format("# File: %s", item.path),
    string.format("# Scope: %s", item.scope),
    string.format("# Status: %s", item.status or "new"),
    string.format("# Stale: %s", item.stale and "yes" or "no"),
  }

  if item.note and item.note ~= "" then
    table.insert(lines, string.format("# Note: %s", item.note))
  end

  table.insert(lines, "")

  for _, line in ipairs(vim.split(item.patch, "\n", { plain = true })) do
    table.insert(lines, line)
  end

  return lines
end

local function summarize(items)
  local counts = {
    total = #items,
    stale = 0,
    ["needs-rework"] = 0,
    question = 0,
    new = 0,
    accepted = 0,
    ignore = 0,
  }

  for _, item in ipairs(items) do
    local status = item.status or "new"
    counts[status] = (counts[status] or 0) + 1

    if item.stale then
      counts.stale = counts.stale + 1
    end
  end

  return counts
end

local function status_label(status)
  local labels = {
    ["needs-rework"] = "REWORK",
    question = "QUESTION",
    new = "NEW",
    accepted = "ACCEPT",
    ignore = "IGNORE",
  }

  return labels[status or "new"] or string.upper(status or "new")
end

local function scope_label(item)
  if item.stale then
    return "STALE"
  end

  return item.scope == "staged" and "STAGED" or "WORKING"
end

local function prompt_title(items, opts)
  local counts = summarize(items)
  local options = opts or {}
  local suffix = options.status and string.format(" [%s]", options.status) or ""

  return string.format(
    "Review Inbox%s %d total %d rework %d question %d stale",
    suffix,
    counts.total,
    counts["needs-rework"],
    counts.question,
    counts.stale
  )
end

function M.open(items, callbacks, opts)
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_previewers, previewers = pcall(require, "telescope.previewers")
  local ok_config, config = pcall(require, "telescope.config")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_state, action_state = pcall(require, "telescope.actions.state")

  if not (ok_pickers and ok_finders and ok_previewers and ok_config and ok_actions and ok_state) then
    vim.notify("Telescope not available", vim.log.levels.ERROR)
    return
  end

  local options = opts or {}

  local entry_maker = function(item)
    local stale = scope_label(item)
    local line = item.line_start or 0
    local status = status_label(item.status)
    local context = item.hunk_context ~= "" and (" " .. item.hunk_context) or ""
    local note = item.note and item.note ~= "" and (" note:" .. item.note) or ""

    return {
      display = string.format("[%s][%s] %s:%d%s", stale, status, item.path, line, context),
      ordinal = table.concat({ status, item.path, item.scope, item.hunk_header, context, note }, " "),
      value = item,
    }
  end

  local previewer = previewers.new_buffer_previewer({
    title = "Review Hunk",
    define_preview = function(self, entry)
      local lines = render_preview(entry.value)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.bo[self.state.bufnr].filetype = "diff"
    end,
  })

  pickers.new({}, {
    prompt_title = prompt_title(items, options),
    results_title = "<CR> jump | <C-a> note | <C-s> status | <C-c> Claude | <C-p> Pi | <C-r> refresh",
    finder = finders.new_table({
      results = items,
      entry_maker = entry_maker,
    }),
    previewer = previewer,
    sorter = config.values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local function with_selection(fn)
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if entry and fn then
          fn(entry.value)
        end
      end

      actions.select_default:replace(function()
        with_selection(callbacks.on_select)
      end)

      map("i", "<C-a>", function()
        with_selection(callbacks.on_annotate)
      end)
      map("n", "<C-a>", function()
        with_selection(callbacks.on_annotate)
      end)

      map("i", "<C-s>", function()
        with_selection(callbacks.on_status)
      end)
      map("n", "<C-s>", function()
        with_selection(callbacks.on_status)
      end)

      map("i", "<C-c>", function()
        with_selection(callbacks.on_claude)
      end)
      map("n", "<C-c>", function()
        with_selection(callbacks.on_claude)
      end)

      map("i", "<C-p>", function()
        with_selection(callbacks.on_pi)
      end)
      map("n", "<C-p>", function()
        with_selection(callbacks.on_pi)
      end)

      map("i", "<C-r>", function()
        with_selection(callbacks.on_refresh)
      end)
      map("n", "<C-r>", function()
        with_selection(callbacks.on_refresh)
      end)

      map("n", "?", function()
        if callbacks.on_help then
          callbacks.on_help()
        end
      end)

      return true
    end,
  }):find()
end

return M
