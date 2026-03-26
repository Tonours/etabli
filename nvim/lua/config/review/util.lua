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

function M.copy_to_registers(text)
  vim.fn.setreg('"', text)
  pcall(vim.fn.setreg, "+", text)
end

return M
