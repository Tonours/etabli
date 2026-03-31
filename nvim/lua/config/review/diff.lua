local util = require("config.review.util")

local M = {}

local scopes = { "unstaged", "staged" }

-- Cache for git root lookups (mirrors worktrees.lua optimization)
local git_root_cache = {}
local git_root_cache_time = {}
local git_root_cache_ttl = 20000 -- 20 seconds TTL (reduced from 30s)

-- Cache for diff results (short-lived, cleared on buffer operations)
local diff_cache = {}
local diff_cache_ttl = 500 -- 500ms TTL (reduced from 750ms)
local diff_cache_time = {}

function M.clear_cache()
  diff_cache = {}
  diff_cache_time = {}
end

-- Clear cache on directory change
vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    git_root_cache = {}
    git_root_cache_time = {}
    M.clear_cache()
  end,
})

-- Clear diff cache on buffer changes that might affect git state
vim.api.nvim_create_autocmd({ "BufWritePost", "BufDelete" }, {
  callback = function()
    M.clear_cache()
  end,
})

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

local function run_git(root, args)
  local cache_key = root .. "#" .. table.concat(args, "#")
  local now = vim.loop.now()

  -- Check cache first
  if diff_cache[cache_key] and (now - (diff_cache_time[cache_key] or 0)) < diff_cache_ttl then
    return diff_cache[cache_key], nil
  end

  local command = vim.list_extend({ "git", "-C", root }, args)
  local result = vim.system(command, { text = true }):wait()

  if result.code ~= 0 then
    local stderr = vim.trim(result.stderr or "")
    return nil, stderr ~= "" and stderr or "git command failed"
  end

  local output = result.stdout or ""
  -- Cache the result
  diff_cache[cache_key] = output
  diff_cache_time[cache_key] = now

  return output, nil
end

local function parse_range(spec)
  local start, count = spec:match("^(%d+),(%d+)$")
  if start then
    return tonumber(start), tonumber(count)
  end

  start = spec:match("^(%d+)$")
  return tonumber(start), 1
end

local function parse_hunk_header(line)
  local old_spec, new_spec, context = line:match("^@@%s+%-(%d+[,%d]*)%s+%+(%d+[,%d]*)%s+@@(.*)$")
  if not old_spec or not new_spec then
    return nil
  end

  local old_start, old_count = parse_range(old_spec)
  local new_start, new_count = parse_range(new_spec)

  return {
    header_line = line,
    header_context = vim.trim(context or ""),
    old_start = old_start,
    old_count = old_count,
    new_start = new_start,
    new_count = new_count,
  }
end

local function finalize_hunk(root, scope, file_state, hunk_state, items)
  if not file_state or not hunk_state then
    return
  end

  local path = file_state.new_path ~= "/dev/null" and file_state.new_path or file_state.old_path
  local hunk_patch = table.concat(hunk_state.lines, "\n")

  -- Pre-allocate patch_lines table for better performance
  local patch_lines = vim.deepcopy(file_state.header_lines)
  vim.list_extend(patch_lines, hunk_state.lines)
  local patch = table.concat(patch_lines, "\n")

  local patch_key = scope .. "\n" .. path .. "\n" .. hunk_patch
  local patch_hash
  if #patch_key < 1000 then
    local hash = 0
    for i = 1, #patch_key do
      hash = ((hash * 31) + patch_key:byte(i)) % 2147483647
    end
    patch_hash = string.format("%08x", hash)
  else
    patch_hash = vim.fn.sha256(patch_key):sub(1, 16)
  end

  local line_start = hunk_state.new_start
  local line_end = hunk_state.new_count > 0 and (hunk_state.new_start + hunk_state.new_count - 1) or hunk_state.new_start

  table.insert(items, {
    repo = util.normalize(root),
    scope = scope,
    path = path,
    old_path = file_state.old_path,
    new_path = file_state.new_path,
    header = hunk_state.header_line,
    hunk_header = hunk_state.header_line,
    hunk_context = hunk_state.header_context,
    patch = patch,
    hunk_patch = hunk_patch,
    patch_hash = patch_hash,
    fingerprint = scope .. "\0" .. path .. "\0" .. hunk_state.header_line .. "\0" .. patch_hash,
    old_start = hunk_state.old_start,
    old_count = hunk_state.old_count,
    new_start = hunk_state.new_start,
    new_count = hunk_state.new_count,
    line_start = line_start,
    line_end = line_end,
    added = file_state.old_path == "/dev/null",
    deleted = file_state.new_path == "/dev/null",
  })
