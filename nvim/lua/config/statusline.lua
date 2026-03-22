local M = {}

local colors = {
  project = "#89b4fa",
  worktree = "#a6e3a1",
}

local cached_context = nil
local cache_cwd = ""

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

return M
