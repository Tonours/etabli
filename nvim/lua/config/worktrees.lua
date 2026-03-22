local M = {}

local function normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function git_root(path)
  local output = vim.fn.system({ "git", "-C", path, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 then
    return nil
  end

  return normalize(vim.trim(output))
end

function M.entries(path)
  local repo = git_root(path)
  if not repo then
    return {}
  end

  local lines = vim.fn.systemlist({ "git", "-C", repo, "worktree", "list", "--porcelain" })
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local entries = {}
  local current_path = ""
  local current_branch = ""

  local function push_entry()
    if current_path == "" then
      return
    end

    local tail = vim.fn.fnamemodify(current_path, ":t")
    table.insert(entries, {
      branch = current_branch,
      display = (current_branch ~= "" and current_branch or tail) .. " ⇄ " .. current_path,
      ordinal = current_branch .. " " .. tail .. " " .. current_path,
      repo = repo,
      tail = tail,
      value = current_path,
    })
  end

  for _, line in ipairs(lines) do
    if vim.startswith(line, "worktree ") then
      current_path = normalize(line:sub(10))
    elseif vim.startswith(line, "branch refs/heads/") then
      current_branch = line:sub(19)
    elseif line == "" then
      push_entry()
      current_path = ""
      current_branch = ""
    end
  end

  push_entry()
  return entries
end

function M.current(path)
  local current_path = normalize(path or vim.fn.getcwd())

  for _, entry in ipairs(M.entries(current_path)) do
    if current_path == entry.value or vim.startswith(current_path .. "/", entry.value .. "/") then
      return entry
    end
  end

  return nil
end

return M
