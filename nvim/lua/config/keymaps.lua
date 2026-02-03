-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Save with leader+w (in addition to default Ctrl+s)
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })

-- Quit with leader+q
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })

-- Copilot keymaps (Alt+l to accept) — uses copilot.lua API
map("i", "<M-l>", function()
  local copilot = require("copilot.suggestion")
  if copilot.is_visible() then
    copilot.accept()
  end
end, { desc = "Copilot Accept" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear Search Highlight" })

-- Better indenting (stay in visual mode)
map("v", "<", "<gv")
map("v", ">", ">gv")
