local M = {}

local dirty_roots = {}

local function normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function current_root()
  return require("config.projects").current_root()
end

local function mark_dirty(root)
  dirty_roots[normalize(root or current_root())] = true
end

local function clear_dirty(root)
  dirty_roots[normalize(root or current_root())] = nil
end

function M.session_marker(root)
  local project_root = normalize(root or current_root())
  local projects = require("config.projects")

  if not projects.session_exists(project_root) then
    return ""
  end

  if dirty_roots[project_root] then
    return " +"
  end

  return " •"
end

function M.clear_dirty(root)
  clear_dirty(root)
end

function M.mark_dirty(root)
  mark_dirty(root)
end

function M.project_info_lines()
  local projects = require("config.projects")
  local worktree = require("config.worktrees").current()
  local root = projects.current_root()
  local buffer_root = projects.buffer_root()
  local marker = M.session_marker(root)

  return {
    "Project:    " .. vim.fn.fnamemodify(root, ":t"),
    "CWD:        " .. root,
    "Buffer root:" .. (buffer_root and " " .. buffer_root or " none"),
    "Worktree:   " .. (worktree and (worktree.branch ~= "" and worktree.branch or worktree.tail) or "none"),
    "Session:    " .. (projects.session_exists(root) and (marker == " +" and "exists, unsaved changes since session" or "exists") or "none"),
    "Marker:     " .. (marker == "" and "none" or marker),
  }
end

function M.project_info()
  vim.notify(table.concat(M.project_info_lines(), "\n"), vim.log.levels.INFO, { title = "ProjectInfo" })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("etabli_project_runtime", { clear = true })

  vim.api.nvim_create_user_command("ProjectInfo", function()
    M.project_info()
  end, {})

  vim.api.nvim_create_user_command("PI", function()
    M.project_info()
  end, {})

  vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufModifiedSet", "DirChanged", "TabNew", "TabClosed", "WinNew", "WinClosed" }, {
    group = group,
    callback = function()
      mark_dirty()
      require("config.statusline").invalidate()
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      clear_dirty()
      require("config.statusline").invalidate()
    end,
  })
end

return M
