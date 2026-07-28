local opt = vim.opt

-- Early performance settings
vim.o.background = 'dark'
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.editorconfig = false
vim.g.loaded_man = 1
vim.g.loaded_osc52 = 1
vim.g.loaded_remote_plugins = 1
vim.g.loaded_spellfile_plugin = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_tutor_mode_plugin = 1
vim.g.loaded_zipPlugin = 1

-- Batch all simple options in one pass (each vim.opt set has overhead)
vim.schedule(function()
  vim.o.clipboard = "unnamedplus"
end)

local o = vim.o
o.completeopt = "menu,menuone,noselect"
o.confirm = true
o.cursorline = true
o.cursorlineopt = "number"
o.equalalways = false
o.expandtab = true
o.fillchars = "eob: "
o.hidden = true
o.hlsearch = false
o.ignorecase = true
o.incsearch = true
o.laststatus = 3
o.mouse = "a"
o.number = true
o.relativenumber = true
o.shiftwidth = 2
o.showmode = false
o.smartcase = true
o.smartindent = true
o.softtabstop = 2
o.splitbelow = true
o.splitright = true
o.swapfile = false
o.tabstop = 2
o.termguicolors = true
o.timeoutlen = 200
o.ttimeoutlen = 10
o.undofile = true
o.updatetime = 120
o.winminwidth = 5
o.wrap = false
o.lazyredraw = false
o.synmaxcol = 300
o.maxmempattern = 20000
o.redrawtime = 1500
o.maxfuncdepth = 100
o.switchbuf = "useopen"
vim.opt.shortmess:append("cC")
o.title = false
o.spell = false
o.startofline = true
o.regexpengine = 0
vim.opt.diffopt:append("algorithm:patience")
o.jumpoptions = "stack"
o.maxmapdepth = 1000
o.showcmd = false
o.cmdheight = 0
o.ruler = false
o.numberwidth = 2
o.signcolumn = "yes:1"
o.showtabline = 2
o.pumblend = 0
o.winblend = 0
o.bufhidden = "hide"
o.eadirection = "hor"
o.previewheight = 5
o.linebreak = false
o.breakindent = false
o.writebackup = false
o.backup = false
o.autochdir = false
o.autoread = true
o.autowrite = false
o.undoreload = 10000
o.updatecount = 0
o.fsync = false
o.errorbells = false
o.visualbell = false
o.sidescroll = 1
o.sidescrolloff = 0
o.joinspaces = false
o.nrformats = "bin"
o.textwidth = 0
o.wrapmargin = 0
o.modeline = false
o.modelines = 0
o.history = 500
o.pumheight = 6
o.pumwidth = 12
o.helpheight = 10
o.cmdwinheight = 4
o.scrolljump = 8
o.scrolloff = 1

-- Options that need array/table values
opt.backupskip = opt.backupskip + "*"
opt.formatoptions = opt.formatoptions - "a" - "o" + "j"
opt.sessionoptions = "buffers,curdir,folds,help,tabpages,localoptions"
opt.viewoptions = "cursor,folds,options"
opt.shada = [['20,<20,s10,h]] -- Smaller persistent history to reduce startup I/O

if vim.fn.exists("&winborder") == 1 then
  vim.o.winborder = "single"
end

-- Defer diagnostic setup
vim.schedule(function()
  vim.diagnostic.config({
    float = { border = "single", source = "if_many" },
    severity_sort = true,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = " ",
        [vim.diagnostic.severity.WARN] = " ",
        [vim.diagnostic.severity.INFO] = " ",
        [vim.diagnostic.severity.HINT] = " ",
      },
    },
    underline = true,
    update_in_insert = false,
    virtual_text = false,
  })
end)
