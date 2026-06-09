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
    vim.list_extend(choices, require("config.review.items").filters())
    table.insert(choices, 1, "all")
    return choices
  end,
  desc = "Open the Hunk review inbox", nargs = "?",
})
lazy_cmd("ReviewLegacyInbox", "config.review", "cmd_open_legacy_inbox", {
  complete = function()
    local choices = require("config.review.state").statuses()
    vim.list_extend(choices, require("config.review.items").filters())
    table.insert(choices, 1, "all")
    return choices
  end,
  desc = "Open the legacy local review inbox", nargs = "?",
})
lazy_cmd("ReviewCurrentHunk", "config.review", "show_current_hunk", { desc = "Focus the current line in Hunk review" })
lazy_cmd("ReviewLegacyCurrentHunk", "config.review", "cmd_show_legacy_current_hunk", {
  desc = "Preview the current review hunk with legacy local state",
})
lazy_cmd("ReviewAnnotate", "config.review", "cmd_annotate", { desc = "Comment the current review line or range", range = true })
lazy_cmd("ReviewResolve", "config.review", "cmd_resolve_comment", { desc = "Resolve the current review conversation" })
lazy_cmd("ReviewStatus", "config.review", "cmd_set_status", {
  complete = function() return require("config.review.state").statuses() end,
  desc = "Set the review status for the current hunk", nargs = "?",
})
lazy_cmd("ReviewAccept", "config.review", "accept_current_hunk", { desc = "Accept the current review hunk" })
lazy_cmd("ReviewMarkReviewed", "config.review", "cmd_mark_reviewed", {
  complete = function() return { "on", "off", "toggle" } end,
  desc = "Mark the current review hunk as reviewed", nargs = "?",
})
lazy_cmd("ReviewStart", "config.review", "cmd_start_transaction", { desc = "Start a local draft review transaction" })
lazy_cmd("ReviewPreview", "config.review", "cmd_preview_transaction", { desc = "Preview the active draft review transaction" })
lazy_cmd("ReviewSubmit", "config.review", "cmd_submit_transaction", {
  complete = function() return { "comment", "approve", "request-changes" } end,
  desc = "Submit the active draft review transaction locally", nargs = "?",
})
lazy_cmd("ReviewExport", "config.review", "cmd_export_transaction", {
  complete = function() return { "markdown", "json" } end,
  desc = "Export the active draft review transaction", nargs = "?",
})
lazy_cmd("ReviewInlineAnnotations", "config.review", "cmd_inline_annotations", {
  complete = function() return { "on", "off", "refresh", "toggle", "expand", "compact" } end,
  desc = "Toggle review inline annotations", nargs = "?",
})
lazy_cmd("ReviewHunk", "config.review", "cmd_open_hunk", {
  complete = function() return { "diff", "diff --watch", "show", "show HEAD" } end,
  desc = "Open Hunk diff viewer", nargs = "*",
})
lazy_cmd("ReviewHunkSync", "config.review", "cmd_sync_hunk", {
  complete = function() return { "push", "pull", "both" } end,
  desc = "Synchronize local review notes with the live Hunk session", nargs = "?",
})
lazy_cmd("ReviewClaude", "config.review", "cmd_send_claude", {
  complete = function() return { "revise", "explain", "review" } end,
  desc = "Send the current hunk review prompt to Claude", nargs = "?",
})
lazy_cmd("ReviewPi", "config.review", "cmd_send_pi", {
  complete = function() return { "revise", "explain", "review" } end,
  desc = "Send the current hunk review prompt to Pi", nargs = "?",
})
lazy_cmd("ReviewIngestClaude", "config.review", "cmd_ingest_claude", {
  complete = "file",
  desc = "Import structured Claude review findings", nargs = "?",
})
lazy_cmd("ReviewIngestPi", "config.review", "cmd_ingest_pi", {
  complete = "file",
  desc = "Import structured Pi review findings", nargs = "?",
})
lazy_cmd("ReviewCompareAgents", "config.review", "cmd_compare_agents", {
  desc = "Compare Pi and Claude findings for the current review hunk",
})
lazy_cmd("ReviewSuggestionPreview", "config.review", "cmd_preview_suggestion", {
  desc = "Safely preview a suggested change for the current review hunk",
})
lazy_cmd("ReviewSuggestionStatus", "config.review", "cmd_suggestion_status", {
  complete = function() return { "open", "applied", "rejected", "resolved" } end,
  desc = "Set the selected suggested change status", nargs = "?",
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
    table.insert(choices, 2, "changed-only")
    return choices
  end,
  desc = "Launch Claude for a first-pass Hunk code review", nargs = "?",
})
lazy_cmd("ReviewPiReview", "config.review", "cmd_pi_review", {
  complete = function()
    local choices = require("config.review.state").statuses()
    table.insert(choices, 1, "all")
    table.insert(choices, 2, "changed-only")
    return choices
  end,
  desc = "Launch Pi for a first-pass Hunk code review", nargs = "?",
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
