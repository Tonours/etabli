local projects = require("config.projects")
local review_util = require("config.review.util")

local M = {}

local valid_status = {
  idle = true,
  running = true,
  inactive = true,
  error = true,
}

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%S.000Z")
end

local function next_id()
  local uv = vim.uv or vim.loop
  return string.format("thread-%d", uv.hrtime())
end

local function normalize_id(value)
  if type(value) == "string" and value ~= "" then
    return value
  end
  if type(value) == "number" then
    return tostring(value)
  end
  return nil
end

local function normalize_status(value)
  if type(value) == "string" and valid_status[value] then
    return value
  end
  return "idle"
end

local function ensure_bucket(store, root_key)
  local bucket = store[root_key]
  if type(bucket) ~= "table" then
    bucket = {}
    store[root_key] = bucket
  end
  if type(bucket.threads) ~= "table" then
    bucket.threads = {}
  end
  bucket.activeThreadId = normalize_id(bucket.activeThreadId)
  return bucket
end

local function normalize_thread(raw, root_key)
  if type(raw) ~= "table" then
    return nil
  end

  local provider = type(raw.provider) == "string" and raw.provider or "pi"
  local created = type(raw.createdAt) == "string" and raw.createdAt or now_iso()

  return {
    id = normalize_id(raw.id) or next_id(),
    provider = provider,
    title = type(raw.title) == "string" and raw.title or (provider .. " thread"),
    cwd = type(raw.cwd) == "string" and raw.cwd or root_key,
    status = normalize_status(raw.status),
    createdAt = created,
    updatedAt = type(raw.updatedAt) == "string" and raw.updatedAt or created,
    lastPrompt = type(raw.lastPrompt) == "string" and raw.lastPrompt or nil,
    bufferName = type(raw.bufferName) == "string" and raw.bufferName or nil,
    notes = type(raw.notes) == "string" and raw.notes or nil,
  }
end

local function each_threads(source, callback)
  if type(source) ~= "table" then
    return
  end
  if vim.islist(source) then
    for _, value in ipairs(source) do
      callback(value)
    end
    return
  end
  for _, value in pairs(source) do
    callback(value)
  end
end

local function find_thread(bucket, thread_id)
  local wanted = normalize_id(thread_id)
  if not wanted then
    return nil, nil
  end

  for index, thread in ipairs(bucket.threads) do
    if normalize_id(thread.id) == wanted then
      return thread, index
    end
  end

  return nil, nil
end

local function normalize_store(decoded)
  local source = {}
  if type(decoded) == "table" then
    if type(decoded.projects) == "table" then
      source = decoded.projects
    else
      source = decoded
    end
  end

  local store = {}
  for key, value in pairs(source) do
    if type(key) == "string" then
      local root_key = M.project_key(key)
      local bucket = ensure_bucket(store, root_key)

      if vim.islist(value) then
        each_threads(value, function(raw)
          local thread = normalize_thread(raw, root_key)
          if thread then
            table.insert(bucket.threads, thread)
          end
        end)
      elseif type(value) == "table" then
        bucket.activeThreadId = normalize_id(value.activeThreadId)
        each_threads(value.threads, function(raw)
          local thread = normalize_thread(raw, root_key)
          if thread then
            table.insert(bucket.threads, thread)
          end
        end)
      end

      if bucket.activeThreadId and not find_thread(bucket, bucket.activeThreadId) then
        bucket.activeThreadId = nil
      end
    end
  end

  return store
end

local function locate_thread(store, thread_id)
  local wanted = normalize_id(thread_id)
  if not wanted then
    return nil, nil, nil
  end

  for root_key, bucket in pairs(store) do
    local thread, index = find_thread(bucket, wanted)
    if thread then
      return root_key, bucket, index
    end
  end

  return nil, nil, nil
end

function M.path()
  return vim.fn.stdpath("state") .. "/etabli/ops-agent-threads.json"
end

local function canonical_root(path)
  local resolved = review_util.normalize(path)
  if vim.fn.filereadable(resolved) == 1 then
    resolved = vim.fs.dirname(resolved)
  end

  local marker = vim.fs.find(".git", { path = resolved, upward = true })[1]
  if marker then
    return review_util.normalize(vim.fs.dirname(marker))
  end

  return resolved
end

function M.project_key(root)
  local resolved = root
  if not resolved or resolved == "" then
    local ok, current_root = pcall(projects.current_root)
    resolved = ok and current_root or vim.fn.getcwd()
  end

  return canonical_root(resolved)