end

local function parse_diff(root, scope, text)
  local items = {}
  local current_file
  local current_hunk

  local function flush_hunk()
    finalize_hunk(root, scope, current_file, current_hunk, items)
    current_hunk = nil
  end

  local function flush_file()
    flush_hunk()
    current_file = nil
  end

  for line in (text .. "\n"):gmatch("(.-)\n") do
    if vim.startswith(line, "diff --git ") then
      flush_file()

      local old_path, new_path = line:match("^diff %-%-git a/(.-) b/(.-)$")
      current_file = {
        old_path = old_path,
        new_path = new_path,
        header_lines = { line },
      }
    elseif current_file then
      if vim.startswith(line, "@@ ") then
        flush_hunk()

        current_hunk = parse_hunk_header(line)
        if current_hunk then
          current_hunk.lines = { line }
        end
      else
        if current_hunk then
          table.insert(current_hunk.lines, line)
        else
          table.insert(current_file.header_lines, line)

          if vim.startswith(line, "--- ") then
            local old_path = line:sub(5)
            current_file.old_path = old_path == "/dev/null" and old_path or old_path:gsub("^a/", "")
          elseif vim.startswith(line, "+++ ") then
            local new_path = line:sub(5)
            current_file.new_path = new_path == "/dev/null" and new_path or new_path:gsub("^b/", "")
          end
        end
      end
    end
  end

  flush_file()

  table.sort(items, function(left, right)
    if left.path == right.path then
      if left.scope == right.scope then
        return left.line_start < right.line_start
      end

      return left.scope < right.scope
    end

    return left.path < right.path
  end)

  return items
end

function M.scopes()
  return vim.deepcopy(scopes)
end

function M.repo_root(path)
  local target = path ~= "" and path or vim.fn.getcwd()
  local start = target

  if vim.fn.filereadable(target) == 1 then
    start = vim.fs.dirname(target)
  end

  -- Use cache if available (optimization: avoid repeated git calls)
  local cached = get_cached_git_root(start)
  if cached then
    return cached
  end

  local result = vim.system({ "git", "-C", start, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if result.code ~= 0 then
    local stderr = vim.trim(result.stderr or "")
    return nil, stderr ~= "" and stderr or "Not inside a git repository"
  end

  local root = util.normalize(vim.trim(result.stdout or ""))
  git_root_cache[start] = root
  git_root_cache_time[start] = vim.loop.now()
  return root
end

function M.branch(root)
  local stdout = run_git(root, { "symbolic-ref", "--quiet", "--short", "HEAD" })
  if stdout then
    return vim.trim(stdout)
  end

  local detached, err = run_git(root, { "rev-parse", "--short", "HEAD" })
  if not detached then
    return nil, err
  end

  return vim.trim(detached)
end

function M.collect_scope(root, scope, opts)
  local args = { "diff", "--no-ext-diff", "--no-color", "--no-renames", "--unified=3", "--relative" }
  local options = opts or {}

  if scope == "staged" then
    table.insert(args, "--cached")
  elseif scope ~= "unstaged" then
    return nil, string.format("Unsupported review scope: %s", scope)
  end

  if options.path and options.path ~= "" then
    table.insert(args, "--")
    table.insert(args, options.path)
  end

  local stdout, err = run_git(root, args)
  if not stdout then
    return nil, err
  end

  return parse_diff(root, scope, stdout)
end

function M.collect_all(root, opts)
  local items = {}

  for _, scope in ipairs(scopes) do
    local scoped, err = M.collect_scope(root, scope, opts)
    if not scoped then
      return nil, err
    end

    vim.list_extend(items, scoped)
  end

  table.sort(items, function(left, right)
    if left.path == right.path then
      if left.scope == right.scope then
        return left.line_start < right.line_start
      end

      return left.scope < right.scope
    end

    return left.path < right.path
  end)

  return items
end

function M.hunk_contains_line(item, line)
  if item.deleted then
    return line == item.line_start
  end

  return line >= item.line_start and line <= item.line_end
end

return M
