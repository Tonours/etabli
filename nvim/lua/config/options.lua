local opt = vim.opt

-- Early performance settings
vim.g.loaded_python3_provider = 0 -- Disable Python 3 provider (speeds up startup)
vim.g.loaded_ruby_provider = 0    -- Disable Ruby provider
vim.g.loaded_perl_provider = 0    -- Disable Perl provider
vim.g.loaded_node_provider = 0    -- Disable Node provider

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
opt.relativenumber = true
opt.shiftwidth = 2
opt.showmode = false
opt.smartcase = true
opt.smartindent = true
opt.softtabstop = 2
opt.splitbelow = true
opt.splitright = true
opt.swapfile = false
opt.tabstop = 2

-- Defer tabline setup to avoid loading statusline at startup
vim.schedule(function()
  opt.tabline = "%!v:lua.require'config.statusline'.tabline()"
end)

-- Defer diagnostic config to avoid slowing startup
vim.schedule(function()
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
end)
opt.termguicolors = true
opt.timeoutlen = 300
opt.undofile = true
opt.updatetime = 120 -- Reduced from 150ms for better responsiveness
opt.winminwidth = 5
opt.wrap = false

-- Performance optimizations
opt.lazyredraw = false
opt.synmaxcol = 300
opt.maxmempattern = 20000
opt.redrawtime = 1500
opt.maxfuncdepth = 100
opt.switchbuf = "useopen"
opt.shortmess:append("cC") -- Reduce completion messages
opt.title = false -- Disable title setting for performance
opt.spell = false -- Disable spell checking by default
opt.startofline = false -- Keep cursor column when jumping

-- Additional performance settings
opt.regexpengine = 0 -- Use NFA regex engine (auto-select fastest)
opt.diffopt:append("algorithm:patience") -- Faster diff algorithm
opt.jumpoptions = "stack" -- Optimize jump list behavior
opt.maxmapdepth = 1000 -- Limit macro recursion depth

-- More performance optimizations
opt.cursorlineopt = "number" -- Only highlight line number, not entire line
opt.showcmd = false -- Don't show command in status line (reduces redraws)
opt.cmdheight = 0 -- Hide command line when not in use (Neovim 0.8+)
opt.laststatus = 3 -- Global statusline (reduces redraws vs per-window)
opt.ruler = false -- Disable ruler (reduces redraws, use statusline instead)
opt.numberwidth = 2 -- Minimum number column width (reduces calculations)
opt.signcolumn = "yes:1" -- Fixed sign column width (reduces layout recalc)
opt.pumblend = 0 -- Disable popup menu transparency (faster rendering)
opt.winblend = 0 -- Disable window transparency (faster rendering)
opt.bufhidden = "hide" -- Hide buffers instead of unloading (faster switching)
opt.eadirection = "hor" -- Only resize horizontal splits (faster)
opt.previewheight = 5 -- Smaller preview window (less rendering)
opt.linebreak = false -- Disable line break (faster rendering)
opt.breakindent = false -- Disable break indent (faster rendering)

-- Additional performance optimizations
-- Batch formatoptions modifications for better performance
opt.formatoptions = opt.formatoptions - "a" - "o" + "j" -- Disable auto-formatting, comment continuation; enable join comment removal
opt.writebackup = false -- Disable write backup (faster writes)
opt.backup = false -- Disable backup (faster writes)
opt.backupskip = opt.backupskip + "*" -- Skip backup for all files
opt.autochdir = false -- Don't auto-change directory (expensive)
opt.autoread = true -- Auto-reload changed files (avoids manual checks)
opt.autowrite = false -- Don't auto-write (can be slow)
opt.undoreload = 10000 -- Limit undo reload for large files
opt.updatecount = 0 -- Disable swap file update count (use time-based instead)
opt.fsync = false -- Disable fsync for faster writes

-- Micro-optimizations for faster UI
opt.sessionoptions = "buffers,curdir,folds,help,tabpages,localoptions" -- Minimal session options
opt.viewoptions = "cursor,folds,options" -- Minimal view options

-- Additional micro-optimizations
opt.pumheight = 6 -- Smaller popup menu (faster rendering, was 8)
opt.pumwidth = 12 -- Minimum popup width (was 15)
opt.helpheight = 10 -- Smaller help window (was 12)
opt.cmdwinheight = 4 -- Smaller command-line window (was 5)
opt.scrolljump = 8 -- Faster scrolling (was 6)
opt.scrolloff = 1 -- Smaller scrolloff for faster rendering (was 2)

-- Extra micro-optimizations for faster startup and runtime
opt.errorbells = false -- Disable error bells
opt.visualbell = false -- Disable visual bell
opt.sidescroll = 1 -- Minimal sideways scroll
opt.sidescrolloff = 0 -- No side scroll offset
opt.joinspaces = false -- Single space after join
opt.nrformats = "bin" -- Only binary number formats (faster increment)
opt.textwidth = 0 -- Disable auto text width
opt.wrapmargin = 0 -- Disable wrap margin

-- Security + performance: disable modeline (can execute arbitrary code)
opt.modeline = false
opt.modelines = 0

-- Reduce history to minimum needed
opt.history = 50 -- Command history (default 10000, reduced for speed)

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
