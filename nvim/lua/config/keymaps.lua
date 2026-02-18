-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- LazyVim already provides: <C-s> save, <leader>qq quit, <Esc> nohlsearch, visual </>

local map = vim.keymap.set

-- Copilot keymaps (Alt+l to accept) — uses copilot.lua API
map("i", "<M-l>", function()
  local copilot = require("copilot.suggestion")
  if copilot.is_visible() then
    copilot.accept()
  end
end, { desc = "Copilot Accept" })
