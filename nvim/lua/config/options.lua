-- Options are automatically loaded before lazy.nvim startup
-- Only overrides of LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt

-- UI
opt.colorcolumn = "100"
opt.scrolloff = 8 -- LazyVim default is 4
opt.sidescrolloff = 8

-- Tabs
opt.tabstop = 2
opt.shiftwidth = 2

-- Auto-reload files (for external tools like Pi)
opt.autoread = true

-- No line wrapping
opt.wrap = false

-- Faster updates (for CursorHold events, git signs, etc.)
opt.updatetime = 250

-- Faster which-key popup
opt.timeoutlen = 300

-- Better completion experience
opt.completeopt = "menu,menuone,noselect"
