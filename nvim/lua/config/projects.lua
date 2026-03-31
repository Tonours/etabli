local M = {}

-- Cache for normalized paths to avoid repeated filesystem calls
local normalize_cache = {}
local normalize_cache_size = 0
local normalize_cache_max = 1000

local function cached_normalize(path)
  if normalize_cache[path] then
    return normalize_cache[path]
  end

  local result = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))

  -- Limit cache size to prevent memory bloat
  if normalize_cache_size < normalize_cache_max then
    normalize_cache[path] = result
    normalize_cache_size = normalize_cache_size + 1
  end

  return result
end

local markers = {
  ".git",
  "package.json",
  "composer.json",
  "tsconfig.json",
  "jsconfig.json",
}

local state_dir = vim.fn.stdpath("state") .. "/etabli"
local projects_file = state_dir .. "/projects.json"
local sessions_dir = state_dir .. "/sessions"

-- Cache for projects list to avoid repeated file reads
local projects_cache = nil
local projects_cache_time = 0
local projects_cache_ttl = 3000 -- 3 seconds cache TTL (reduced from 5s)

local function ensure_dirs()
  vim.fn.mkdir(state_dir, "p")
  vim.fn.mkdir(sessions_dir, "p")
end

local function path_exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function normalize(path)
  return cached_normalize(path)
end

local function session_path(root)
  local name = root:gsub("[:/\\]", "%%")
  return sessions_dir .. "/" .. name .. ".vim"
end

local function has_marker(root)
  for _, marker in ipairs(markers) do
    if path_exists(root .. "/" .. marker) then
      return true
    end
  end

  return false
end

local function should_track(root)
  return has_marker(root) or vim.fn.filereadable(session_path(root)) == 1
end

local function read_projects()
  -- Check cache first
  local now = vim.loop.now()
  if projects_cache and (now - projects_cache_time) < projects_cache_ttl then
    return vim.deepcopy(projects_cache)
  end

  if vim.fn.filereadable(projects_file) ~= 1 then
    return {}
  end

  local ok_read, lines = pcall(vim.fn.readfile, projects_file)
  if not ok_read then
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(decoded) ~= "table" then
    return {}
  end

  -- Update cache
  projects_cache = decoded
  projects_cache_time = now

  return vim.deepcopy(decoded)
end

local function write_projects(projects)
  ensure_dirs()
  vim.fn.writefile({ vim.json.encode(projects) }, projects_file)
  -- Invalidate cache on write
  projects_cache = nil
  projects_cache_time = 0
end

-- Track modified buffer count for faster checks
local modified_count = 0
local modified_count_valid = false

local function update_modified_count()
  if modified_count_valid then
    return modified_count
  end

  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      count = count + 1
    end
  end
  modified_count = count
  modified_count_valid = true
  return count
end

-- Invalidate modified count on buffer changes
vim.api.nvim_create_autocmd({ "BufModifiedSet", "BufAdd", "BufDelete" }, {
  callback = function()
    modified_count_valid = false
  end,
})

local function is_modified()
  return update_modified_count() > 0
end

local function detect_root(path)
  local start = path ~= "" and path or vim.fn.getcwd()
  if vim.fn.filereadable(start) == 1 then
    start = vim.fs.dirname(start)
  end

  local found = vim.fs.find(markers, { path = start, upward = true })[1]
  if not found then
    return nil
  end

  return normalize(vim.fs.dirname(found))
end

local function has_meaningful_layout()
  -- Quick checks first (cheaper operations)
  if #vim.api.nvim_list_tabpages() > 1 or #vim.api.nvim_list_wins() > 1 then
    return true
  end

  -- Check current buffer only (most likely to have content)
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_loaded(current_buf) then
    local name = vim.api.nvim_buf_get_name(current_buf)
    if name ~= "" then
      return true
    end
    local buftype = vim.bo[current_buf].buftype
    if buftype ~= "" then
      return true
    end
  end

  return false
end

