return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        lazy = true,
      },
    },
    opts = function()
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      local function picker_started_in_terminal(prompt_bufnr)
        local picker = action_state.get_current_picker(prompt_bufnr)
        if not picker or not picker.original_win_id or not vim.api.nvim_win_is_valid(picker.original_win_id) then
          return false
        end

        local origin_buf = vim.api.nvim_win_get_buf(picker.original_win_id)
        return vim.bo[origin_buf].buftype == "terminal"
      end

      local function open_in_tab_from_terminal(prompt_bufnr)
        if picker_started_in_terminal(prompt_bufnr) then
          actions.select_default:replace(function()
            actions.file_tab(prompt_bufnr)
          end)
        end

        return true
      end

      return {
        defaults = {
          file_ignore_patterns = {
            "node_modules/",
            "dist/",
            "coverage/",
            ".git/",
            ".cache/",
            "build/",
            "out/",
            "%.lock",
            "%-lock%.",
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
          path_display = { "truncate" },
          preview_title = false,
          prompt_prefix = "   ",
          results_title = false,
          selection_caret = " ",
          sorting_strategy = "ascending",
          -- Performance optimizations
          preview = {
            timeout = 300, -- Reduced from 400ms for faster preview
            msg_bg_fillchar = " ",
            filesize_limit = 1.0, -- Reduced from 1.5MB for faster preview
          },
          -- Reduce environment overhead
          set_env = {
            COLORTERM = "truecolor",
          },
          -- Cache results for better performance (reduced memory usage)
          cache_picker = {
            num_pickers = 3, -- Reduced from 5 for lower memory usage
            limit_entries = 75, -- Reduced from 100 for faster lookup
          },
          -- Speed up file finding
          find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
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
            attach_mappings = open_in_tab_from_terminal,
            hidden = true,
            prompt_title = "Files",
          },
          live_grep = {
            attach_mappings = open_in_tab_from_terminal,
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
