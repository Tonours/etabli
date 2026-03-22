local M = {}

local worktrees = require("config.worktrees")

local function open_picker(title, results, on_select)
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_config, config = pcall(require, "telescope.config")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_state, action_state = pcall(require, "telescope.actions.state")

  if not (ok_pickers and ok_finders and ok_config and ok_actions and ok_state) then
    vim.notify("Telescope not available", vim.log.levels.ERROR)
    return
  end

  pickers.new({}, {
    finder = finders.new_table({ results = results, entry_maker = function(entry) return entry end }),
    previewer = false,
    prompt_title = title,
    sorter = config.values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          on_select(selection.value)
        end
      end)

      return true
    end,
  }):find()
end

function M.pick_project()
  local projects = require("config.projects")
  local results = projects.list_projects()
  local seen = {}

  for _, entry in ipairs(results) do
    seen[entry.value] = true
  end

  for _, entry in ipairs(worktrees.entries(projects.current_root())) do
    if not seen[entry.value] then
      table.insert(results, 1, entry)
      seen[entry.value] = true
    end
  end

  open_picker("Projects", results, projects.open_project)
end

function M.pick_worktree()
  local projects = require("config.projects")
  local results = worktrees.entries(projects.current_root())

  if vim.tbl_isempty(results) then
    vim.notify("No git worktrees found for current repo", vim.log.levels.INFO)
    return
  end

  open_picker("Worktrees", results, projects.open_project)
end

function M.pick_project_recent_files()
  local root = require("config.projects").current_root()
  local results = {}
  local seen = {}

  for _, file in ipairs(vim.v.oldfiles or {}) do
    local normalized = vim.fs.normalize(file)
    if vim.startswith(normalized, root .. "/") and vim.fn.filereadable(normalized) == 1 and not seen[normalized] then
      table.insert(results, {
        display = normalized:sub(#root + 2),
        ordinal = normalized,
        value = normalized,
      })
      seen[normalized] = true
    end
  end

  if vim.tbl_isempty(results) then
    vim.notify("No recent files for current project", vim.log.levels.INFO)
    return
  end

  open_picker("Project Recent Files", results, function(file)
    vim.cmd.edit(vim.fn.fnameescape(file))
  end)
end

return M
