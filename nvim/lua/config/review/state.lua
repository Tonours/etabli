local diff = require("config.review.diff")
local util = require("config.review.util")

local M = {}

local statuses = {
  "new",
  "accepted",
  "needs-rework",
  "question",
  "ignore",
}

local state_dir = vim.fn.stdpath("state") .. "/etabli/review"

-- Cache for file reads to avoid repeated disk access
local file_cache = {}
local file_cache_ttl = 300 -- 300ms TTL for cache (reduced from 500ms)
local file_cache_time = {}

local function is_cache_valid(key)
  local cached_time = file_cache_time[key]
  if not cached_time then
    return false
  end
  return (vim.loop.now() - cached_time) < file_cache_ttl
end

local function set_cache(key, value)
  file_cache[key] = value
  file_cache_time[key] = vim.loop.now()
end

local function clear_cache()
  file_cache = {}
  file_cache_time = {}
end

local function sort_items(items)
  local status_order = {
    ["needs-rework"] = 1,
    question = 2,
    new = 3,
    accepted = 4,
    ignore = 5,
  }

  table.sort(items, function(left, right)
    if left.stale ~= right.stale then
      return not left.stale
    end

    local left_status = status_order[left.status or "new"] or 99
    local right_status = status_order[right.status or "new"] or 99
    if left_status ~= right_status then
      return left_status < right_status
    end

    if left.path == right.path then
      if left.scope == right.scope then
        return (left.line_start or 0) < (right.line_start or 0)
      end

      return left.scope < right.scope
    end

    return left.path < right.path
  end)
end

local function file_path(repo, branch)
  local repo_tail = vim.fn.fnamemodify(repo, ":t")
  local repo_hash = vim.fn.sha256(repo):sub(1, 12)
  local branch_slug = util.sanitize_segment(branch)

  util.ensure_dir(state_dir)

  return string.format("%s/%s__%s__%s.json", state_dir, repo_tail, branch_slug, repo_hash)
end

local function ensure_record_shape(decoded, repo, branch)
  if type(decoded) ~= "table" then
    return {
      version = 1,
      repo = repo,
      branch = branch,
      items = {},
    }
  end

  decoded.version = decoded.version or 1
  decoded.repo = decoded.repo or repo
  decoded.branch = decoded.branch or branch
  decoded.items = type(decoded.items) == "table" and decoded.items or {}

  return decoded
end

function M.statuses()
  return vim.deepcopy(statuses)
end

function M.is_valid_status(status)
  return vim.tbl_contains(statuses, status)
end

function M.context_for_repo(repo)
  local branch, err = diff.branch(repo)
  if not branch then
    return nil, err
  end

  return {
    repo = util.normalize(repo),
    branch = branch,
  }
end

function M.context_for_buffer(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil, "Current buffer has no file path"
  end

  local repo, err = diff.repo_root(name)
  if not repo then
    return nil, err
  end

  return M.context_for_repo(repo)
end

function M.read(context)
  local target = file_path(context.repo, context.branch)
  local cache_key = context.repo .. "#" .. context.branch

  -- Check cache first
  if is_cache_valid(cache_key) and file_cache[cache_key] then
    return vim.deepcopy(file_cache[cache_key])
  end

  if vim.fn.filereadable(target) ~= 1 then
    local result = ensure_record_shape(nil, context.repo, context.branch)
    set_cache(cache_key, result)
    return result
  end

  local ok_read, lines = pcall(vim.fn.readfile, target)
  if not ok_read then
    local result = ensure_record_shape(nil, context.repo, context.branch)
    set_cache(cache_key, result)
    return result
  end

  local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode then
    local result = ensure_record_shape(nil, context.repo, context.branch)
    set_cache(cache_key, result)
    return result
  end

  local result = ensure_record_shape(decoded, context.repo, context.branch)
  set_cache(cache_key, result)
  return result
end

function M.status_counts(context)
  local stored = M.read(context)
  local counts = {}

  for _, status in ipairs(statuses) do
    counts[status] = 0
  end

  for _, item in pairs(stored.items) do
    local status = item.status or "new"
    if counts[status] ~= nil then
      counts[status] = counts[status] + 1
    end
  end

  counts.total = 0
  for _, status in ipairs(statuses) do
    counts.total = counts.total + counts[status]
  end

  return counts
end

function M.write(context, data)
  util.ensure_dir(state_dir)
  local target = file_path(context.repo, context.branch)
  vim.fn.writefile({ vim.json.encode(data) }, target)
  -- Invalidate cache on write
  local cache_key = context.repo .. "#" .. context.branch
  file_cache[cache_key] = nil
  file_cache_time[cache_key] = nil

  local ok, snapshot = pcall(require, "config.ade.snapshot")
  if ok and snapshot and snapshot.schedule_write then
    snapshot.schedule_write(context.repo)
  end
end

function M.clear(context)
  local target = file_path(context.repo, context.branch)
  -- Invalidate cache before deleting
  local cache_key = context.repo .. "#" .. context.branch
  file_cache[cache_key] = nil
  file_cache_time[cache_key] = nil
  if util.path_exists(target) then
    vim.uv.fs_unlink(target)
  end

  local ok, snapshot = pcall(require, "config.ade.snapshot")
  if ok and snapshot and snapshot.schedule_write then
    snapshot.schedule_write(context.repo)
  end
end

function M.merge_items(context, current_items)
  local stored = M.read(context)
  local merged = {}
  local seen = {}

  for _, item in ipairs(current_items) do
    local saved = stored.items[item.fingerprint]
    local combined = vim.tbl_extend("force", item, {
      branch = context.branch,
      note = saved and saved.note or "",
      status = saved and saved.status or "new",
      updated_at = saved and saved.updated_at or nil,
      stale = false,
    })

    table.insert(merged, combined)
    seen[item.fingerprint] = true
  end

  for fingerprint, saved in pairs(stored.items) do
    if not seen[fingerprint] and ((saved.note or "") ~= "" or (saved.status or "new") ~= "new") then
      local stale = vim.deepcopy(saved)
      stale.branch = context.branch
      stale.stale = true
      table.insert(merged, stale)
    end
  end

  sort_items(merged)

  return merged
end

function M.save_item(context, item, attrs)
  local stored = M.read(context)
  local previous = stored.items[item.fingerprint] or {}
  local note = attrs and attrs.note or previous.note or ""
  local status = attrs and attrs.status or previous.status or "new"

  if not M.is_valid_status(status) then
    return nil, string.format("Invalid review status: %s", status)
  end

  stored.items[item.fingerprint] = vim.tbl_extend("force", previous, item, {
    repo = context.repo,
    branch = context.branch,
    note = note,
    status = status,
    stale = false,
    updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  })

  M.write(context, stored)

  return stored.items[item.fingerprint]
end

function M.set_status(context, item, status)
  return M.save_item(context, item, { status = status })
end

function M.set_note(context, item, note)
  return M.save_item(context, item, { note = note or "" })
end

return M
