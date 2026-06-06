local M = {}

local meta = require("config.review.meta")
local telescope_loader = require("config.telescope")
local util = require("config.review.util")

local function summarize(items)
  local counts = {
    total = #items,
    attention = 0,
    stale = 0,
    changed = 0,
    unreviewed = 0,
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
    if (item.attention_rank or 99) < 99 then
      counts.attention = counts.attention + 1
    end
    if item.changed_since_review then
      counts.changed = counts.changed + 1
    end
    if item.reviewed ~= true then
      counts.unreviewed = counts.unreviewed + 1
    end
  end

  return counts
end

local function scope_label(item)
  if item.stale then
    return "STALE"
  end

  return item.scope == "staged" and "STAGED" or "WORKING"
end

local function comment_range_label(comment)
  local line = tonumber(comment.line)
  local end_line = tonumber(comment.end_line) or line

  if line and end_line and end_line ~= line then
    return string.format("lines %d-%d", line, end_line)
  end

  return string.format("line %s", line or "?")
end

local function reviewed_label(item)
  if item.changed_since_review then
    return "changed"
  end

  if item.reviewed then
    return "reviewed"
  end

  return "open"
end

local function attention_marker(item)
  local reason = item.attention_reason
  if reason == "needs-human" then
    return "!"
  end
  if reason == "needs-recheck" or reason == "changed-since-review" then
    return "~"
  end
  if reason == "needs-review" then
    return ">"
  end
  if reason == "ready-to-accept" then
    return "+"
  end
  return " "
end

local function attention_highlight(item)
  local reason = item.attention_reason
  if reason == "needs-human" then
    return "DiagnosticError"
  end
  if reason == "needs-recheck" or reason == "changed-since-review" then
    return "DiagnosticWarn"
  end
  if reason == "needs-review" or reason == "ready-to-accept" then
    return "DiagnosticInfo"
  end
  return "Comment"
end

local function unresolved_comments(comments)
  local unresolved = {}

  for _, comment in ipairs(comments or {}) do
    if comment.resolved ~= true and comment.body and comment.body ~= "" then
      table.insert(unresolved, comment)
    end
  end

  return unresolved
end

local function render_preview(item)
  local comments = item.comments or {}
  local draft_comments = item.draft_comments or {}
  local unresolved = unresolved_comments(comments)
  local lines = {
    "Review hunk",
    "",
    string.format("File:   %s", item.path),
    string.format("Line:   %s", item.line_start or "?"),
    string.format("Scope:  %s", scope_label(item)),
    string.format("Status: %s", meta.label(item.status)),
    string.format("Attention: %s", item.attention_label or item.attention_reason or "MUTED"),
    string.format("Reviewed:  %s", reviewed_label(item)),
  }

  if item.changed_since_review and item.reviewed_at then
    table.insert(lines, string.format("Changed since review: %s", item.reviewed_at))
  end

  if item.note and item.note ~= "" then
    table.insert(lines, "Note:")
    util.append_text_lines(lines, item.note, "  ")
  end

  if #draft_comments > 0 then
    table.insert(lines, "Pending transaction comments:")
    for _, comment in ipairs(draft_comments) do
      table.insert(lines, string.format("  - %s %s [pending]:", comment.id or "?", comment_range_label(comment)))
      util.append_text_lines(lines, comment.body or "", "    ")
    end
  end

  if #unresolved > 0 then
    table.insert(lines, "Unresolved comments:")
    for _, comment in ipairs(unresolved) do
      table.insert(
        lines,
        string.format(
          "  - %s %s [%s]:",
          comment.id or "?",
          comment_range_label(comment),
          comment.resolved and "resolved" or "unresolved"
        )
      )
      util.append_text_lines(lines, comment.body or "", "    ")
    end
  end

  if #comments > #unresolved then
    table.insert(lines, string.format("Resolved comments: %d", #comments - #unresolved))
  end

  table.insert(lines, "")
  table.insert(lines, string.rep("-", 72))
  table.insert(lines, "")

  local patch_lines = vim.split(item.patch, "\n", { plain = true })
  vim.list_extend(lines, patch_lines)

  return lines
end

local function scope_highlight(item)
  if item.stale then
    return "Comment"
  end

  return item.scope == "staged" and "DiagnosticHint" or "Identifier"
end

local function prompt_title(items, opts)
  local counts = summarize(items)
  local options = opts or {}
  local suffix = options.status and string.format(" [%s]", options.status) or (options.filter and string.format(" [%s]", options.filter) or "")

  return string.format(
    "Review Inbox%s - %d hunks | %d attention | %d changed | %d stale",
    suffix,
    counts.total,
    counts.attention,
    counts.changed,
    counts.stale
  )
end

local function default_selection_index(items, focus_fingerprint)
  if not focus_fingerprint or focus_fingerprint == "" then
    return nil
  end

  for index, item in ipairs(items) do
    if item.fingerprint == focus_fingerprint then
      return index
    end
  end

  return nil
end

function M.open(items, callbacks, opts)
  if #vim.api.nvim_list_uis() == 0 then
    vim.notify("Review inbox is not available in headless mode", vim.log.levels.WARN)
    return
  end

  local pickers = telescope_loader.require("telescope.pickers")
  local finders = telescope_loader.require("telescope.finders")
  local previewers = telescope_loader.require("telescope.previewers")
  local config = telescope_loader.require("telescope.config")
  local actions = telescope_loader.require("telescope.actions")
  local action_state = telescope_loader.require("telescope.actions.state")
  local entry_display = telescope_loader.require("telescope.pickers.entry_display")

  if not (pickers and finders and previewers and config and actions and action_state and entry_display) then
    vim.notify("Telescope not available", vim.log.levels.ERROR)
    return
  end

  local options = opts or {}
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 3 },
      { width = 8 },
      { width = 8 },
      { width = 5 },
      { width = 8 },
      { remaining = true },
    },
  })

  local entry_maker = function(item)
    local line = item.line_start or 0
    local status = meta.label(item.status)
    local context = item.hunk_context ~= "" and (" " .. item.hunk_context) or ""
    local has_note = item.note and item.note ~= ""
    local comment_count = item.unresolved_comment_count or 0
    local note_marker = comment_count > 0 and tostring(math.min(comment_count, 9)) or (has_note and "N" or "")
    local note = has_note and (" " .. item.note) or ""
    local location = string.format("%s:%d%s", item.path, line, context)

    return {
      display = function(entry)
        return displayer({
          { attention_marker(entry.value), attention_highlight(entry.value) },
          { scope_label(entry.value), scope_highlight(entry.value) },
          { meta.label(entry.value.status), meta.highlight(entry.value.status) },
          { note_marker, has_note and "Special" or "Comment" },
          { reviewed_label(entry.value), entry.value.changed_since_review and "DiagnosticWarn" or "Comment" },
          { location, entry.value.stale and "Comment" or "Normal" },
        })
      end,
      ordinal = table.concat({ item.attention_reason or "", reviewed_label(item), status, item.path, item.scope, item.hunk_header, context, note }, " "),
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
    default_selection_index = default_selection_index(items, options.focus_fingerprint),
    prompt_title = prompt_title(items, options),
    results_title = "Enter diff | Tab mark | r reviewed | Ctrl-Y accept | ? help",
    preview_title = "Ctrl-A comment | Ctrl-S status | Ctrl-C Claude | Ctrl-P Pi | Ctrl-R refresh",
    finder = finders.new_table({
      results = items,
      entry_maker = entry_maker,
    }),
    layout_strategy = "horizontal",
    layout_config = {
      height = 0.9,
      preview_width = 0.6,
      prompt_position = "top",
      width = 0.96,
    },
    previewer = previewer,
    sorter = config.values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local map_opts = { nowait = true, noremap = true, silent = true }

      local function current_value()
        local entry = action_state.get_selected_entry()
        return entry and entry.value or nil
      end

      local function selected_values()
        local telescope_picker = action_state.get_current_picker(prompt_bufnr)
        local multi = telescope_picker:get_multi_selection()

        if multi and #multi > 0 then
          local values = {}
          for _, entry in ipairs(multi) do
            table.insert(values, entry.value)
          end

          return values
        end

        local value = current_value()
        return value and { value } or {}
      end

      local function with_selection(fn)
        local values = selected_values()
        actions.close(prompt_bufnr)

        if #values > 0 and fn then
          fn(values)
        end
      end

      local function with_current(fn)
        local value = current_value()
        actions.close(prompt_bufnr)

        if value and fn then
          fn(value)
        end
      end

      actions.select_default:replace(function()
        with_current(callbacks.on_select)
      end)

      map("i", "<C-a>", function()
        with_current(callbacks.on_annotate)
      end, vim.tbl_extend("force", map_opts, { desc = "Comment selected review line" }))
      map("n", "<C-a>", function()
        with_current(callbacks.on_annotate)
      end, vim.tbl_extend("force", map_opts, { desc = "Comment selected review line" }))

      map("i", "<C-s>", function()
        with_current(callbacks.on_status)
      end, vim.tbl_extend("force", map_opts, { desc = "Set selected hunk status" }))
      map("n", "<C-s>", function()
        with_current(callbacks.on_status)
      end, vim.tbl_extend("force", map_opts, { desc = "Set selected hunk status" }))

      map("i", "<C-y>", function()
        with_selection(callbacks.on_accept)
      end, vim.tbl_extend("force", map_opts, { desc = "Accept selected hunk(s)" }))
      map("n", "<C-y>", function()
        with_selection(callbacks.on_accept)
      end, vim.tbl_extend("force", map_opts, { desc = "Accept selected hunk(s)" }))

      map("i", "<C-g>", function()
        with_selection(callbacks.on_reviewed)
      end, vim.tbl_extend("force", map_opts, { desc = "Mark selected hunk(s) reviewed" }))
      map("n", "<C-g>", function()
        with_selection(callbacks.on_reviewed)
      end, vim.tbl_extend("force", map_opts, { desc = "Mark selected hunk(s) reviewed" }))
      map("n", "r", function()
        with_selection(callbacks.on_reviewed)
      end, vim.tbl_extend("force", map_opts, { desc = "Mark selected hunk(s) reviewed" }))

      map("i", "<C-c>", function()
        with_selection(callbacks.on_claude)
      end, vim.tbl_extend("force", map_opts, { desc = "Send selected hunk(s) to Claude" }))
      map("n", "<C-c>", function()
        with_selection(callbacks.on_claude)
      end, vim.tbl_extend("force", map_opts, { desc = "Send selected hunk(s) to Claude" }))

      map("i", "<C-p>", function()
        with_selection(callbacks.on_pi)
      end, vim.tbl_extend("force", map_opts, { desc = "Send selected hunk(s) to Pi" }))
      map("n", "<C-p>", function()
        with_selection(callbacks.on_pi)
      end, vim.tbl_extend("force", map_opts, { desc = "Send selected hunk(s) to Pi" }))

      map("i", "<C-r>", function()
        with_selection(callbacks.on_refresh)
      end, vim.tbl_extend("force", map_opts, { desc = "Refresh review inbox" }))
      map("n", "<C-r>", function()
        with_selection(callbacks.on_refresh)
      end, vim.tbl_extend("force", map_opts, { desc = "Refresh review inbox" }))

      map("i", "?", function()
        actions.close(prompt_bufnr)
        if callbacks.on_help then
          callbacks.on_help({
            origin_win = vim.api.nvim_get_current_win(),
            overlay = true,
          })
        end
      end, vim.tbl_extend("force", map_opts, { desc = "Open review inbox help" }))
      map("n", "?", function()
        actions.close(prompt_bufnr)
        if callbacks.on_help then
          callbacks.on_help({
            origin_win = vim.api.nvim_get_current_win(),
            overlay = true,
          })
        end
      end, vim.tbl_extend("force", map_opts, { desc = "Open review inbox help" }))

      return true
    end,
  }):find()
end

return M