local function confirm_replace_layout()
  if not has_meaningful_layout() then
    return true
  end

  local choice = vim.fn.confirm(
    "Replace current layout with the saved project session?",
    "&Yes\n&No",
    2
  )

  return choice == 1
end

function M.current_root()
  return normalize(vim.fn.getcwd())
end

function M.buffer_root()
  local name = vim.api.nvim_buf_get_name(0)
  return detect_root(name)
end

function M.track(root)
  local project_root = normalize(root)
  if not should_track(project_root) then
    return
  end

  local projects = read_projects()
  local updated = { project_root }

  for _, project in ipairs(projects) do
    if project ~= project_root then
      table.insert(updated, project)
    end
  end

  write_projects(updated)
end

function M.change_root(root)
  local project_root = normalize(root)
  vim.cmd("cd " .. vim.fn.fnameescape(project_root))
  M.track(project_root)
end

local function save_session_file(root, notify)
  local project_root = normalize(root)
  local target = session_path(project_root)

  if not should_track(project_root) then
    return
  end

  ensure_dirs()
  M.track(project_root)
  vim.cmd("silent! mksession! " .. vim.fn.fnameescape(target))
  require("config.project_runtime").clear_dirty(project_root)

  if notify then
    vim.notify("Project session saved", vim.log.levels.INFO)
  end
end

function M.save_session()
  save_session_file(M.current_root(), true)
end

local function load_session_state(root)
  local project_root = normalize(root or M.current_root())
  local target = session_path(project_root)

  if vim.fn.filereadable(target) ~= 1 then
    return "missing"
  end

  if is_modified() then
    vim.notify("Save or close modified buffers before loading a project session", vim.log.levels.WARN)
    return "blocked"
  end

  if not confirm_replace_layout() then
    return "cancelled"
  end

  M.change_root(project_root)
  vim.cmd("silent! tabonly")
  vim.cmd("silent! only")
  vim.cmd("silent! %bwipeout!")
  vim.cmd("silent! source " .. vim.fn.fnameescape(target))
  return "loaded"
end

function M.load_session(root)
  return load_session_state(root) ~= "missing"
end

function M.load_session_state(root)
  return load_session_state(root)
end

function M.root_current_buffer()
  local root = M.buffer_root()
  if not root then
    vim.notify("No project root found for current buffer", vim.log.levels.WARN)
    return
  end

  M.change_root(root)
  vim.notify("Project root set", vim.log.levels.INFO)
end

function M.open_project(root)
  local project_root = normalize(root)
  if is_modified() then
    vim.notify("Save or close modified buffers before switching projects", vim.log.levels.WARN)
    return
  end

  local current = M.current_root()
  if current ~= project_root then
    save_session_file(current, false)
  end

  if not M.load_session(project_root) then
    M.change_root(project_root)
    vim.cmd("Telescope find_files")
  end
end

function M.session_exists(root)
  return vim.fn.filereadable(session_path(root or M.current_root())) == 1
end

function M.list_projects()
  local projects = read_projects()
  local current = M.current_root()
  if should_track(current) and not vim.tbl_contains(projects, current) then
    table.insert(projects, 1, current)
  end

  return vim.tbl_map(function(root)
    local tail = vim.fn.fnamemodify(root, ":t")
    return {
      display = tail .. " — " .. root,
      ordinal = tail .. " " .. root,
      value = root,
    }
  end, projects)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("etabli_projects", { clear = true })
  local last_root = ""

  -- Defer tracking on VimEnter to improve startup time (use schedule for faster execution)
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      vim.schedule(function()
        local project_root = M.current_root()
        if should_track(project_root) and project_root ~= last_root then
          last_root = project_root
          M.track(project_root)
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      local project_root = M.current_root()
      if not should_track(project_root) or project_root == last_root then
        return
      end

      last_root = project_root
      M.track(project_root)
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if is_modified() then
        return
      end

      save_session_file(M.current_root(), false)
    end,
  })
end

return M
