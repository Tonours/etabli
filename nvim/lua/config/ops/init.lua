local actions = require("config.ops.actions")
local mode = require("config.ops.mode")
local snapshot = require("config.ops.snapshot")
local state = require("config.ops.state")
local view = require("config.ops.view")
local tilldone = require("config.ops.tilldone")

local M = {}
local commands_registered = false
local focus_refresh_ttl = 1500
local last_focus_refresh_at = 0

local function refresh_runtime(cause)
  if cause == "focus" then
    local now = vim.uv.now()
    if (now - last_focus_refresh_at) < focus_refresh_ttl then
      return
    end

    last_focus_refresh_at = now
  end

  state.invalidate()
  snapshot.schedule_write(vim.fn.getcwd())
end

M.info_lines = view.info_lines
M.project_info_lines = view.project_info_lines
M.next_lines = view.next_lines
M.resume_lines = view.resume_lines
M.statusline_label = view.statusline_label
M.statusline_color = view.statusline_color
M.show_status = actions.show_status
M.show_next = actions.show_next
M.refresh_review = actions.refresh_review
M.open_plan = actions.open_plan
M.open_review = actions.open_review
M.open_handoff = actions.open_handoff
M.resume = actions.resume
M.show_doctor = actions.show_doctor
M.show_mode = actions.show_mode
M.set_mode_simple = actions.set_mode_simple
M.set_mode_standard = actions.set_mode_standard
M.show_tilldone = tilldone.show_float

function M.setup_commands()
  if commands_registered then
    return
  end

  commands_registered = true

  vim.api.nvim_create_user_command("OPSStatus", function()
    M.show_status()
  end, { desc = "Show OPS plan/runtime/review status" })

  vim.api.nvim_create_user_command("OPS", function()
    M.show_status()
  end, { desc = "Show OPS plan/runtime/review status" })

  vim.api.nvim_create_user_command("OPSNext", function()
    M.show_next()
  end, { desc = "Show the next OPS action" })

  vim.api.nvim_create_user_command("OPSOpenPlan", function()
    M.open_plan()
  end, { desc = "Open PLAN.md for the current cwd" })

  vim.api.nvim_create_user_command("OPSReview", function()
    M.open_review()
  end, { desc = "Open the review inbox for the current cwd" })

  vim.api.nvim_create_user_command("OPSHandoff", function()
    M.open_handoff()
  end, { desc = "Open the current OPS handoff file" })

  vim.api.nvim_create_user_command("OPSRefreshReview", function()
    M.refresh_review()
  end, { desc = "Refresh live OPS review state" })

  vim.api.nvim_create_user_command("OPSDoctor", function()
    M.show_doctor()
  end, { desc = "Diagnose OPS plumbing for the current cwd" })

  vim.api.nvim_create_user_command("OPSResume", function()
    M.resume()
  end, { desc = "Resume the current cwd context" })

  vim.api.nvim_create_user_command("OPSMode", function(opts)
    M.show_mode(opts.args)
  end, {
    desc = "Show or set the OPS operating mode",
    nargs = "?",
    complete = function()
      return mode.modes()
    end,
  })

  vim.api.nvim_create_user_command("OPSModeSimple", function()
    M.set_mode_simple()
  end, { desc = "Set OPS mode to simple (main + worker)" })

  vim.api.nvim_create_user_command("OPSModeStandard", function()
    M.set_mode_standard()
  end, { desc = "Set OPS mode to standard (main + scout + worker + reviewer)" })

  vim.api.nvim_create_user_command("OPSTillDone", function()
    tilldone.show_float()
  end, { desc = "Show TillDone tasks from Pi" })

  vim.api.nvim_create_user_command("TillDoneNext", function()
    tilldone.show_next_action()
  end, { desc = "Show next action from TillDone and OPS" })

  local group = vim.api.nvim_create_augroup("etabli_ops_runtime", { clear = true })
  vim.api.nvim_create_autocmd({ "DirChanged", "BufWritePost" }, {
    group = group,
    pattern = { "*" },
    callback = function()
      refresh_runtime("event")
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    pattern = { "*" },
    callback = function()
      refresh_runtime("focus")
    end,
  })

  snapshot.schedule_write(vim.fn.getcwd())
end

return M
