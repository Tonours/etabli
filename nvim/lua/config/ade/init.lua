local actions = require("config.ade.actions")
local mode = require("config.ade.mode")
local snapshot = require("config.ade.snapshot")
local state = require("config.ade.state")
local view = require("config.ade.view")

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

function M.setup_commands()
  if commands_registered then
    return
  end

  commands_registered = true

  vim.api.nvim_create_user_command("ADEStatus", function()
    M.show_status()
  end, { desc = "Show ADE plan/runtime/review status" })

  vim.api.nvim_create_user_command("ADE", function()
    M.show_status()
  end, { desc = "Show ADE plan/runtime/review status" })

  vim.api.nvim_create_user_command("ADENext", function()
    M.show_next()
  end, { desc = "Show the next ADE action" })

  vim.api.nvim_create_user_command("ADEOpenPlan", function()
    M.open_plan()
  end, { desc = "Open PLAN.md for the current worktree" })

  vim.api.nvim_create_user_command("ADEReview", function()
    M.open_review()
  end, { desc = "Open the review inbox for the current worktree" })

  vim.api.nvim_create_user_command("ADEHandoff", function()
    M.open_handoff()
  end, { desc = "Open the current ADE handoff file" })

  vim.api.nvim_create_user_command("ADERefreshReview", function()
    M.refresh_review()
  end, { desc = "Refresh live ADE review state" })

  vim.api.nvim_create_user_command("ADEDoctor", function()
    M.show_doctor()
  end, { desc = "Diagnose ADE plumbing for the current worktree" })

  vim.api.nvim_create_user_command("ADEResume", function()
    M.resume()
  end, { desc = "Resume the current worktree context" })

  vim.api.nvim_create_user_command("ADEMode", function(opts)
    M.show_mode(opts.args)
  end, {
    desc = "Show or set the ADE operating mode",
    nargs = "?",
    complete = function()
      return mode.modes()
    end,
  })

  local group = vim.api.nvim_create_augroup("etabli_ade_runtime", { clear = true })
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
