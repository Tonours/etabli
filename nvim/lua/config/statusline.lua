local M = {}

local colors = {
  project = "#89b4fa",
}

local cached_context = nil
local cache_cwd = ""

-- Tabline caching - more aggressive caching
local cached_tabline = nil
local tabline_cache_cwd = ""
local tabline_cache_tabcount = 0
local tabline_cache_current = nil
local tabline_cache_bufcount = 0
local tabline_cache_version = 0

-- Path cache for unique_path_label
local path_cache = {}
local path_cache_cwd = ""

-- Track buffer changes for cache invalidation
local buffer_change_count = 0
vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufFilePost" }, {
  callback = function()
    buffer_change_count = buffer_change_count + 1
  end,
})

-- Use a more efficient buffer change tracking with debouncing
local buffer_change_timer = nil
vim.api.nvim_create_autocmd({ "BufEnter", "BufLeave" }, {
  callback = function()
    if buffer_change_timer then
      vim.fn.timer_stop(buffer_change_timer)
    end
  buffer_change_timer = vim.fn.timer_start(75, function()
      buffer_change_count = buffer_change_count + 1
      buffer_change_timer = nil
    end)
  end,
})

local function join_last(parts, count)
  local start_index = math.max(#parts - count + 1, 1)
  return table.concat(parts, "/", start_index, #parts)
end

local function path_parts(path)
  local parts = {}

  for part in vim.fs.normalize(path):gmatch("[^/]+") do
    table.insert(parts, part)
  end

  return parts
end

local function unique_path_label(path, paths)
  -- Clear cache if cwd changed
  local cwd = vim.fn.getcwd()
  if cwd ~= path_cache_cwd then
    path_cache = {}
    path_cache_cwd = cwd
  end

  -- Check cache first
  local cached = path_cache[path]
  if cached then
    return cached
  end

  -- Fast path: single path, just return the tail
  if #paths <= 1 then
    local result = vim.fn.fnamemodify(path, ":t")
    path_cache[path] = result
    return result
  end

  local relative_path = vim.fn.fnamemodify(path, ":~:.")

  -- Batch convert paths to relative once
  local relative_paths = {}
  for i, item in ipairs(paths) do
    relative_paths[i] = vim.fn.fnamemodify(item, ":~:.")
  end

  local parts = path_parts(relative_path)

  -- Fast path: single-part paths
  if #parts == 1 then
    path_cache[path] = relative_path
    return relative_path
  end

  for count = 1, #parts do
    local candidate = join_last(parts, count)
    local unique = true

    for _, item in ipairs(relative_paths) do
      if item ~= relative_path and join_last(path_parts(item), count) == candidate then
        unique = false
        break
      end
    end

    if unique then
      path_cache[path] = candidate
      return candidate
    end
  end

  path_cache[path] = relative_path
  return relative_path
end

local function refresh_context()
  local cwd = vim.fn.getcwd()
  if cached_context and cwd == cache_cwd then
    return cached_context
  end

  local projects = require("config.projects")
  local runtime = require("config.project_runtime")
  local session_marker = runtime.session_marker(cwd)

  local project_root = projects.current_root()
  cached_context = {
    project_color = colors.project,
    project_label = "󰉋 " .. vim.fn.fnamemodify(project_root, ":t") .. session_marker,
  }

  cache_cwd = cwd
  return cached_context
end

local function tab_label(tab)
  local win = vim.api.nvim_tabpage_get_win(tab)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  local buftype = vim.bo[buf].buftype
  local filetype = vim.bo[buf].filetype
  local modified = vim.bo[buf].modified and " +" or ""

  if filetype == "NvimTree" then
    local tabnr = vim.api.nvim_tabpage_get_number(tab)
    return "explorer:" .. vim.fn.fnamemodify(vim.fn.getcwd(-1, tabnr), ":t") .. modified
  end

  if buftype == "terminal" then
    local terminal_name = name:match("^term://([^:]+)") or "terminal"
    return terminal_name .. modified
  end

  if name == "" then
    return "[No Name]" .. modified
  end

  local paths = {}
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    local tab_win = vim.api.nvim_tabpage_get_win(tabpage)
    local tab_buf = vim.api.nvim_win_get_buf(tab_win)
    local tab_name = vim.api.nvim_buf_get_name(tab_buf)

    if tab_name ~= "" and vim.bo[tab_buf].buftype == "" then
      table.insert(paths, tab_name)
    end
  end

  local tail = vim.fn.fnamemodify(name, ":t")
  local duplicates = {}
  for _, path in ipairs(paths) do
    if vim.fn.fnamemodify(path, ":t") == tail then
      table.insert(duplicates, path)
    end
  end

  if #duplicates > 1 then
    return unique_path_label(name, duplicates) .. modified
  end

  return tail .. modified
end

function M.invalidate()
  cached_context = nil
  cache_cwd = ""
  -- Also invalidate tabline cache
  cached_tabline = nil
  tabline_cache_cwd = ""
  tabline_cache_tabcount = 0
  tabline_cache_current = nil
  tabline_cache_bufcount = 0
  tabline_cache_version = buffer_change_count
  -- Clear path cache
  path_cache = {}
  path_cache_cwd = ""
end

function M.project_label()
  local ctx = refresh_context()
  return ctx and ctx.project_label or ""
end

function M.project_color()
  local ctx = refresh_context()
  return ctx and { fg = ctx.project_color } or {}
end

function M.tabline()
  local current = vim.api.nvim_get_current_tabpage()
  local tabs = vim.api.nvim_list_tabpages()
  local cwd = vim.fn.getcwd()
  local buf_count = #vim.api.nvim_list_bufs()

  -- Use cached tabline if context hasn't changed
  if cached_tabline
    and cwd == tabline_cache_cwd
    and #tabs == tabline_cache_tabcount
    and current == tabline_cache_current
    and buf_count == tabline_cache_bufcount
    and buffer_change_count == tabline_cache_version then
    return cached_tabline
  end

  -- Pre-allocate parts table with exact capacity
  local parts = {}
  local idx = 0
  for i = 1, #tabs do
    local tab = tabs[i]
    local tabnr = vim.api.nvim_tabpage_get_number(tab)
    local hl = tab == current and "%#TabLineSel#" or "%#TabLine#"
    idx = idx + 1
    parts[idx] = string.format("%%%dT%s %d %s %%T", tabnr, hl, tabnr, tab_label(tab))
  end

  parts[idx + 1] = "%#TabLineFill#%="

  -- Update cache
  cached_tabline = table.concat(parts, "")
  tabline_cache_cwd = cwd
  tabline_cache_tabcount = #tabs
  tabline_cache_current = current
  tabline_cache_bufcount = buf_count
  tabline_cache_version = buffer_change_count

  return cached_tabline
end

-- Cache invalidation on relevant events
local function setup_invalidation()
  local group = vim.api.nvim_create_augroup("etabli_statusline_cache", { clear = true })

  vim.api.nvim_create_autocmd({ "DirChanged" }, {
    group = group,
    callback = M.invalidate,
  })

  -- Clear tabline cache when tabs change
  vim.api.nvim_create_autocmd({ "TabNew", "TabClosed" }, {
    group = group,
    callback = function()
      cached_tabline = nil
      tabline_cache_cwd = ""
      tabline_cache_tabcount = 0
      tabline_cache_current = nil
      -- Clear path cache on tab changes
      path_cache = {}
      path_cache_cwd = ""
    end,
  })

  -- Only update current tab highlight on TabEnter without full rebuild
  vim.api.nvim_create_autocmd("TabEnter", {
    group = group,
    callback = function()
      cached_tabline = nil
    end,
  })
end

setup_invalidation()

return M
