-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt

-- UI
opt.relativenumber = true
opt.colorcolumn = "100"
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Tabs
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true

-- Auto-reload files (for external tools like OpenCode)
opt.autoread = true

-- Persistent undo history
opt.undofile = true

-- No line wrapping
opt.wrap = false

-- Always show sign column (prevents layout shift)
opt.signcolumn = "yes"

-- Faster updates (for CursorHold events, git signs, etc.)
opt.updatetime = 250

-- Faster which-key popup
opt.timeoutlen = 300

-- Better completion experience
opt.completeopt = "menu,menuone,noselect"

-- Split behavior
opt.splitright = true
opt.splitbelow = true
