vim.g.mapleader = " "
vim.g.maplocalleader = " "

if vim.loader and vim.loader.enable then
  vim.loader.enable()
end

require("config.options")
vim.cmd.colorscheme("habamax")
require("config.autocmds")

vim.api.nvim_create_user_command("PackUpdate", function()
  vim.pack.update()
end, { desc = "Update vim.pack plugins" })

vim.api.nvim_create_user_command("EtabliDoctor", function()
  require("config.doctor").show()
end, { desc = "Diagnose Etabli Neovim setup" })

local function lazy_cmd(name, module, fn, opts)
  vim.api.nvim_create_user_command(name, function(cmd_opts)
    require(module)[fn](cmd_opts)
  end, opts or {})
end

lazy_cmd("CopilotStatus", "config.copilot", "status", { desc = "Show native Copilot LSP status" })
lazy_cmd("CopilotEnable", "config.copilot", "enable_command", { desc = "Enable Copilot inline completion for the current cwd" })
lazy_cmd("CopilotDisable", "config.copilot", "disable_command", { desc = "Disable Copilot inline completion for the current cwd" })
lazy_cmd("CopilotToggle", "config.copilot", "toggle", { desc = "Toggle Copilot inline completion for the current cwd" })
lazy_cmd("ProjectInfo", "config.project_runtime", "project_info", {})
lazy_cmd("PI", "config.project_runtime", "project_info", {})

lazy_cmd("ReviewInbox", "config.review.hunk_flow", "cmd_open_inbox", {
  complete = function()
    return { "all" }
  end,
  desc = "Open the Hunk review inbox", nargs = "?",
})
lazy_cmd("ReviewCurrentHunk", "config.review.hunk_flow", "show_current_hunk", { desc = "Focus the current line in Hunk review" })
lazy_cmd("ReviewAnnotate", "config.review.hunk_flow", "cmd_annotate", { desc = "Comment the current review line or range", range = true })
lazy_cmd("ReviewHunk", "config.review.hunk_flow", "cmd_open_hunk", {
  complete = function() return { "diff", "diff --watch", "show", "show HEAD" } end,
  desc = "Open Hunk diff viewer", nargs = "*",
})
lazy_cmd("ReviewHunkNextComment", "config.review.hunk_flow", "cmd_hunk_next_comment", {
  desc = "Move Hunk to the next review comment",
})
lazy_cmd("ReviewHunkPrevComment", "config.review.hunk_flow", "cmd_hunk_prev_comment", {
  desc = "Move Hunk to the previous review comment",
})
lazy_cmd("ReviewHelp", "config.review.hunk_flow", "cmd_help", {
  desc = "Show Hunk review workflow help",
})
lazy_cmd("ReviewContext", "config.review.hunk_flow", "open_context_rail", {
  desc = "Open the Hunk review context rail",
})
lazy_cmd("ReviewClaudeReview", "config.review.hunk_flow", "cmd_claude_review", {
  complete = function()
    return { "all", "changed-only" }
  end,
  desc = "Launch Claude for a first-pass Hunk code review", nargs = "?",
})
lazy_cmd("ReviewPiReview", "config.review.hunk_flow", "cmd_pi_review", {
  complete = function()
    return { "all", "changed-only" }
  end,
  desc = "Launch Pi for a first-pass Hunk code review", nargs = "?",
})

-- Priority 1: keymaps needed for immediate editing
vim.schedule(function()
  require("config.keymaps")
end)

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    require("config.projects").setup()
    require("config.project_runtime").setup()
  end,
})

require("config.pack").setup()
