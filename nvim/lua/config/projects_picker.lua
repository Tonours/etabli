local M = {}

local telescope_loader = require("config.telescope")
local worktrees = require("config.worktrees")

-- Cache for telescope modules to avoid repeated requires
local telescope_modules = nil

local function get_telescope_modules()
  if telescope_modules then
    return telescope_modules
  end

  local pickers = telescope_loader.require("telescope.pickers")
  local finders = telescope_loader.require("telescope.finders")
  local config = telescope_loader.require("telescope.config")
  local actions = telescope_loader.require("telescope.actions")
  local action_state = telescope_loader.require("telescope.actions.state")

  if not (pickers and finders and config and actions and action_state) then
    return nil
  end

  telescope_modules = {
    pickers = pickers,
    finders = finders,
    config = config,
    actions = actions,
    action_state = action_state,
  }
  return telescope_modules
end

local function open_picker(title, results, on_select, opts)
  if #vim.api.nvim_list_uis() == 0 then
    vim.notify(title .. " is not available in headless mode", vim.log.levels.WARN)
    return
  end

  -- Use schedule for immediate but non-blocking execution
  vim.schedule(function()
    local ts = get_telescope_modules()
    if not ts then
      vim.notify("Telescope not available", vim.log.levels.ERROR)
      return
    end

    local options = opts or {}

    -- Pre-allocate results table if large
    local entry_maker = function(entry) return entry end

    ts.pickers.new({}, {
      finder = ts.finders.new_table({ results = results, entry_maker = entry_maker }),
      previewer = false,
      prompt_title = options.prompt_title or title,
      sorter = ts.config.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        ts.actions.select_default:replace(function()
          local selection = ts.action_state.get_selected_entry()
          ts.actions.close(prompt_bufnr)
          if selection then
            on_select(selection.value)
          end
        end)

        if options.attach_mappings then
          return options.attach_mappings(prompt_bufnr, ts)
        end

        return true
      end,
    }):find()
  end)
end

local function cw_command()
  local command = vim.fn.exepath("cw")
  if command ~= "" then
    return command
  end

  vim.notify("cw is not available in PATH", vim.log.levels.ERROR)
  return nil
end

local function create_worktree_for(repo_path)
  local command = cw_command()
  if not command then
    return
  end

  vim.ui.input({ prompt = "Worktree task: " }, function(task)
    local task_value = task and vim.trim(task) or ""
    if task_value == "" then
      return
    end

    vim.ui.input({ prompt = "Branch prefix: ", default = "feature" }, function(prefix)
      if prefix == nil then
        return
      end

      local prefix_value = vim.trim(prefix)
      if prefix_value == "" then
        prefix_value = "feature"
      end

      local result = vim.system({
        command,
        "new",
        "--detach",
        "--no-agent",
        "--print-path",
        repo_path,
        task_value,
        prefix_value,
      }, { text = true }):wait()

      if result.code ~= 0 then
        vim.notify(vim.trim(result.stderr or "cw new failed"), vim.log.levels.ERROR)
        return
      end

      local path = vim.trim(result.stdout or "")
      if path == "" then
        vim.notify("cw new did not return a worktree path", vim.log.levels.ERROR)
        return
      end

      require("config.projects").open_project(path)
    end)
  end)
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
  local root = projects.current_root()
  local results = worktrees.entries(root)

  if vim.tbl_isempty(results) then
    vim.notify("No git worktrees found for current repo", vim.log.levels.INFO)
    return
  end

  open_picker("Worktrees", results, projects.open_project, {
    prompt_title = "Worktrees · <C-n> new",
    attach_mappings = function(prompt_bufnr, ts)
      local map = vim.keymap.set
      map("i", "<C-n>", function()
        ts.actions.close(prompt_bufnr)
        create_worktree_for(root)
      end, { buffer = prompt_bufnr })
      map("n", "<C-n>", function()
        ts.actions.close(prompt_bufnr)
        create_worktree_for(root)
      end, { buffer = prompt_bufnr })

      return true
    end,
  })
end

function M.create_worktree()
  create_worktree_for(require("config.projects").current_root())
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
