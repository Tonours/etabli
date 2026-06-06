local diff = require("config.review.diff")
local meta = require("config.review.meta")
local state = require("config.review.state")
local util = require("config.review.util")

local M = {}

local namespace = vim.api.nvim_create_namespace("etabli_review_annotations")
local enabled = true
local refresh_ttl = 750
local last_refresh = {}
local setup_done = false

local markers = {
  ["needs-rework"] = "R",
  question = "?",
  new = "N",
  accepted = "A",
  ignore = "I",
}

local function unresolved_comments(item)
  local comments = {}

  for _, comment in ipairs(item.comments or {}) do
    if comment.resolved ~= true and comment.body and comment.body ~= "" then
      table.insert(comments, comment)
    end
  end

  return comments
end

local function should_render(item)
  local status = item.status or "new"
  local has_note = item.note and item.note ~= ""

  return has_note or meta.is_actionable(status) or #unresolved_comments(item) > 0
end

local function annotation_text(item)
  local status = item.status or "new"
  local parts = { meta.label(status) }

  if item.note and item.note ~= "" then
    local note = vim.trim((item.note:gsub("%s+", " ")))
    if note ~= "" then
      table.insert(parts, note)
    end
  end

  return table.concat(parts, " ")
end

local function has_summary_annotation(item)
  local status = item.status or "new"
  local has_note = item.note and item.note ~= ""

  return has_note or meta.is_actionable(status)
end

local function trim_body_lines(body)
  local lines = vim.split(body or "", "\n", { plain = true })
  local rendered = {}
  local truncated = false

  for index, line in ipairs(lines) do
    local text = vim.trim(line)
    if text ~= "" then
      table.insert(rendered, text)
    end

    if #rendered >= 4 then
      for next_index = index + 1, #lines do
        if vim.trim(lines[next_index]) ~= "" then
          truncated = true
          break
        end
      end
      break
    end
  end

  if truncated then
    table.insert(rendered, "...")
  end

  if vim.tbl_isempty(rendered) then
    return { "(empty comment)" }
  end

  return rendered
end

local function range_label(comment)
  local line = tonumber(comment.line)
  local end_line = tonumber(comment.end_line) or line

  if line and end_line and end_line ~= line then
    return string.format("lines %d-%d", line, end_line)
  end

  return string.format("line %s", line or "?")
end

local function comments_by_line(item)
  local grouped = {}

  for _, comment in ipairs(unresolved_comments(item)) do
    local line = tonumber(comment.end_line or comment.line) or item.line_start or 1
    grouped[line] = grouped[line] or {}
    table.insert(grouped[line], comment)
  end

  return grouped
end

local function comment_virtual_lines(comments)
  local lines = {}

  for index, comment in ipairs(comments) do
    local prefix = string.format("  | review #%s %s", comment.id or "?", range_label(comment))
    if #comments > 1 then
      prefix = string.format("%s (%d/%d)", prefix, index, #comments)
    end

    table.insert(lines, {
      { prefix, "DiagnosticWarn" },
    })

    for _, body_line in ipairs(trim_body_lines(comment.body)) do
      table.insert(lines, {
        { "  | ", "Comment" },
        { body_line, "Normal" },
      })
    end
  end

  return lines
end

local function line_for_item(bufnr, item)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count < 1 then
    return 0
  end

  local line = item.line_start or 1
  if line < 1 then
    line = 1
  elseif line > line_count then
    line = line_count
  end

  return line - 1
end

local function line_index(bufnr, line)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count < 1 then
    return 0
  end

  local target = line or 1
  if target < 1 then
    target = 1
  elseif target > line_count then
    target = line_count
  end

  return target - 1
end

local function context_for_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return nil
  end

  if vim.bo[bufnr].buftype ~= "" then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end

  local context = state.context_for_buffer(bufnr)
  if not context then
    return nil
  end

  return context, name
end

local function render_items(bufnr, items, relative_path)
  for _, item in ipairs(items) do
    if not item.stale and item.path == relative_path and should_render(item) then
      local status = item.status or "new"
      local highlight = meta.highlight(status)
      local text = annotation_text(item)
      local grouped_comments = comments_by_line(item)

      for line, comments in pairs(grouped_comments) do
        vim.api.nvim_buf_set_extmark(bufnr, namespace, line_index(bufnr, line), 0, {
          hl_mode = "combine",
          priority = 130,
          sign_hl_group = "DiagnosticWarn",
          sign_text = "R",
          virt_lines = comment_virtual_lines(comments),
        })
      end

      if has_summary_annotation(item) then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, line_for_item(bufnr, item), 0, {
          hl_mode = "combine",
          priority = 120,
          sign_hl_group = highlight,
          sign_text = markers[status] or "R",
          virt_text = {
            { "  review: ", "Comment" },
            { text, highlight },
          },
          virt_text_pos = "eol",
        })
      end
    end
  end
