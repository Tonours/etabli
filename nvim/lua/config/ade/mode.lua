local M = {}

local uv = vim.uv or vim.loop
local cache_ttl_ms = 1000
local default_mode = "standard"
local modes = { "simple", "standard", "option-compare" }

local cache = {
  cwd = nil,
  checked_at = 0,
  mtime = nil,
  value = nil,
}

local mode_hints = {
  simple = {
    roles = "main + worker",
    review = "end-focused review",
    worktrees = "single worktree",
  },
  standard = {
    roles = "main + scout + worker + reviewer",
    review = "continuous review",
    worktrees = "main worktree",
  },
  ["option-compare"] = {
    roles = "main + 2-3 isolated workers + reviewer",
    review = "compare before keep/discard",
    worktrees = "isolated option worktrees",
  },
}

local function now_ms()
  return uv.now()
end

local function is_valid_mode(mode)
  return vim.tbl_contains(modes, mode)
end

local function sanitize_path(path)
  return path:gsub("[^A-Za-z0-9%._%-]+", "_")
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function state_dir()
  return vim.fn.stdpath("state") .. "/etabli/ade-mode"
end

local function file_path(cwd)
  local normalized = vim.fs.normalize(cwd or vim.fn.getcwd())
  return string.format("%s/%s.json", state_dir(), sanitize_path(normalized))
end

local function file_mtime(path)
  local stat = uv.fs_stat(path)
  if not stat or not stat.mtime then
    return nil
  end

  return string.format("%s:%s", stat.mtime.sec or 0, stat.mtime.nsec or 0)
end

local function warnings_for(mode)
  local warnings = {}
  if mode == default_mode then
    return warnings
  end
  return warnings
end

function M.default_mode()
  return default_mode
end

function M.modes()
  return vim.deepcopy(modes)
end

function M.describe(mode)
  local resolved = is_valid_mode(mode) and mode or default_mode
  local hint = mode_hints[resolved]
  return {
    mode = resolved,
    roles = hint.roles,
    review = hint.review,
    worktrees = hint.worktrees,
  }
end

function M.read(cwd)
  local normalized = vim.fs.normalize(cwd or vim.fn.getcwd())
  local path = file_path(normalized)
  local now = now_ms()
  if cache.cwd == normalized and (now - cache.checked_at) < cache_ttl_ms then
    return cache.value
  end

  cache.cwd = normalized
  cache.checked_at = now

  local mtime = file_mtime(path)
  if not mtime then
    cache.mtime = nil
    cache.value = {
      explicit = false,
      mode = default_mode,
      path = path,
      warnings = {},
      description = M.describe(default_mode),
    }
    return cache.value
  end

  if cache.mtime == mtime and cache.value ~= nil then
    return cache.value
  end

  local ok_read, lines = pcall(vim.fn.readfile, path)
  if not ok_read then
    cache.mtime = nil
    cache.value = {
      explicit = false,
      mode = default_mode,
      path = path,
      warnings = { "Mode file unreadable" },
      description = M.describe(default_mode),
    }
    return cache.value
  end

  local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode or type(decoded) ~= "table" or not is_valid_mode(decoded.mode) then
    cache.mtime = mtime
    cache.value = {
      explicit = false,
      mode = default_mode,
      path = path,
      warnings = { "Mode file invalid; using standard" },
      description = M.describe(default_mode),
    }
    return cache.value
  end

  cache.mtime = mtime
  cache.value = {
    explicit = true,
    mode = decoded.mode,
    path = path,
    warnings = warnings_for(decoded.mode),
    description = M.describe(decoded.mode),
  }
  return cache.value
end

function M.write(cwd, mode)
  if not is_valid_mode(mode) then
    return nil, string.format("Invalid ADE mode: %s", mode)
  end

  local normalized = vim.fs.normalize(cwd or vim.fn.getcwd())
  local path = file_path(normalized)
  ensure_dir(state_dir())
  vim.fn.writefile({ vim.json.encode({ mode = mode }) }, path)

  cache.cwd = nil
  cache.checked_at = 0
  cache.mtime = nil
  cache.value = nil

  return M.read(normalized)
end

function M.clear(cwd)
  local path = file_path(cwd)
  if uv.fs_stat(path) then
    uv.fs_unlink(path)
  end
  cache.cwd = nil
  cache.checked_at = 0
  cache.mtime = nil
  cache.value = nil
end

return M
