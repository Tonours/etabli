local opt = vim.opt

opt.clipboard = "unnamedplus"
opt.completeopt = { "menu", "menuone", "noselect" }
opt.confirm = true
opt.cursorline = true
opt.equalalways = false
opt.expandtab = true
opt.fillchars = { eob = " " }
opt.hidden = true
opt.hlsearch = false
opt.ignorecase = true
opt.incsearch = true
opt.laststatus = 3
opt.mouse = "a"
opt.number = true
opt.pumheight = 10
opt.relativenumber = true
opt.scrolloff = 6
opt.sessionoptions = { "buffers", "curdir", "folds", "help", "tabpages", "localoptions" }
opt.shiftwidth = 2
opt.showmode = false
opt.signcolumn = "yes"
opt.smartcase = true
opt.smartindent = true
opt.softtabstop = 2
opt.splitbelow = true
opt.splitright = true
opt.swapfile = false
opt.tabstop = 2
opt.termguicolors = true
opt.timeoutlen = 300
opt.undofile = true
opt.updatetime = 200
opt.winminwidth = 5
opt.wrap = false

vim.diagnostic.config({
  float = {
    border = "rounded",
    source = "if_many",
  },
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.INFO] = " ",
      [vim.diagnostic.severity.HINT] = " ",
    },
  },
  underline = true,
  update_in_insert = false,
  virtual_text = false,
})

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
