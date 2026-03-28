vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Optional: Profile startup time (set PROFILE_NVIM=1 to enable)
if vim.env.PROFILE_NVIM == "1" then
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyDone",
    callback = function()
      local stats = require("lazy").stats()
      local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
      vim.notify("Lazy loaded " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. "ms", vim.log.levels.INFO)
    end,
  })
end

require("config.bootstrap")
require("config.options")
require("config.autocmds")
require("config.review").setup()
require("config.project_runtime").setup_commands()
require("config.keymaps")

-- Defer heavy module loading to improve startup time
-- Keep review and project commands synchronous so they are always available on startup
vim.schedule(function()
  require("config.projects").setup()
  require("config.project_runtime").setup()
end)

-- Setup lazy.nvim immediately (defer_fn with 0ms adds unnecessary overhead)
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
    cache = {
      enabled = true,
    },
    reset_packpath = true,
    rtp = {
      reset = true,
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrw",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
