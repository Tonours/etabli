vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.bootstrap")
require("config.options")
require("config.autocmds")
require("config.projects").setup()
require("config.project_runtime").setup()
require("config.review").setup()
require("config.keymaps")

require("lazy").setup("plugins", {
  defaults = {
    lazy = true,
    version = false,
  },
  install = {
    colorscheme = { "catppuccin" },
  },
  checker = {
    enabled = false,
  },
  change_detection = {
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
