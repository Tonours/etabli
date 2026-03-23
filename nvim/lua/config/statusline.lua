local M = {}

local colors = {
  project = "#89b4fa",
  worktree = "#a6e3a1",
}

local cached_context = nil
local cache_cwd = ""

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
  local relative_path = vim.fn.fnamemodify(path, ":~:.")
  local relative_paths = {}

  for _, item in ipairs(paths) do
    table.insert(relative_paths, vim.fn.fnamemodify(item, ":~:."))
  end

  local parts = path_parts(relative_path)
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
      return candidate
    end
  end

  return relative_path
end

local function refresh_context()
  local cwd = vim.fn.getcwd()
  if cached_context and cwd == cache_cwd then
    return cached_context
  end

  local projects = require("config.projects")
  local runtime = require("config.project_runtime")
  local worktree = require("config.worktrees").current(cwd)
  local session_marker = runtime.session_marker(cwd)

  if worktree then
    cached_context = {
      color = colors.worktree,
      label = " " .. (worktree.branch ~= "" and worktree.branch or worktree.tail) .. session_marker,
    }
  else
    local root = projects.current_root()
    cached_context = {
      color = colors.project,
      label = "󰉋 " .. vim.fn.fnamemodify(root, ":t") .. session_marker,
    }
  end

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
end

function M.project_label()
  return refresh_context().label
end

function M.project_color()
  return { fg = refresh_context().color }
end

function M.tabline()
  local current = vim.api.nvim_get_current_tabpage()
  local parts = {}

  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local tabnr = vim.api.nvim_tabpage_get_number(tab)
    local hl = tab == current and "%#TabLineSel#" or "%#TabLine#"
    table.insert(parts, string.format("%%%dT%s %d %s %%T", tabnr, hl, tabnr, tab_label(tab)))
  end

  table.insert(parts, "%#TabLineFill#%=")
  return table.concat(parts, "")
end

return M
