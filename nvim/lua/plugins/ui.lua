return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    version = "ebd667671917",
    cmd = "Neotree",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    init = function()
      require("config.neo_tree").setup_autocmds()
    end,
    opts = {
      close_if_last_window = false,
      enable_diagnostics = false,
      enable_git_status = true,
      filesystem = {
        bind_to_cwd = false,
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
        },
        follow_current_file = {
          enabled = true,
          leave_dirs_open = false,
        },
        hijack_netrw_behavior = "open_default",
        use_libuv_file_watcher = true,
      },
      popup_border_style = "single",
      sources = { "filesystem" },
      window = {
        position = "right",
        width = 34,
        mappings = {
          ["<space>"] = "none",
        },
      },
    },
  },
  {
    "akinsho/bufferline.nvim",
    version = "v4.9.1",
    event = "VeryLazy",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      options = {
        always_show_bufferline = true,
        diagnostics = false,
        mode = "buffers",
        numbers = "none",
        separator_style = "thin",
        show_buffer_close_icons = false,
        show_close_icon = false,
        offsets = {
          {
            filetype = "neo-tree",
            text = "files",
            text_align = "left",
            separator = true,
          },
        },
      },
    },
  },
}
