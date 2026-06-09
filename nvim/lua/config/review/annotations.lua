local diff = require("config.review.diff")
local meta = require("config.review.meta")
local review_items = require("config.review.items")
local state = require("config.review.state")
local util = require("config.review.util")

local M = {}

local namespace = vim.api.nvim_create_namespace("etabli_review_annotations")
local function is_truthy_flag(value)
  return value == true or value == 1 or value == "1" or value == "true"
end

local enabled = is_truthy_flag(vim.g.etabli_review_legacy_annotations)
local refresh_ttl = 750
local last_refresh = {}
local expanded_line_by_buffer = {}
local setup_done = false

local function normalize_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end

  return bufnr
end

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

  for _, comment in ipairs(item.draft_comments or {}) do
    if comment.body and comment.body ~= "" then
      local draft = vim.deepcopy(comment)
      draft.draft = true
      table.insert(comments, draft)
    end
  end

  for _, finding in ipairs(item.agent_findings or {}) do
    if
      (finding.status == nil or finding.status == "open")
      and finding.review_comment
      and finding.review_comment ~= ""
    then
      table.insert(comments, {
        id = finding.id,
        line = finding.line,
        end_line = finding.end_line,
        body = string.format("%s/%s: %s", finding.provider or "agent", finding.severity or "low", finding.review_comment),
        agent = true,
      })
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
    local kind = "comment"
    if comment.agent == true then
      kind = "agent"
    elseif comment.draft == true then
      kind = "draft"
    end
    local prefix = string.format("  | %s #%s %s", kind, comment.id or "?", range_label(comment))
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

local function compact_comment_text(comments)
  local count = #comments
  local draft_count = 0
  local agent_count = 0
  for _, comment in ipairs(comments) do
    if comment.draft == true then
      draft_count = draft_count + 1
    elseif comment.agent == true then
      agent_count = agent_count + 1
    end
  end

  local human_count = count - draft_count - agent_count
  local labels = {}
  if human_count > 0 then
    table.insert(labels, human_count == 1 and "1 comment" or string.format("%d comments", human_count))
  end
  if draft_count > 0 then
    table.insert(labels, draft_count == 1 and "1 draft" or string.format("%d drafts", draft_count))
  end
  if agent_count > 0 then
    table.insert(labels, agent_count == 1 and "1 agent" or string.format("%d agents", agent_count))
  end
  local first = comments[1]
  local range = first and range_label(first) or "line ?"

  return string.format("thread %s at %s | <leader>ro", table.concat(labels, ", "), range)
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
  local expanded_line = expanded_line_by_buffer[bufnr]

  for _, item in ipairs(items) do
    if not item.stale and item.path == relative_path and should_render(item) then
      local status = item.status or "new"
      local highlight = meta.highlight(status)
      local text = annotation_text(item)
      local grouped_comments = comments_by_line(item)

      for line, comments in pairs(grouped_comments) do
        local row = line_index(bufnr, line)
        local extmark = {
          hl_mode = "combine",
          priority = 130,
          sign_hl_group = "DiagnosticWarn",
          sign_text = "R",
        }

        if expanded_line == line then
          extmark.virt_lines = comment_virtual_lines(comments)
        else
          extmark.virt_text = {
            { "  review: ", "Comment" },
            { compact_comment_text(comments), "DiagnosticWarn" },
          }
          extmark.virt_text_pos = "eol"
        end

        vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, extmark)
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
  bufnr = normalize_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end

function M.expand_current_thread(bufnr)
  bufnr = normalize_bufnr(bufnr)
  local target = vim.api.nvim_win_get_cursor(0)[1]

  if expanded_line_by_buffer[bufnr] == target then
    expanded_line_by_buffer[bufnr] = nil
  else
    expanded_line_by_buffer[bufnr] = target
  end

  M.refresh_buffer(bufnr, { force = true })
end

function M.compact_buffer(bufnr)
  bufnr = normalize_bufnr(bufnr)
  expanded_line_by_buffer[bufnr] = nil
  M.refresh_buffer(bufnr, { force = true })
end

function M.refresh_buffer(bufnr, opts)
  bufnr = normalize_bufnr(bufnr)
  local options = opts or {}

  if not enabled then
    return
  end

  local now = vim.uv.now()

  if not options.force then
    local refreshed_at = last_refresh[bufnr] or 0
    if (now - refreshed_at) < refresh_ttl then
      return
    end
  end
  last_refresh[bufnr] = now

  M.clear_buffer(bufnr)

  local context, name = context_for_buffer(bufnr)
  if not context then
    return
  end

  local relative_path = util.relative_path(context.repo, name)
  local items = options.merged_items
  if not items then
    local err
    items, err = review_items.for_context(context, {
      include_stale = false,
      path = relative_path,
    })
    if not items then
      vim.notify(err, vim.log.levels.WARN)
      return
    end
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
    expanded_line_by_buffer[bufnr] = nil
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
    expanded_line_by_buffer[bufnr] = nil
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
      expanded_line_by_buffer[event.buf] = nil
    end,
  })
end

return M
