local doctor = require("config.ops.doctor")
local mode = require("config.ops.mode")
local snapshot = require("config.ops.snapshot")
local state = require("config.ops.state")
local view = require("config.ops.view")

local M = {}

local function try_write_snapshot(cwd, title)
  local ok, err = pcall(snapshot.write, cwd)
  if ok then
    return
  end
  vim.notify(
    string.format("Snapshot export failed: %s", err),
    vim.log.levels.WARN,
    { title = title }
  )
end

function M.show_status()
  vim.notify(table.concat(view.info_lines(), "\n"), vim.log.levels.INFO, { title = "OPSStatus" })
end

function M.show_next()
  vim.notify(table.concat(view.next_lines(), "\n"), vim.log.levels.INFO, { title = "OPSNext" })
end

function M.refresh_review()
  local cwd = vim.fn.getcwd()
  local review = state.refresh_review_summary(cwd)
  try_write_snapshot(cwd, "OPSRefreshReview")
  local lines = {
    "OPS review refresh:",
    "Review:     " .. review.line,
  }
  for _, warning in ipairs(review.warnings or {}) do
    table.insert(lines, "Review warn: " .. warning)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "OPSRefreshReview" })
end

function M.open_plan()
  local plan = state.plan_state(vim.fn.getcwd())
  if not plan.exists then
    vim.notify("Missing PLAN.md in current working directory", vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(plan.path))
  if #plan.warnings > 0 then
    vim.notify(table.concat(plan.warnings, "\n"), vim.log.levels.WARN, { title = "OPSOpenPlan" })
  end
end

function M.open_review()
  require("config.review").open_inbox()
end

function M.open_handoff()
  local handoff = state.handoff_state(vim.fn.getcwd())
  if not handoff.available then
    vim.notify("Missing handoff file: .pi/handoff-implement.md or .pi/handoff.md", vim.log.levels.WARN)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(handoff.path))
end

function M.resume()
  local projects = require("config.projects")
  local root = projects.current_root()
  local session_state = "missing"
  if projects.session_exists(root) then
    session_state = projects.load_session_state(root)
  end

  vim.notify(table.concat(view.resume_lines(root, session_state), "\n"), vim.log.levels.INFO, { title = "OPSResume" })
end

function M.show_doctor()
  vim.notify(table.concat(doctor.lines(), "\n"), vim.log.levels.INFO, { title = "OPSDoctor" })
end

function M.show_mode(command_mode)
  local cwd = vim.fn.getcwd()
  if command_mode and command_mode ~= "" then
    local mode_state, err = mode.write(cwd, command_mode)
    if not mode_state then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    vim.notify(
      string.format("OPS mode set to %s\n%s", mode_state.mode, mode_state.description.roles),
      vim.log.levels.INFO,
      { title = "OPSMode" }
    )
    try_write_snapshot(cwd, "OPSMode")
    return
  end

  local mode_state = mode.read(cwd)
  vim.notify(
    string.format(
      "OPS mode: %s\nRoles: %s\nReview: %s\nWorktrees: %s",
      mode_state.explicit and mode_state.mode or (mode_state.mode .. " (default)"),
      mode_state.description.roles,
      mode_state.description.review,
      mode_state.description.worktrees
    ),
    vim.log.levels.INFO,
    { title = "OPSMode" }
  )
end

return M
