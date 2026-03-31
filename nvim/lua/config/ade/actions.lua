local doctor = require("config.ade.doctor")
local mode = require("config.ade.mode")
local snapshot = require("config.ade.snapshot")
local state = require("config.ade.state")
local view = require("config.ade.view")

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
  vim.notify(table.concat(view.info_lines(), "\n"), vim.log.levels.INFO, { title = "ADEStatus" })
end

function M.show_next()
  vim.notify(table.concat(view.next_lines(), "\n"), vim.log.levels.INFO, { title = "ADENext" })
end

function M.refresh_review()
  local cwd = vim.fn.getcwd()
  local review = state.refresh_review_summary(cwd)
  try_write_snapshot(cwd, "ADERefreshReview")
  local lines = {
    "ADE review refresh:",
    "Review:     " .. review.line,
  }
  for _, warning in ipairs(review.warnings or {}) do
    table.insert(lines, "Review warn: " .. warning)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "ADERefreshReview" })
end

function M.open_plan()
  local plan = state.plan_state(vim.fn.getcwd())
  if not plan.exists then
    vim.notify("Missing PLAN.md in current working directory", vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(plan.path))
  if #plan.warnings > 0 then
    vim.notify(table.concat(plan.warnings, "\n"), vim.log.levels.WARN, { title = "ADEOpenPlan" })
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

  vim.notify(table.concat(view.resume_lines(root, session_state), "\n"), vim.log.levels.INFO, { title = "ADEResume" })
end

function M.show_doctor()
  vim.notify(table.concat(doctor.lines(), "\n"), vim.log.levels.INFO, { title = "ADEDoctor" })
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
      string.format("ADE mode set to %s\n%s", mode_state.mode, mode_state.description.roles),
      vim.log.levels.INFO,
      { title = "ADEMode" }
    )
    try_write_snapshot(cwd, "ADEMode")
    return
  end

  local mode_state = mode.read(cwd)
  vim.notify(
    string.format(
      "ADE mode: %s\nRoles: %s\nReview: %s\nWorktrees: %s",
      mode_state.explicit and mode_state.mode or (mode_state.mode .. " (default)"),
      mode_state.description.roles,
      mode_state.description.review,
      mode_state.description.worktrees
    ),
    vim.log.levels.INFO,
    { title = "ADEMode" }
  )
end

return M
