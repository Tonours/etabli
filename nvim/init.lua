vim.g.mapleader = " "
vim.g.maplocalleader = " "

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
require("config.project_runtime").setup_commands()

local function lazy_cmd(name, module, fn, opts)
  vim.api.nvim_create_user_command(name, function(cmd_opts)
    require(module)[fn](cmd_opts)
  end, opts or {})
end

lazy_cmd("OPSStatus", "config.ops", "show_status", { desc = "Show OPS plan/runtime/review status" })
lazy_cmd("OPS", "config.ops", "show_status", { desc = "Show OPS plan/runtime/review status" })
lazy_cmd("OPSNext", "config.ops", "show_next", { desc = "Show the next OPS action" })
lazy_cmd("OPSOpenPlan", "config.ops", "open_plan", { desc = "Open PLAN.md for the current cwd" })
lazy_cmd("OPSReview", "config.ops", "open_review", { desc = "Open the review inbox for the current cwd" })
lazy_cmd("OPSHandoff", "config.ops", "open_handoff", { desc = "Open the current OPS handoff file" })
lazy_cmd("OPSRefreshReview", "config.ops", "refresh_review", { desc = "Refresh live OPS review state" })
lazy_cmd("OPSDoctor", "config.ops", "show_doctor", { desc = "Diagnose OPS plumbing for the current cwd" })
lazy_cmd("OPSResume", "config.ops", "resume", { desc = "Resume the current cwd context" })
lazy_cmd("OPSMode", "config.ops", "show_mode", {
  desc = "Show or set the OPS operating mode", nargs = "?",
  complete = function() return require("config.ops.mode").modes() end,
})
lazy_cmd("OPSModeSimple", "config.ops", "set_mode_simple", { desc = "Set OPS mode to simple (main + worker)" })
lazy_cmd("OPSModeStandard", "config.ops", "set_mode_standard", { desc = "Set OPS mode to standard (main + scout + worker + reviewer)" })
lazy_cmd("OPSTillDone", "config.ops", "show_tilldone", { desc = "Show TillDone tasks from Pi" })
lazy_cmd("TillDoneNext", "config.ops", "show_tilldone_next", { desc = "Show next action from TillDone and OPS" })

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

local function load_catppuccin()
  if vim.g.etabli_catppuccin_loaded then
    return
  end

  local ok, lazy = pcall(require, "lazy")
  if not ok then
    return
  end

  lazy.load({ plugins = { "catppuccin" } })
  vim.g.etabli_catppuccin_loaded = true
end

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
    require("config.ops").setup_runtime()
    require("config.review").setup()
  end,
})

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

if #vim.api.nvim_list_uis() == 0 then
  load_catppuccin()
else
  vim.api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = load_catppuccin,
  })
end
