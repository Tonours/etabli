local util = require("config.review.util")

local M = {}

function M.comment_range_label(comment)
  local line = tonumber(comment.line)
  local end_line = tonumber(comment.end_line) or line

  if line and end_line and end_line ~= line then
    return string.format("lines %d-%d", line, end_line)
  end

  return string.format("line %s", line or "?")
end

function M.render_item(item)
  local has_note = item.note and item.note ~= ""
  local comments = item.comments or {}
  local lines = {
    "# Review Hunk",
    "",
    string.format("- Repo: %s", item.repo),
    string.format("- Branch: %s", item.branch or "unknown"),
    string.format("- File: %s", item.path),
    string.format("- Scope: %s", item.scope),
    string.format("- Status: %s", item.status or "new"),
    string.format("- Stale: %s", item.stale and "yes" or "no"),
  }

  if has_note then
    table.insert(lines, "- Note:")
    util.append_text_lines(lines, item.note, "  ")
  end

  table.insert(lines, "")
  util.append_fenced_block(lines, "diff", item.patch)

  if #comments > 0 then
    vim.list_extend(lines, { "", "## Review comments" })
    for _, comment in ipairs(comments) do
      table.insert(
        lines,
        string.format(
          "- %s %s [%s]:",
          comment.id or "?",
          M.comment_range_label(comment),
          comment.resolved and "resolved" or "unresolved"
        )
      )
      util.append_text_lines(lines, comment.body or "", "  ")
    end
  end

  return lines
end

local function git_show_lines(repo, spec)
  local result = vim.system({ "git", "-C", repo, "show", spec }, { text = true }):wait()
  if result.code ~= 0 then
    return {}
  end

  local stdout = result.stdout or ""
  if stdout == "" then
    return {}
  end

  return vim.split(stdout, "\n", { plain = true })
end

local function buffer_filetype(path)
  return vim.filetype.match({ filename = path }) or ""
end

local function set_unique_buffer_name(buf, name)
  local safe_name = tostring(name or "")
  if safe_name == "" then
    safe_name = "review"
  end

  if pcall(vim.api.nvim_buf_set_name, buf, safe_name) then
    return
  end

  if pcall(vim.api.nvim_buf_set_name, buf, string.format("%s-%d", safe_name, buf)) then
    return
  end

  for suffix = 1, 1000 do
    if pcall(vim.api.nvim_buf_set_name, buf, string.format("%s-%d", safe_name, suffix)) then
      return
    end
  end

  error(string.format("failed to create a unique review buffer name for %s", safe_name))
end

local function set_scratch_buffer(buf, name, lines, filetype)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.bo[buf].filetype = filetype or ""
  set_unique_buffer_name(buf, name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].readonly = true
end

function M.open_item_diff(item)
  if item.stale then
    vim.notify("This review item is stale, so the live diff no longer exists. Showing the stored patch instead.", vim.log.levels.INFO)
    util.open_scratch("review-stale.md", M.render_item(item), "markdown")
    return
  end

  local absolute_path = item.repo .. "/" .. item.path
  local left_label = item.scope == "staged" and "HEAD" or "INDEX"
  local left_spec = item.scope == "staged" and ("HEAD:" .. item.path) or (":" .. item.path)
  local left_lines = git_show_lines(item.repo, left_spec)
  local filetype = buffer_filetype(item.path)

  vim.cmd.tabnew()

  local left_buf = vim.api.nvim_get_current_buf()
  set_scratch_buffer(left_buf, string.format("review-%s-%s", util.sanitize_segment(left_label:lower()), item.path), left_lines, filetype)

  vim.cmd.vsplit()

  local right_buf = vim.api.nvim_get_current_buf()
  if item.scope == "staged" then
    set_scratch_buffer(
      right_buf,
      string.format("review-index-%s", item.path),
      git_show_lines(item.repo, ":" .. item.path),
      filetype
    )
  elseif vim.fn.filereadable(absolute_path) == 1 then
    vim.cmd.edit(vim.fn.fnameescape(absolute_path))
  else
    set_scratch_buffer(
      right_buf,
      string.format("review-working-%s", item.path),
      {},
      filetype
    )
  end

  vim.wo.wrap = false
  vim.cmd.diffthis()

  vim.cmd.wincmd("h")
  vim.wo.wrap = false
  vim.cmd.diffthis()

  vim.cmd.wincmd("l")
  if item.line_start and item.line_start > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { item.line_start, 0 })
  end
end

return M
