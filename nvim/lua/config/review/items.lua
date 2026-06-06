local diff = require("config.review.diff")
local meta = require("config.review.meta")
local state = require("config.review.state")
local util = require("config.review.util")

local M = {}

local repo_items_cache = {}
local repo_items_cache_ttl = 1000
local review_focus_clear_ttl = 1500
local last_focus_clear_at = 0

function M.clear_cache()
  repo_items_cache = {}
end

local function split_nul(text)
  local items = {}

  for value in tostring(text or ""):gmatch("([^%z]+)%z") do
    table.insert(items, value)
  end

  return items
end

local function can_batch_hash_paths(paths)
  for _, path in ipairs(paths) do
    if path:find("\n", 1, true) then
      return false
    end
  end

  return true
end

local function hash_paths(repo, paths)
  if vim.tbl_isempty(paths) then
    return {}
  end

  if can_batch_hash_paths(paths) then
    local result = vim.system({
      "git",
      "-C",
      repo,
      "hash-object",
      "--stdin-paths",
    }, {
      text = true,
      stdin = table.concat(paths, "\n") .. "\n",
    }):wait()
    if result.code ~= 0 then
      return nil
    end

    local hashes = vim.split(vim.trim(result.stdout or ""), "\n", { plain = true })
    if #hashes ~= #paths then
      return nil
    end

    return hashes
  end

  local hashes = {}
  for _, path in ipairs(paths) do
    local result = vim.system({
      "git",
      "-C",
      repo,
      "hash-object",
      "--",
      path,
    }, { text = true }):wait()
    if result.code ~= 0 then
      return nil
    end

    table.insert(hashes, vim.trim(result.stdout or ""))
  end

  return hashes
end

local function git_output(repo, args)
  local result = vim.system(vim.list_extend({ "git", "-C", repo }, args), { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end

  return result.stdout or ""
end

local function append_signature_part(parts, label, output)
  table.insert(parts, string.format("%d:%s%d:%s", #label, label, #output, output))
end

local function append_hashed_paths(parts, label, paths, hashes)
  for index, path in ipairs(paths) do
    local hash = hashes[index] or ""
    table.insert(parts, string.format("%d:%s%d:%s%d:%s", #label, label, #path, path, #hash, hash))
  end
end

local function unique_sorted(paths)
  local seen = {}
  local unique = {}

  for _, path in ipairs(paths) do
    if path and path ~= "" and not seen[path] then
      seen[path] = true
      table.insert(unique, path)
    end
  end

  table.sort(unique)
  return unique
end

local function content_paths_from_status(status)
  local tokens = split_nul(status)
  local paths = {}
  local index = 1

  while index <= #tokens do
    local entry = tokens[index]
    local code = entry:sub(1, 2)
    local path = entry:sub(4)
    local next_index = index + 1

    if code == "??" then
      table.insert(paths, path)
    elseif #entry >= 4 then
      local index_status = code:sub(1, 1)
      local worktree_status = code:sub(2, 2)

      if index_status == "R" or index_status == "C" or worktree_status == "R" or worktree_status == "C" then
        next_index = index + 2
      end

      if worktree_status ~= " " and worktree_status ~= "D" then
        table.insert(paths, path)
      end
    end

    index = next_index
  end

  return unique_sorted(paths)
end

local function status_has_staged_changes(status)
  local tokens = split_nul(status)
  local index = 1

  while index <= #tokens do
    local entry = tokens[index]
    local code = entry:sub(1, 2)
    local next_index = index + 1

    if code ~= "??" and code ~= "!!" and #entry >= 4 then
      local index_status = code:sub(1, 1)
      local worktree_status = code:sub(2, 2)

      if index_status == "R" or index_status == "C" or worktree_status == "R" or worktree_status == "C" then
        next_index = index + 2
      end

      if index_status ~= " " then
        return true
      end
    end

    index = next_index
  end

  return false
end

function M.repo_change_signature(repo)
  if not repo or repo == "" then
    return nil
  end

  local parts = {}
  local status = git_output(repo, { "status", "--porcelain=v1", "--untracked-files=all", "-z" })
  if not status then
    return nil
  end

  append_signature_part(parts, "status --porcelain=v1 --untracked-files=all -z", status)

  local staged_raw = ""
  if status_has_staged_changes(status) then
    staged_raw = git_output(repo, { "diff", "--cached", "--no-ext-diff", "--raw", "--full-index", "-z" })
    if not staged_raw then
      return nil
    end
  end
  append_signature_part(parts, "diff --cached --raw --full-index -z", staged_raw)

  local content_paths = content_paths_from_status(status)
  local content_hashes = hash_paths(repo, content_paths)
  if not content_hashes then
    return nil
  end
  append_hashed_paths(parts, "content", content_paths, content_hashes)

  return vim.fn.sha256(table.concat(parts, ""))
end

function M.refresh_buffers(repo)
  local normalized_repo = util.normalize(repo)
  local prefix = normalized_repo .. "/"

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local normalized_name = name ~= "" and util.normalize(name) or ""

      if normalized_name == normalized_repo or vim.startswith(normalized_name, prefix) then
        pcall(vim.api.nvim_buf_call, bufnr, function()
          vim.cmd("silent! checktime")
        end)
      end
    end
  end
end

function M.clear_cache_on_focus()
  local now = vim.uv.now()
  if (now - last_focus_clear_at) < review_focus_clear_ttl then
    return
  end

  last_focus_clear_at = now
  M.clear_cache()
end

local function cache_key(context, opts)
  local options = opts or {}
  return table.concat({
    context.repo,
    context.branch,
    options.path or "",
  }, "\0")
end

local function cached(context, opts)
  local key = cache_key(context, opts)
  local cache_entry = repo_items_cache[key]
  if cache_entry and (vim.loop.now() - cache_entry.at) < repo_items_cache_ttl then
    return cache_entry.items
  end

  local items, err = diff.collect_all(context.repo, { path = opts.path })
  if not items then
    return nil, err
  end

  local merged = state.merge_items(context, items)
  repo_items_cache[key] = {
    at = vim.loop.now(),
    items = merged,
  }

  return merged
end

local function filter(items, opts)
  local options = opts or {}
  local filtered = {}
  local target_status = options.status
  local include_stale = options.include_stale ~= false
  local include_resolved_stale = options.include_resolved_stale
  local target_status_nil = target_status == nil

  for _, item in ipairs(items) do
    local status = item.status or "new"
    local is_stale = item.stale

    if not target_status_nil and status ~= target_status then
      goto continue
    end

    if is_stale then
      local surfaced = meta.is_actionable(status)
      if not include_stale then
        if not surfaced then
          goto continue
        end
      elseif not include_resolved_stale and target_status_nil and not surfaced then
        goto continue
      end
    end

    table.insert(filtered, item)
    ::continue::
  end

  return filtered
end

function M.for_context(context, opts)
  local options = opts or {}
  local items, err = cached(context, options)
  if not items then
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end

  return filter(items, options)
end

return M
