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
require("config.copilot").setup_commands()
require("config.project_runtime").setup_commands()

vim.api.nvim_create_user_command("EtabliDoctor", function()
  require("config.doctor").show()
end, { desc = "Diagnose Etabli Neovim setup" })

local function lazy_cmd(name, module, fn, opts)
  vim.api.nvim_create_user_command(name, function(cmd_opts)
    require(module)[fn](cmd_opts)
  end, opts or {})
end

lazy_cmd("ReviewInbox", "config.review", "cmd_open_inbox", {
  complete = function()
    local choices = require("config.review.state").statuses()
    table.insert(choices, 1, "all")
    return choices
  end,
  desc = "Open the review inbox", nargs = "?",
})
lazy_cmd("ReviewCurrentHunk", "config.review", "show_current_hunk", { desc = "Preview the current review hunk" })
lazy_cmd("ReviewAnnotate", "config.review", "cmd_annotate", { desc = "Comment the current review line or range", range = true })
lazy_cmd("ReviewResolve", "config.review", "cmd_resolve_comment", { desc = "Resolve the current review conversation" })
lazy_cmd("ReviewStatus", "config.review", "cmd_set_status", {
  complete = function() return require("config.review.state").statuses() end,
  desc = "Set the review status for the current hunk", nargs = "?",
})
lazy_cmd("ReviewAccept", "config.review", "accept_current_hunk", { desc = "Accept the current review hunk" })
lazy_cmd("ReviewInlineAnnotations", "config.review", "cmd_inline_annotations", {
  complete = function() return { "on", "off", "refresh", "toggle" } end,
  desc = "Toggle review inline annotations", nargs = "?",
})
lazy_cmd("ReviewClaude", "config.review", "cmd_send_claude", {
  complete = function() return { "revise", "explain", "review" } end,
  desc = "Send the current hunk review prompt to Claude", nargs = "?",
})
lazy_cmd("ReviewPi", "config.review", "cmd_send_pi", {
  complete = function() return { "revise", "explain", "review" } end,
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
lazy_cmd("ReviewClaudeReview", "config.review", "cmd_claude_review", {
  complete = function()
    local choices = require("config.review.state").statuses()
    table.insert(choices, 1, "all")
    return choices
  end,
  desc = "Launch Claude for a first-pass code review", nargs = "?",
})
lazy_cmd("ReviewPiReview", "config.review", "cmd_pi_review", {
  complete = function()
    local choices = require("config.review.state").statuses()
    table.insert(choices, 1, "all")
    return choices
  end,
  desc = "Launch Pi for a first-pass code review", nargs = "?",
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
