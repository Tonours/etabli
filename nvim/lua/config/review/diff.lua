local util = require("config.review.util")

local M = {}

local scopes = { "unstaged", "staged" }
local tracked_old_prefix = "etabli-old/"
local tracked_new_prefix = "etabli-new/"
local path_prefix_pairs = {
  { old = tracked_old_prefix, new = tracked_new_prefix },
  { old = "a/", new = "b/" },
}

-- Cache for git root lookups
local git_root_cache = {}
local git_root_cache_time = {}
local git_root_cache_ttl = 20000 -- 20 seconds TTL (reduced from 30s)
local git_root_error_cache = {}
local git_root_error_cache_time = {}
local git_root_error_cache_ttl = 2000 -- short TTL so new git init commands are picked up quickly

-- Cache for diff results (short-lived, cleared on buffer operations)
local diff_cache = {}
local diff_cache_ttl = 500 -- 500ms TTL (reduced from 750ms)
local diff_cache_time = {}

function M.clear_cache()
  diff_cache = {}
  diff_cache_time = {}
end

local function clear_git_root_cache()
  git_root_cache = {}
  git_root_cache_time = {}
  git_root_error_cache = {}
  git_root_error_cache_time = {}
end

-- Clear cache on directory change
vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    clear_git_root_cache()
    M.clear_cache()
  end,
})

-- Clear diff cache on changes that might affect git state
vim.api.nvim_create_autocmd({ "BufWritePost", "BufDelete" }, {
  callback = function()
    M.clear_cache()
  end,
})

