local function open_tree_on_startup()
  if vim.o.diff or vim.fn.argc() ~= 1 then
    return
  end

  local first_arg = vim.fn.argv(0)
  if first_arg == "" or vim.fn.isdirectory(first_arg) ~= 1 then
    return
  end

  vim.cmd.cd(first_arg)
  vim.cmd.enew()
  require("nvim-tree.api").tree.open()
end

local function open_node_in_tab_or_toggle_dir()
  local api = require("nvim-tree.api")
  local node = api.tree.get_node_under_cursor()

  if not node then
    return
  end

  if node.type == "directory" then
    api.node.open.edit(node)
    return
  end

  api.node.open.tab_drop(node)
end

local function tree_on_attach(bufnr)
  local api = require("nvim-tree.api")

  api.config.mappings.default_on_attach(bufnr)

  local function opts(desc)
    return {
      buffer = bufnr,
      desc = "nvim-tree: " .. desc,
      noremap = true,
      nowait = true,
      silent = true,
    }
  end

  vim.keymap.set("n", "<CR>", open_node_in_tab_or_toggle_dir, opts("Open: Tab / Toggle Dir"))
  vim.keymap.set("n", "o", open_node_in_tab_or_toggle_dir, opts("Open: Tab / Toggle Dir"))
  vim.keymap.set("n", "<2-LeftMouse>", open_node_in_tab_or_toggle_dir, opts("Open: Tab / Toggle Dir"))
end

return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  {
    "echasnovski/mini.bufremove",
    lazy = false,
    opts = {},
  },
  {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "VeryLazy",
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 300,
      },
      signcolumn = true,
    },
  },
  {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      hijack_cursor = false,
      on_attach = tree_on_attach,
      sync_root_with_cwd = true,
      tab = {
        sync = {
          open = true,
        },
      },
      git = {
        enable = false,
      },
      diagnostics = {
        enable = false,
      },
      update_focused_file = {
        enable = true,
        update_root = false,
      },
      view = {
        side = "left",
        signcolumn = "no",
        width = 30,
      },
      renderer = {
        group_empty = true,
        highlight_opened_files = "name",
        indent_width = 1,
        root_folder_label = false,
        icons = {
          show = {
            git = false,
          },
        },
      },
      actions = {
        open_file = {
          quit_on_open = false,
          resize_window = false,
          window_picker = {
            enable = false,
          },
        },
      },
      filters = {
        dotfiles = false,
      },
    },
    config = function(_, opts)
      require("nvim-tree").setup(opts)

      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          vim.schedule(open_tree_on_startup)
        end,
      })
    end,
  },
}