end

local function repo_buffers(normalized_repo)
  local prefix = normalized_repo .. "/"
  local buffers = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local normalized_name = name ~= "" and util.normalize(name) or ""
      if normalized_name == normalized_repo or vim.startswith(normalized_name, prefix) then
        table.insert(buffers, {
          bufnr = bufnr,
          path = util.relative_path(normalized_repo, name),
        })
      end
    end
  end

  return buffers
end

local function group_items_by_path(items)
  local grouped = {}

  for _, item in ipairs(items) do
    grouped[item.path] = grouped[item.path] or {}
    table.insert(grouped[item.path], item)
  end

  return grouped
end

function M.namespace()
  return namespace
end

function M.is_enabled()
  return enabled
end

function M.clear_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end

function M.refresh_buffer(bufnr, opts)
  bufnr = bufnr or 0
  local options = opts or {}

  if not options.force then
    local now = vim.uv.now()
    local refreshed_at = last_refresh[bufnr] or 0
    if (now - refreshed_at) < refresh_ttl then
      return
    end
    last_refresh[bufnr] = now
  end

  M.clear_buffer(bufnr)

  if not enabled then
    return
  end

  local context, name = context_for_buffer(bufnr)
  if not context then
    return
  end

  local relative_path = util.relative_path(context.repo, name)
  local items = options.merged_items
  if not items then
    local current_items, err = diff.collect_all(context.repo, { path = relative_path })
    if not current_items then
      vim.notify(err, vim.log.levels.WARN)
      return
    end

    items = state.merge_items(context, current_items)
  end

  render_items(bufnr, items, relative_path)
end

function M.refresh_repo(repo)
  if not enabled or not repo or repo == "" then
    return
  end

  local normalized_repo = util.normalize(repo)
  local buffers = repo_buffers(normalized_repo)
  if vim.tbl_isempty(buffers) then
    return
  end

  local function clear_repo_buffer_annotations()
    for _, buffer in ipairs(buffers) do
      M.clear_buffer(buffer.bufnr)
    end
  end

  local context, context_err = state.context_for_repo(normalized_repo)
  if not context then
    clear_repo_buffer_annotations()
    vim.notify(context_err, vim.log.levels.WARN)
    return
  end

  local current_items, err = diff.collect_all(context.repo)
  if not current_items then
    clear_repo_buffer_annotations()
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  local merged_items = state.merge_items(context, current_items)
  local items_by_path = group_items_by_path(merged_items)
  local now = vim.uv.now()

  for _, buffer in ipairs(buffers) do
    last_refresh[buffer.bufnr] = now
    M.clear_buffer(buffer.bufnr)
    render_items(buffer.bufnr, items_by_path[buffer.path] or {}, buffer.path)
  end
end

function M.toggle()
  enabled = not enabled

  if enabled then
    M.refresh_buffer(0, { force = true })
    vim.notify("Review inline annotations enabled", vim.log.levels.INFO)
    return
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    M.clear_buffer(bufnr)
  end
  vim.notify("Review inline annotations disabled", vim.log.levels.INFO)
end

function M.set_enabled(next_enabled)
  enabled = next_enabled == true

  if enabled then
    M.refresh_buffer(0, { force = true })
    return
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    M.clear_buffer(bufnr)
  end
end

function M.setup()
  if setup_done then
    return
  end

  setup_done = true

  local group = vim.api.nvim_create_augroup("etabli_review_annotations", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = group,
    callback = function(event)
      M.refresh_buffer(event.buf, { force = event.event == "BufWritePost" })
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(event)
      last_refresh[event.buf] = nil
    end,
  })
end

return M