vim.api.nvim_create_autocmd("ShellCmdPost", {
  callback = function()
    clear_git_root_cache()
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

local function get_cached_git_root_error(path)
  local cached = git_root_error_cache[path]
  if not cached then
    return nil
  end

  local cached_time = git_root_error_cache_time[path]
  if not cached_time then
    return nil
  end

  if (vim.loop.now() - cached_time) > git_root_error_cache_ttl then
    git_root_error_cache[path] = nil
    git_root_error_cache_time[path] = nil
    return nil
  end

  return cached
end

local function run_git_uncached(root, args, opts)
  local options = opts or {}
  local ok_codes = options.ok_codes or { [0] = true }
  local command = vim.list_extend({ "git", "-C", root, "-c", "core.quotePath=false" }, args)
  local system_opts = { text = true }

  if options.env then
    system_opts.env = options.env
  end

  local result = vim.system(command, system_opts):wait()

  if not ok_codes[result.code] then
    local stderr = vim.trim(result.stderr or "")
    return nil, stderr ~= "" and stderr or "git command failed"
  end

  return result.stdout or "", nil
end

local function run_git(root, args, opts)
  local options = opts or {}
  if options.env or options.cache == false then
    return run_git_uncached(root, args, options)
  end

  local cache_key = root .. "\0" .. table.concat(args, "\0")
  local now = vim.loop.now()

  -- Check cache first
  if diff_cache[cache_key] and (now - (diff_cache_time[cache_key] or 0)) < diff_cache_ttl then
    return diff_cache[cache_key], nil
  end

  local output, err = run_git_uncached(root, args, options)
  if not output then
    return nil, err
  end

  -- Cache the result
  diff_cache[cache_key] = output
  diff_cache_time[cache_key] = now

  return output, nil
end

local function nul_split(text)
  local items = {}

  for value in tostring(text or ""):gmatch("([^%z]+)%z") do
    table.insert(items, value)
  end

  return items
end

local function path_chunks(paths)
  local chunks = {}
  local current = {}
  local current_bytes = 0
  local max_paths = 128
  local max_bytes = 24000

  for _, path in ipairs(paths) do
    local path_bytes = #path + 1
    if #current > 0 and (#current >= max_paths or current_bytes + path_bytes > max_bytes) then
      table.insert(chunks, current)
      current = {}
      current_bytes = 0
    end

    table.insert(current, path)
    current_bytes = current_bytes + path_bytes
  end

  if #current > 0 then
    table.insert(chunks, current)
  end

  return chunks
end

local function sort_items(items)
  table.sort(items, function(left, right)
    if left.path == right.path then
      if left.scope == right.scope then
        return left.line_start < right.line_start
      end

      return left.scope < right.scope
    end

    return left.path < right.path
  end)
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

local function unquote_git_path(raw)
  if not raw:match('^".*"$') then
    return raw
  end

  local escapes = {
    a = "\a",
    b = "\b",
    f = "\f",
    n = "\n",
    r = "\r",
    t = "\t",
    v = "\v",
    ['"'] = '"',
    ["\\"] = "\\",
  }

  local body = raw:sub(2, -2)
  body = body:gsub("\\([0-7][0-7][0-7])", function(value)
    return string.char(tonumber(value, 8))
  end)

  return body:gsub("\\(.)", function(value)
    return escapes[value] or value
  end)
end

local function strip_file_marker_prefix(path, prefixes)
  local candidates = vim.islist(prefixes) and prefixes or { prefixes }

  for _, prefix in ipairs(candidates) do
    if vim.startswith(path, prefix) then
      return path:sub(#prefix + 1)
    end
  end

  return path
end

local function parse_file_marker_path(raw, prefixes)
  local path = raw:match("^(.-)\t") or raw
  path = unquote_git_path(path)

  if path == "/dev/null" then
    return path
  end

  return strip_file_marker_prefix(path, prefixes)
end

local function split_diff_git_body(body, delimiter)
  local fallback_old
  local fallback_new
  local start = 1

  while true do
    local delimiter_at = body:find(delimiter, start, true)
    if not delimiter_at then
      break
    end

    local old_path = body:sub(1, delimiter_at - 1)
    local new_path = body:sub(delimiter_at + #delimiter)
    if not fallback_old then
      fallback_old = old_path
      fallback_new = new_path
    end

    if old_path == new_path then
      return old_path, new_path
    end

    start = delimiter_at + 1
  end

  return fallback_old, fallback_new
end

local function parse_diff_git_paths(line)
  for _, prefixes in ipairs(path_prefix_pairs) do
    local line_prefix = "diff --git " .. prefixes.old
    local delimiter = " " .. prefixes.new

    if vim.startswith(line, line_prefix) then
      local body = line:sub(#line_prefix + 1)
      return split_diff_git_body(body, delimiter)
    end
  end

  local old_raw, new_raw = line:match('^diff %-%-git%s+(".*")%s+(".*")$')
  if old_raw and new_raw then
    return parse_file_marker_path(old_raw, { tracked_old_prefix, "a/" }),
      parse_file_marker_path(new_raw, { tracked_new_prefix, "b/" })
  end

  return nil, nil
end

local function patch_hash_for(scope, path, body)
  local patch_key = scope .. "\n" .. path .. "\n" .. body
  return vim.fn.sha256(patch_key):sub(1, 16)
end

local function file_header_label(file_state)
  for index = 2, #(file_state.header_lines or {}) do
    local line = file_state.header_lines[index]
    if line and line ~= "" then
      return line
    end
  end

  return "file metadata"
end

local function file_state_has_header(file_state, prefix)
  for _, line in ipairs(file_state.header_lines or {}) do
    if vim.startswith(line, prefix) then
      return true
    end
  end

  return false
end

local function changed_line_range_for_hunk(hunk_state)
  local new_line = hunk_state.new_start
  local changed_start
  local changed_end

  for index, line in ipairs(hunk_state.lines or {}) do
    if index > 1 then
      local prefix = line:sub(1, 1)
      if prefix == "+" then
        changed_start = changed_start or new_line
        changed_end = new_line
        new_line = new_line + 1
      elseif prefix == " " then
        new_line = new_line + 1
      end
    end
  end

  return changed_start or hunk_state.new_start, changed_end or changed_start or hunk_state.new_start
end

local function finalize_hunk(root, scope, file_state, hunk_state, items)
  if not file_state or not hunk_state then
    return false
  end

  local path = file_state.new_path ~= "/dev/null" and file_state.new_path or file_state.old_path
  local hunk_patch = table.concat(hunk_state.lines, "\n")

  -- Pre-allocate patch_lines table for better performance
  local patch_lines = vim.deepcopy(file_state.header_lines)
  vim.list_extend(patch_lines, hunk_state.lines)
  local patch = table.concat(patch_lines, "\n")
  local patch_hash = patch_hash_for(scope, path, hunk_patch)

  local line_start = hunk_state.new_start
  local line_end = hunk_state.new_count > 0 and (hunk_state.new_start + hunk_state.new_count - 1) or hunk_state.new_start
  local changed_line_start, changed_line_end = changed_line_range_for_hunk(hunk_state)

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
    changed_line_start = changed_line_start,
    changed_line_end = changed_line_end,
    line_start = line_start,
    line_end = line_end,
    added = file_state.old_path == "/dev/null",
    deleted = file_state.new_path == "/dev/null",
  })

  return true
end

local function finalize_file_metadata(root, scope, file_state, items)
  if not file_state or file_state.has_hunk then
    return
  end

  local added = file_state.old_path == "/dev/null" or file_state_has_header(file_state, "new file mode")
  local deleted = file_state.new_path == "/dev/null" or file_state_has_header(file_state, "deleted file mode")
  local old_path = added and "/dev/null" or file_state.old_path
  local new_path = deleted and "/dev/null" or file_state.new_path
  local path = new_path ~= "/dev/null" and new_path or old_path

  if not path or path == "" or path == "/dev/null" then
    return
  end

  local patch = table.concat(file_state.header_lines, "\n")
  local header = file_header_label(file_state)
  local patch_hash = patch_hash_for(scope, path, patch)

  table.insert(items, {
    repo = util.normalize(root),
    scope = scope,
    path = path,
    old_path = old_path,
    new_path = new_path,
    header = header,
    hunk_header = header,
    hunk_context = "",
    patch = patch,
    hunk_patch = patch,
    patch_hash = patch_hash,
    fingerprint = scope .. "\0" .. path .. "\0" .. header .. "\0" .. patch_hash,
    old_start = 1,
    old_count = 0,
    new_start = 1,
    new_count = 0,
    line_start = 1,
    line_end = 1,
    added = added,
    deleted = deleted,
  })
end

local function parse_diff(root, scope, text)
  local items = {}
  local current_file
  local current_hunk

  local function flush_hunk()
    if finalize_hunk(root, scope, current_file, current_hunk, items) and current_file then
      current_file.has_hunk = true
    end
    current_hunk = nil
  end

  local function flush_file()
    flush_hunk()
    finalize_file_metadata(root, scope, current_file, items)
    current_file = nil
  end

  for line in (text .. "\n"):gmatch("(.-)\n") do
    if vim.startswith(line, "diff --git ") then
      flush_file()

      local old_path, new_path = parse_diff_git_paths(line)
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
            current_file.old_path = parse_file_marker_path(line:sub(5), { tracked_old_prefix, "a/" })
          elseif vim.startswith(line, "+++ ") then
            current_file.new_path = parse_file_marker_path(line:sub(5), { tracked_new_prefix, "b/" })
          end
        end
      end
    end
  end

  flush_file()

  sort_items(items)

  return items
end

local function collect_untracked(root, opts)
  local options = opts or {}
  local args = { "ls-files", "--others", "--exclude-standard", "-z" }

  if options.path and options.path ~= "" then
    table.insert(args, "--")
    table.insert(args, options.path)
  end

  local stdout, err = run_git(root, args)
  if not stdout then
    return nil, err
  end

  local paths = nul_split(stdout)
  local items = {}

  if #paths == 0 then
    return items
  end

  local index_path = vim.fn.tempname()
  local env = { GIT_INDEX_FILE = index_path }
  local has_head = run_git_uncached(root, { "rev-parse", "--verify", "HEAD" }, { env = env }) ~= nil
  local read_tree_args = has_head and { "read-tree", "HEAD" } or { "read-tree", "--empty" }
  local _, read_tree_err = run_git_uncached(root, read_tree_args, { env = env })

  if read_tree_err then
    vim.fn.delete(index_path)
    vim.fn.delete(index_path .. ".lock")
    return nil, read_tree_err
  end

  for _, chunk in ipairs(path_chunks(paths)) do
    local add_args = { "add", "-N", "--" }
    vim.list_extend(add_args, chunk)

    local _, add_err = run_git_uncached(root, add_args, { env = env })
    if add_err then
      vim.fn.delete(index_path)
      vim.fn.delete(index_path .. ".lock")
      return nil, add_err
    end
  end

  for _, chunk in ipairs(path_chunks(paths)) do
    local diff_args = {
      "diff",
      "--no-ext-diff",
      "--no-color",
      "--no-renames",
      "--unified=3",
      "--relative",
      "--src-prefix=" .. tracked_old_prefix,
      "--dst-prefix=" .. tracked_new_prefix,
      "--",
    }
    vim.list_extend(diff_args, chunk)

    local patch, patch_err = run_git_uncached(root, diff_args, { env = env })
    if not patch then
      vim.fn.delete(index_path)
      vim.fn.delete(index_path .. ".lock")
      return nil, patch_err
    end

    vim.list_extend(items, parse_diff(root, "unstaged", patch))
  end

  vim.fn.delete(index_path)
  vim.fn.delete(index_path .. ".lock")
  sort_items(items)
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

  local cached_error = get_cached_git_root_error(start)
  if cached_error then
    return nil, cached_error
  end

  local result = vim.system({ "git", "-C", start, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if result.code ~= 0 then
    local stderr = vim.trim(result.stderr or "")
    local err = stderr ~= "" and stderr or "Not inside a git repository"
    git_root_error_cache[start] = err
    git_root_error_cache_time[start] = vim.loop.now()
    return nil, err
  end

  local root = util.normalize(vim.trim(result.stdout or ""))
  git_root_cache[start] = root
  git_root_cache_time[start] = vim.loop.now()
  git_root_error_cache[start] = nil
  git_root_error_cache_time[start] = nil
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
  local args = {
    "diff",
    "--no-ext-diff",
    "--no-color",
    "--no-renames",
    "--unified=3",
    "--relative",
    "--src-prefix=" .. tracked_old_prefix,
    "--dst-prefix=" .. tracked_new_prefix,
  }
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

  local items = parse_diff(root, scope, stdout)
  if scope == "unstaged" then
    local untracked, untracked_err = collect_untracked(root, options)
    if not untracked then
      return nil, untracked_err
    end

    vim.list_extend(items, untracked)
    sort_items(items)
  end

  return items
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

  sort_items(items)

  return items
end

function M.hunk_contains_line(item, line)
  if item.deleted then
    return line == item.line_start
  end

  return line >= item.line_start and line <= item.line_end
end

return M