end

function M.read_store()
  local file = io.open(M.path(), "r")
  if not file then
    return {}
  end

  local content = file:read("*a")
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    return {}
  end

  return normalize_store(decoded)
end

function M.write_store(store)
  review_util.ensure_dir(vim.fs.dirname(M.path()))
  local file = io.open(M.path(), "w")
  if not file then
    return false
  end

  file:write(vim.json.encode(store or {}))
  file:close()
  return true
end

function M.list_threads(root)
  local root_key = M.project_key(root)
  local bucket = ensure_bucket(M.read_store(), root_key)
  return vim.deepcopy(bucket.threads)
end

function M.get_active_thread(root)
  local root_key = M.project_key(root)
  local bucket = ensure_bucket(M.read_store(), root_key)
  local thread = find_thread(bucket, bucket.activeThreadId)
  return thread and vim.deepcopy(thread) or nil
end

function M.create_thread(opts)
  local options = opts or {}
  local root_key = M.project_key(options.root or options.cwd)
  local store = M.read_store()
  local bucket = ensure_bucket(store, root_key)
  local thread = normalize_thread({
    id = options.id,
    provider = options.provider,
    title = options.title,
    cwd = options.cwd or root_key,
    status = options.status,
    createdAt = options.createdAt,
    updatedAt = options.updatedAt,
    lastPrompt = options.lastPrompt,
    bufferName = options.bufferName,
    notes = options.notes,
  }, root_key)

  table.insert(bucket.threads, thread)
  if bucket.activeThreadId == nil then
    bucket.activeThreadId = thread.id
  end

  M.write_store(store)
  return vim.deepcopy(thread)
end

function M.set_active_thread(root, thread_id)
  local target_root = root
  local target_id = thread_id
  if target_id == nil then
    target_id = root
    target_root = nil
  end

  local store = M.read_store()
  local root_key = target_root and M.project_key(target_root) or nil
  local bucket = root_key and ensure_bucket(store, root_key) or nil

  if not bucket then
    root_key, bucket = locate_thread(store, target_id)
  end
  if not bucket then
    return false
  end

  local thread = find_thread(bucket, target_id)
  if not thread then
    return false
  end

  bucket.activeThreadId = normalize_id(target_id)
  M.write_store(store)
  return true
end

function M.update_thread(root, thread_id, patch)
  local target_root = root
  local target_id = thread_id
  local updates = patch

  if updates == nil and type(thread_id) == "table" then
    updates = thread_id
    target_id = root
    target_root = nil
  end

  local store = M.read_store()
  local root_key = target_root and M.project_key(target_root) or nil
  local bucket = root_key and ensure_bucket(store, root_key) or nil
  local thread, index

  if bucket then
    thread, index = find_thread(bucket, target_id)
  else
    root_key, bucket, index = locate_thread(store, target_id)
    thread = bucket and bucket.threads[index] or nil
  end

  if not thread or not index then
    return nil
  end

  local merged = normalize_thread(vim.tbl_extend("force", thread, updates or {}, { updatedAt = now_iso() }), root_key)
  bucket.threads[index] = merged
  M.write_store(store)
  return vim.deepcopy(merged)
end

function M.remove_thread(root, thread_id)
  local root_key = M.project_key(root)
  local store = M.read_store()
  local bucket = ensure_bucket(store, root_key)
  local _, index = find_thread(bucket, thread_id)
  if not index then
    return false
  end

  table.remove(bucket.threads, index)
  if bucket.activeThreadId and not find_thread(bucket, bucket.activeThreadId) then
    bucket.activeThreadId = bucket.threads[1] and bucket.threads[1].id or nil
  end

  M.write_store(store)
  return true
end

function M.summarize(root)
  local root_key = M.project_key(root)
  local bucket = ensure_bucket(M.read_store(), root_key)
  local counts = {
    total = #bucket.threads,
    running = 0,
    inactive = 0,
    idle = 0,
    error = 0,
  }

  for _, thread in ipairs(bucket.threads) do
    if counts[thread.status] ~= nil then
      counts[thread.status] = counts[thread.status] + 1
    end
  end

  return {
    project = root_key,
    activeThreadId = bucket.activeThreadId,
    threads = vim.deepcopy(bucket.threads),
    counts = counts,
  }
end

return M
