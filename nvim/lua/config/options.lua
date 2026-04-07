local opt = vim.opt

-- Early performance settings
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Batch all simple options in one pass (each vim.opt set has overhead)
-- Use raw :set commands for maximum speed
vim.cmd([[
  set clipboard=unnamedplus
  set completeopt=menu,menuone,noselect
  set confirm
  set cursorline
  set cursorlineopt=number
  set noequalalways
  set expandtab
  set fillchars=eob:\ 
  set hidden
  set nohlsearch
  set ignorecase
  set incsearch
  set laststatus=3
  set mouse=a
  set number
  set relativenumber
  set shiftwidth=2
  set noshowmode
  set smartcase
  set smartindent
  set softtabstop=2
  set splitbelow
  set splitright
  set noswapfile
  set tabstop=2
  set termguicolors
  set timeoutlen=300
  set undofile
  set updatetime=120
  set winminwidth=5
  set nowrap
  set nolazyredraw
  set synmaxcol=300
  set maxmempattern=20000
  set redrawtime=1500
  set maxfuncdepth=100
  set switchbuf=useopen
  set shortmess+=cC
  set notitle
  set nospell
  set startofline
  set regexpengine=0
  set diffopt+=algorithm:patience
  set jumpoptions=stack
  set maxmapdepth=1000
  set noshowcmd
  set cmdheight=0
  set laststatus=3
  set noruler
  set numberwidth=2
  set signcolumn=yes:1
  set pumblend=0
  set winblend=0
  set bufhidden=hide
  set eadirection=hor
  set previewheight=5
  set nolinebreak
  set nobreakindent
  set nowritebackup
  set nobackup
  set noautochdir
  set autoread
  set noautowrite
  set undoreload=10000
  set updatecount=0
  set nofsync
  set noerrorbells
  set novisualbell
  set sidescroll=1
  set sidescrolloff=0
  set nojoinspaces
  set nrformats=bin
  set textwidth=0
  set wrapmargin=0
  set nomodeline
  set modelines=0
  set history=500
  set pumheight=6
  set pumwidth=12
  set helpheight=10
  set cmdwinheight=4
  set scrolljump=8
  set scrolloff=1
]])

-- Options that need array/table values (can't use :set easily)
opt.backupskip = opt.backupskip + "*"
opt.formatoptions = opt.formatoptions - "a" - "o" + "j"
opt.sessionoptions = "buffers,curdir,folds,help,tabpages,localoptions"
opt.viewoptions = "cursor,folds,options"

-- Defer tabline and diagnostic setup
vim.schedule(function()
  opt.tabline = "%!v:lua.require'config.statusline'.tabline()"
  vim.diagnostic.config({
    float = { border = "rounded", source = "if_many" },
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
