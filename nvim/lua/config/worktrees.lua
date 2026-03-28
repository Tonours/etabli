local M = {}

-- Cache for git root lookups with TTL
local git_root_cache = {}
local git_root_cache_time = {}
local git_root_cache_ttl = 5000 -- 5 seconds TTL (reduced from 10s)

local function normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

-- Fast path: check cache with TTL
local function get_cached_git_root(path)
  local cached = git_root_cache[path]
  if not cached then
    return nil
  end

  local cached_time = git_root_cache_time[path]
  if not cached_time then
    return nil
  end

  -- Check if cache is still valid
  if (vim.loop.now() - cached_time) > git_root_cache_ttl then
    git_root_cache[path] = nil
    git_root_cache_time[path] = nil
    return nil
  end

  return cached
end

local function git_root(path)
  -- Fast path: check cache first
  local cached = get_cached_git_root(path)
  if cached then
    return cached
  end

  local output = vim.fn.system({ "git", "-C", path, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 then
    return nil
  end

  local result = normalize(vim.trim(output))
  git_root_cache[path] = result
  git_root_cache_time[path] = vim.loop.now()
  return result
end

-- Clear git root cache on directory change
vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    git_root_cache = {}
    git_root_cache_time = {}
  end,
})

local worktree_cache = {}
local worktree_cache_time = {}
local worktree_cache_ttl = 2000 -- 2 seconds default TTL (reduced from 3s)

function M.entries(path)
  local now = vim.loop.now()
  local repo = git_root(path)
  if not repo then
    return {}
  end

  -- Use cache if valid for this specific repo
  local repo_cache_time = worktree_cache_time[repo]
  if worktree_cache[repo] and repo_cache_time and (now - repo_cache_time) < worktree_cache_ttl then
    return worktree_cache[repo]
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

  -- Update cache for this specific repo
  worktree_cache[repo] = entries
  worktree_cache_time[repo] = now

  return entries
end

function M.clear_cache()
  worktree_cache = {}
  worktree_cache_time = {}
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

-- Clear cache on directory change
vim.api.nvim_create_autocmd("DirChanged", {
  callback = M.clear_cache,
})

return M
