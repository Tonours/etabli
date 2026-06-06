local M = {}

local function ensure_parent(path)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
end

function M.write_lines(path, lines)
  ensure_parent(path)

  local tmp = string.format("%s.tmp.%s.%s", path, vim.fn.getpid(), vim.uv.hrtime())
  local ok_write, write_result = pcall(vim.fn.writefile, lines, tmp)
  if not ok_write or write_result ~= 0 then
    pcall(vim.uv.fs_unlink, tmp)
    return nil, string.format("Failed to write state file: %s", ok_write and write_result or write_result)
  end

  local ok_rename, rename_result, rename_err = pcall(vim.uv.fs_rename, tmp, path)
  if not ok_rename or not rename_result then
    pcall(vim.uv.fs_unlink, tmp)
    return nil, string.format("Failed to replace state file: %s", rename_err or rename_result or "unknown error")
  end

  return true
end

function M.write_json(path, data)
  local ok_encode, payload = pcall(vim.json.encode, data)
  if not ok_encode then
    return nil, string.format("Failed to encode state JSON: %s", payload)
  end

  return M.write_lines(path, { payload })
end

return M
