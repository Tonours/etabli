return {
  {
    "nvim-telescope/telescope.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
      },
    },
    opts = function()
      local actions = require("telescope.actions")

      return {
        defaults = {
          file_ignore_patterns = {
            "node_modules/",
            "dist/",
            "coverage/",
            ".git/",
          },
          layout_config = {
            prompt_position = "top",
          },
          layout_strategy = "horizontal",
          mappings = {
            i = {
              ["<Esc>"] = actions.close,
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
            },
          },
          path_display = { "smart" },
          preview_title = false,
          prompt_prefix = "   ",
          results_title = false,
          selection_caret = " ",
          sorting_strategy = "ascending",
        },
        pickers = {
          buffers = {
            ignore_current_buffer = true,
            previewer = false,
            prompt_title = "Buffers",
            sort_mru = true,
          },
          diagnostics = {
            prompt_title = "Diagnostics",
          },
          find_files = {
            hidden = true,
            prompt_title = "Files",
          },
          live_grep = {
            prompt_title = "Grep",
          },
          lsp_document_symbols = {
            prompt_title = "Symbols",
          },
          lsp_dynamic_workspace_symbols = {
            prompt_title = "Workspace Symbols",
          },
          oldfiles = {
            only_cwd = true,
            previewer = false,
            prompt_title = "Recent Files",
          },
        },
      }
    end,
    config = function(_, opts)
      local telescope = require("telescope")

      telescope.setup(opts)
      pcall(telescope.load_extension, "fzf")
    end,
  },
}
