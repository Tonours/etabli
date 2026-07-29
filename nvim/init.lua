vim.g.mapleader = " "
vim.g.maplocalleader = " "

if vim.loader and vim.loader.enable then
  vim.loader.enable()
end

require("config.options")
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
require("config.theme").setup()
