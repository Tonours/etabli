local diff = require("config.review.diff")
local meta = require("config.review.meta")
local state_file = require("config.state_file")
local util = require("config.review.util")

local M = {}

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

function M.clear_cache()
  clear_cache()
end

local function context_cache_key(context)
  return table.concat({
    context.repo or "",
    context.branch or "",
  }, "\0")
end

local function sort_items(items)
  table.sort(items, function(left, right)
    if left.stale ~= right.stale then
      return not left.stale
    end

    local left_status = meta.priority(left.status)
    local right_status = meta.priority(right.status)
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

local function legacy_file_path(repo, branch)
  local repo_tail = vim.fn.fnamemodify(repo, ":t")
  local repo_hash = vim.fn.sha256(repo):sub(1, 12)
  local branch_slug = util.sanitize_segment(branch)

  util.ensure_dir(state_dir)

  return string.format("%s/%s__%s__%s.json", state_dir, repo_tail, branch_slug, repo_hash)
end

local function file_path(repo, branch)
  local repo_tail = vim.fn.fnamemodify(repo, ":t")
  local repo_hash = vim.fn.sha256(repo):sub(1, 12)
  local branch_slug = util.sanitize_segment(branch)
  local branch_hash = vim.fn.sha256(branch):sub(1, 12)

  util.ensure_dir(state_dir)

  return string.format("%s/%s__%s__%s__%s.json", state_dir, repo_tail, branch_slug, branch_hash, repo_hash)
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

local function backup_corrupt_record(path)
  local backup = string.format("%s.corrupt.%s.%s", path, os.date("!%Y%m%d-%H%M%S"), vim.uv.hrtime())
  pcall(vim.uv.fs_rename, path, backup)
end

local function read_record(path, repo, branch)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end

  local ok_read, lines = pcall(vim.fn.readfile, path)
  if not ok_read then
    return nil
  end

  local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode then
    backup_corrupt_record(path)
    return nil
  end

  local record = ensure_record_shape(decoded, repo, branch)
  if record.repo ~= repo or record.branch ~= branch then
    return nil
  end

  return record
end

local function normalize_comments(comments)
  if type(comments) ~= "table" then
    return {}
  end

  local normalized = {}
  for index, comment in ipairs(comments) do
    if type(comment) == "table" and type(comment.body) == "string" and comment.body ~= "" then
      local line = tonumber(comment.line or comment.start_line)
      local end_line = tonumber(comment.end_line) or line
      if line and end_line and end_line < line then
        line, end_line = end_line, line
      end

      local fallback_id = vim.fn.sha256(table.concat({
        comment.body,
        tostring(line or ""),
        tostring(end_line or ""),
        tostring(index),
      }, "\n")):sub(1, 12)

      table.insert(normalized, {
        id = comment.id or fallback_id,
        line = line,
        end_line = end_line,
        body = comment.body,
        resolved = comment.resolved == true,
        created_at = comment.created_at,
        updated_at = comment.updated_at,
      })
    end
  end

  return normalized
end

local function comments_for_item(comments, item)
  local normalized = normalize_comments(comments)
  if not item or not item.line_start or not item.line_end then
    return normalized
  end

  local filtered = {}

  for _, comment in ipairs(normalized) do
    if diff.hunk_contains_line(item, comment.line) and diff.hunk_contains_line(item, comment.end_line) then
      table.insert(filtered, comment)
    end
  end

  return filtered
end

local function comment_id_exists(comments, id)
  for _, comment in ipairs(comments) do
    if comment.id == id then
      return true
    end
  end

  return false
end

local function review_anchor(item)
  return table.concat({
    item.scope or "",
    item.path or "",
    item.hunk_header or item.header or "",
  }, "\0")
end

local function review_signature(item)
  return item.patch_hash or item.fingerprint or ""
end

local function unresolved_comment_count(comments)
  local count = 0

  for _, comment in ipairs(comments or {}) do
    if comment.resolved ~= true and comment.body and comment.body ~= "" then
      count = count + 1
    end
  end

  return count
end

local function latest_reviewed_by_anchor(items)
  local reviewed = {}

  for _, item in pairs(items or {}) do
    if item.reviewed == true then
      local anchor = item.review_anchor or review_anchor(item)
      local current = reviewed[anchor]
      if not current or tostring(item.reviewed_at or item.updated_at or "") > tostring(current.reviewed_at or current.updated_at or "") then
        reviewed[anchor] = item
      end
    end
  end

  return reviewed
end

local function decorate_attention(item)
  local status = item.status or "new"
  local unresolved = unresolved_comment_count(item.comments)
  local has_note = item.note and item.note ~= ""

  item.comment_count = #(item.comments or {})
  item.unresolved_comment_count = unresolved

  if item.stale and (meta.is_actionable(status) or unresolved > 0 or has_note) then
    item.attention_reason = "needs-recheck"
    item.attention_label = "RECHECK"
    item.attention_rank = 2
  elseif item.changed_since_review then
    item.attention_reason = "changed-since-review"
    item.attention_label = "CHANGED"
    item.attention_rank = 2
  elseif unresolved > 0 or meta.is_actionable(status) then
    item.attention_reason = "needs-human"
    item.attention_label = "HUMAN"
    item.attention_rank = 1
  elseif status == "new" and item.reviewed ~= true then
    item.attention_reason = "needs-review"
    item.attention_label = "REVIEW"
    item.attention_rank = 3
  elseif status == "new" and item.reviewed == true then
    item.attention_reason = "ready-to-accept"
    item.attention_label = "READY"
    item.attention_rank = 4
  else
    item.attention_reason = "muted"
    item.attention_label = "MUTED"
    item.attention_rank = 99
  end

  return item
end

local function apply_review_state(item, saved, reviewed_by_anchor)
  local signature = review_signature(item)
  local anchor = review_anchor(item)
  local anchor_review = reviewed_by_anchor[anchor]

  item.review_anchor = anchor
  item.review_signature = signature
  item.reviewed = saved and saved.reviewed == true and (saved.reviewed_signature or "") == signature
  item.reviewed_at = saved and saved.reviewed_at or nil
  item.changed_since_review = false

  if saved and saved.reviewed == true and (saved.reviewed_signature or "") ~= "" and saved.reviewed_signature ~= signature then
    item.changed_since_review = true
    item.reviewed = false
    item.previous_reviewed_signature = saved.reviewed_signature
    item.reviewed_at = saved.reviewed_at
  elseif (not saved or saved.reviewed ~= true) and anchor_review and (anchor_review.reviewed_signature or "") ~= "" and anchor_review.reviewed_signature ~= signature then
    item.changed_since_review = true
    item.reviewed = false
    item.previous_reviewed_signature = anchor_review.reviewed_signature
    item.reviewed_at = anchor_review.reviewed_at
  end

  return item
end

function M.statuses()
  return meta.statuses()
end

function M.is_valid_status(status)
  return meta.is_valid_status(status)
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
  local legacy_target = legacy_file_path(context.repo, context.branch)
  local cache_key = context_cache_key(context)

  -- Check cache first
  if is_cache_valid(cache_key) and file_cache[cache_key] then
    return vim.deepcopy(file_cache[cache_key])
  end

  local result = read_record(target, context.repo, context.branch)
  if not result and legacy_target ~= target then
    result = read_record(legacy_target, context.repo, context.branch)
  end
  result = result or ensure_record_shape(nil, context.repo, context.branch)
  set_cache(cache_key, result)
  return result
end

function M.status_counts(context)
  local stored = M.read(context)
  local counts = {}

  for _, status in ipairs(meta.statuses()) do
    counts[status] = 0
  end

  for _, item in pairs(stored.items) do
    local status = item.status or "new"
    if counts[status] ~= nil then
      counts[status] = counts[status] + 1
    end
  end

  counts.total = 0
  for _, status in ipairs(meta.statuses()) do
    counts.total = counts.total + counts[status]
  end

  return counts
end

function M.write(context, data)
  util.ensure_dir(state_dir)
  local target = file_path(context.repo, context.branch)
  local ok_write, write_err = state_file.write_json(target, data)
  if not ok_write then
    return nil, write_err
  end

  local cache_key = context_cache_key(context)
  file_cache[cache_key] = vim.deepcopy(data)
  file_cache_time[cache_key] = vim.loop.now()

  return true
end

function M.clear(context)
  local target = file_path(context.repo, context.branch)
  local legacy_target = legacy_file_path(context.repo, context.branch)
  -- Invalidate cache before deleting
  local cache_key = context_cache_key(context)
  file_cache[cache_key] = nil
  file_cache_time[cache_key] = nil
  if util.path_exists(target) then
    pcall(vim.uv.fs_unlink, target)
  end
  if legacy_target ~= target and read_record(legacy_target, context.repo, context.branch) then
    pcall(vim.uv.fs_unlink, legacy_target)
  end
end

function M.merge_items(context, current_items)
  local stored = M.read(context)
  local merged = {}
  local seen = {}
  local reviewed_by_anchor = latest_reviewed_by_anchor(stored.items)

  for _, item in ipairs(current_items) do
    local saved = stored.items[item.fingerprint]
    local saved_comments = saved and comments_for_item(saved.comments, item) or {}
    local combined = vim.tbl_extend("force", item, {
      branch = context.branch,
      note = saved and saved.note or "",
      comments = saved_comments,
      status = saved and saved.status or "new",
      updated_at = saved and saved.updated_at or nil,
      stale = false,
    })
    apply_review_state(combined, saved, reviewed_by_anchor)
    decorate_attention(combined)

    table.insert(merged, combined)
    seen[item.fingerprint] = true
  end

  for fingerprint, saved in pairs(stored.items) do
    local saved_comments = comments_for_item(saved.comments, saved)
    local has_comment = not vim.tbl_isempty(saved_comments)
    if not seen[fingerprint] and ((saved.note or "") ~= "" or (saved.status or "new") ~= "new" or has_comment) then
      local stale = vim.deepcopy(saved)
      stale.comments = saved_comments
      stale.branch = context.branch
      stale.stale = true
      stale.review_anchor = stale.review_anchor or review_anchor(stale)
      stale.review_signature = stale.review_signature or review_signature(stale)
      stale.changed_since_review = stale.reviewed == true
      decorate_attention(stale)
      table.insert(merged, stale)
    end
  end

  sort_items(merged)

  return merged
end

local function save_item_in_record(context, stored, item, attrs)
  local previous = stored.items[item.fingerprint] or {}
  local note = attrs and attrs.note or previous.note or ""
  local status = attrs and attrs.status or previous.status or "new"
  local comments = attrs and attrs.comments or previous.comments or {}
  local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local reviewed = previous.reviewed == true
  local reviewed_signature = previous.reviewed_signature
  local reviewed_at = previous.reviewed_at

  if attrs and attrs.reviewed ~= nil then
    reviewed = attrs.reviewed == true
    reviewed_signature = reviewed and review_signature(item) or nil
    reviewed_at = reviewed and now or nil
  elseif status == "accepted" then
    reviewed = true
    reviewed_signature = review_signature(item)
    reviewed_at = reviewed_at or now
  end

  if not M.is_valid_status(status) then
    return nil, string.format("Invalid review status: %s", status)
  end

  stored.items[item.fingerprint] = vim.tbl_extend("force", previous, item, {
    repo = context.repo,
    branch = context.branch,
    note = note,
    comments = comments_for_item(comments, item),
    status = status,
    reviewed = reviewed,
    reviewed_at = reviewed_at,
    reviewed_signature = reviewed_signature,
    review_anchor = review_anchor(item),
    review_signature = review_signature(item),
    stale = false,
    updated_at = now,
  })

  local ok_write, write_err = M.write(context, stored)
  if not ok_write then
    return nil, write_err
  end

  return stored.items[item.fingerprint]
end

function M.save_item(context, item, attrs)
  return save_item_in_record(context, M.read(context), item, attrs)
end

function M.set_status(context, item, status)
  return M.save_item(context, item, { status = status })
end

function M.set_note(context, item, note)
  return M.save_item(context, item, { note = note or "" })
end

function M.set_reviewed(context, item, reviewed)
  return M.save_item(context, item, { reviewed = reviewed ~= false })
end

function M.add_comment(context, item, attrs)
  local options = attrs or {}
  local body = vim.trim(options.body or "")
  if body == "" then
    return nil, "Review comment cannot be empty"
  end

  local stored = M.read(context)
  local previous = stored.items[item.fingerprint] or {}
  local comments = normalize_comments(previous.comments)
  local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local line = tonumber(options.line) or item.line_start or 1
  local end_line = tonumber(options.end_line) or line
  if end_line < line then
    line, end_line = end_line, line
  end
  if not diff.hunk_contains_line(item, line) or not diff.hunk_contains_line(item, end_line) then
    return nil, "Review comment range must stay inside this hunk"
  end
  local nonce = 0
  local id

  repeat
    nonce = nonce + 1
    id = vim.fn.sha256(table.concat({
      item.fingerprint or "",
      tostring(line),
      tostring(end_line),
      body,
      now,
      tostring(#comments + nonce),
      tostring(vim.uv.hrtime()),
    }, "\n")):sub(1, 12)
  until not comment_id_exists(comments, id)

  table.insert(comments, {
    id = id,
    line = line,
    end_line = end_line,
    body = body,
    resolved = false,
    created_at = now,
    updated_at = now,
  })

  return save_item_in_record(context, stored, item, { comments = comments })
end

function M.set_comment_resolved(context, item, comment_id, resolved)
  local stored = M.read(context)
  local previous = stored.items[item.fingerprint]
  if not previous then
    return nil, "No review comments found for this hunk"
  end

  local comments = normalize_comments(previous.comments)
  local changed = false
  local now = os.date("!%Y-%m-%dT%H:%M:%SZ")

  for _, comment in ipairs(comments) do
    if comment.id == comment_id then
      comment.resolved = resolved == true
      comment.updated_at = now
      changed = true
      break
    end
  end

  if not changed then
    return nil, "No matching review comment found"
  end

  return save_item_in_record(context, stored, item, { comments = comments })
end

return M
