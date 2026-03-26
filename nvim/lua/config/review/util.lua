local M = {}

function M.normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

function M.relative_path(root, path)
  local normalized_root = M.normalize(root)
  local normalized_path = M.normalize(path)
  local prefix = normalized_root .. "/"

  if normalized_path == normalized_root then
    return "."
  end

  if vim.startswith(normalized_path, prefix) then
    return normalized_path:sub(#prefix + 1)
  end

  return normalized_path
end

function M.ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

function M.path_exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

function M.sanitize_segment(value)
  return tostring(value):gsub("[^%w%-_.]", "_")
end

function M.open_scratch(title, lines, filetype)
  vim.cmd.tabnew()

  local buf = vim.api.nvim_get_current_buf()
  local safe_title = title ~= "" and title or "review"
  local buffer_name = string.format("%s-%d", safe_title, buf)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = filetype or "markdown"

  vim.api.nvim_buf_set_name(buf, buffer_name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  return buf
end

function M.open_overlay(title, lines, opts)
  local options = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  local max_line = 0

  for _, line in ipairs(lines) do
    max_line = math.max(max_line, vim.fn.strdisplaywidth(line))
  end

  local width = math.min(math.max(max_line + 4, 60), math.floor(vim.o.columns * 0.72))
  local height = math.min(math.max(#lines, 1) + 2, math.floor(vim.o.lines * 0.7))
  local row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = options.filetype or "markdown"

  vim.api.nvim_buf_set_name(buf, string.format("%s-overlay-%d", title ~= "" and title or "review", buf))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  local win = vim.api.nvim_open_win(buf, true, {
    border = "rounded",
    col = col,
    height = height,
    relative = "editor",
    row = row,
    style = "minimal",
    title = title,
    title_pos = "center",
    width = width,
    zindex = 90,
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end

    if options.origin_win and vim.api.nvim_win_is_valid(options.origin_win) then
      pcall(vim.api.nvim_set_current_win, options.origin_win)
    end

    if options.on_close then
      options.on_close()
    end
  end

  for _, key in ipairs({ "q", "<Esc>", "?", "<CR>" }) do
    vim.keymap.set("n", key, close, { buffer = buf, nowait = true, silent = true })
  end

  return buf, win
end

function M.copy_to_registers(text)
  vim.fn.setreg('"', text)
  pcall(vim.fn.setreg, "+", text)
end

return M
