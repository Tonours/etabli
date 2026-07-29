local M = {}

function M.setup()
  local pack = require("config.pack")
  if not pack.load("catppuccin.nvim") then
    -- Fallback if pack not installed yet: still pin Mocha-ish base via palette.
    local p = require("config.palette")
    vim.o.background = "dark"
    vim.api.nvim_set_hl(0, "Normal", { fg = p.text, bg = p.base })
    vim.api.nvim_set_hl(0, "NormalFloat", { fg = p.text, bg = p.mantle })
    vim.api.nvim_set_hl(0, "FloatBorder", { fg = p.surface0, bg = p.mantle })
    vim.api.nvim_set_hl(0, "StatusLine", { fg = p.text, bg = p.mantle })
    vim.g.colors_name = "etabli-mocha-fallback"
    return
  end

  vim.cmd.colorscheme("catppuccin-mocha")
end

function M.colors_name()
  return vim.g.colors_name or ""
end

return M
