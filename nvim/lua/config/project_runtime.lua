local M = {}

local dirty_roots = {}
local commands_registered = false

local function normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function current_root()
  return require("config.projects").current_root()
end

local function mark_dirty(root)
  local key = normalize(root or current_root())
  if dirty_roots[key] then
    return false
  end

  dirty_roots[key] = true
  return true
end

local function clear_dirty(root)
  local key = normalize(root or current_root())
  if not dirty_roots[key] then
    return false
  end

  dirty_roots[key] = nil
  return true
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
  local ops = require("config.ops")
  local root = projects.current_root()
  local buffer_root = projects.buffer_root()
  local marker = M.session_marker(root)

  local lines = {
    "Project:    " .. vim.fn.fnamemodify(root, ":t"),
    "CWD:        " .. root,
    "Buffer root:" .. (buffer_root and " " .. buffer_root or " none"),
    "Session:    " .. (projects.session_exists(root) and (marker == " +" and "exists, unsaved changes since session" or "exists") or "none"),
    "Marker:     " .. (marker == "" and "none" or marker),
  }

  vim.list_extend(lines, ops.project_info_lines(root))
  return lines
end

function M.project_info()
  vim.notify(table.concat(M.project_info_lines(), "\n"), vim.log.levels.INFO, { title = "ProjectInfo" })
end

function M.setup_commands()
  if commands_registered then
    return
  end

  commands_registered = true

  vim.api.nvim_create_user_command("ProjectInfo", function()
    M.project_info()
  end, {})

  vim.api.nvim_create_user_command("PI", function()
    M.project_info()
  end, {})
end

function M.setup()
  local group = vim.api.nvim_create_augroup("etabli_project_runtime", { clear = true })

  M.setup_commands()

  -- Throttled autocmd with optimized batching using single timer
  local dirty_timer = nil
  local throttle_ms = 25 -- Throttle time for batching (reduced from 35ms)

  -- Single autocmd with pattern matching for efficiency
  vim.api.nvim_create_autocmd({
    "BufAdd", "BufDelete", "BufModifiedSet",
    "DirChanged", "TabNew", "TabClosed", "WinNew", "WinClosed"
  }, {
    group = group,
    callback = function()
      -- Stop existing timer if any
      if dirty_timer then
        vim.fn.timer_stop(dirty_timer)
      end

      -- Create new timer
      dirty_timer = vim.fn.timer_start(throttle_ms, function()
        dirty_timer = nil
        if mark_dirty() then
          require("config.statusline").invalidate()
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      clear_dirty()
      require("config.statusline").invalidate()
    end,
  })
end

return M
