vim.g.mapleader = " "
vim.g.maplocalleader = " "

if vim.loader and vim.loader.enable then
  vim.loader.enable()
end

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
vim.cmd.colorscheme("habamax")
require("config.autocmds")
require("config.project_runtime").setup_commands()

local function lazy_cmd(name, module, fn, opts)
  vim.api.nvim_create_user_command(name, function(cmd_opts)
    require(module)[fn](cmd_opts)
  end, opts or {})
end

lazy_cmd("ReviewInbox", "config.review", "cmd_open_inbox", {
  complete = function() return require("config.review.state").statuses() end,
  desc = "Open the review inbox", nargs = "?",
})
lazy_cmd("ReviewCurrentHunk", "config.review", "show_current_hunk", { desc = "Preview the current review hunk" })
lazy_cmd("ReviewAnnotate", "config.review", "annotate_current_hunk", { desc = "Annotate the current review hunk" })
lazy_cmd("ReviewStatus", "config.review", "cmd_set_status", {
  complete = function() return require("config.review.state").statuses() end,
  desc = "Set the review status for the current hunk", nargs = "?",
})
lazy_cmd("ReviewAccept", "config.review", "accept_current_hunk", { desc = "Accept the current review hunk" })
lazy_cmd("ReviewClaude", "config.review", "cmd_send_claude", {
  complete = function() return { "revise", "explain" } end,
  desc = "Send the current hunk review prompt to Claude", nargs = "?",
})
lazy_cmd("ReviewPi", "config.review", "cmd_send_pi", {
  complete = function() return { "revise", "explain" } end,
  desc = "Send the current hunk review prompt to Pi", nargs = "?",
})
lazy_cmd("ReviewClaudeBatch", "config.review", "cmd_claude_batch", {
  complete = function() return require("config.review.state").statuses() end,
  desc = "Prepare one Claude prompt for all hunks with a review status", nargs = "?",
})
lazy_cmd("ReviewPiBatch", "config.review", "cmd_pi_batch", {
  complete = function() return require("config.review.state").statuses() end,
  desc = "Prepare one Pi prompt for all hunks with a review status", nargs = "?",
})

-- Priority 1: keymaps needed for immediate editing
vim.schedule(function()
  require("config.keymaps")
end)

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    require("config.projects").setup()
    require("config.project_runtime").setup()
    require("config.review").setup()
  end,
})

require("lazy").setup("plugins", {
  defaults = {
    lazy = true,
    version = false,
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
        "editorconfig",
        "man",
        "net",
        "netrw",
        "netrwPlugin",
        "osc52",
        "rplugin",
        "spellfile",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
