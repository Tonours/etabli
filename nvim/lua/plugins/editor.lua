local function open_node_in_tab_or_toggle_dir()
  -- Lazy-load nvim-tree API only when needed
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    return
  end

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
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {},
  },
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  {
    "echasnovski/mini.bufremove",
    keys = {
      { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Delete buffer" },
      { "<leader>bD", function() require("mini.bufremove").delete(0, true) end, desc = "Delete buffer (force)" },
    },
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
        delay = 1000,
        ignore_whitespace = true,
      },
      signcolumn = true,
      numhl = false,
      linehl = false,
      word_diff = false,
      -- Performance optimizations
      max_file_length = 4000, -- Reduced from 6000
      update_debounce = 1500, -- Increased from 1000ms
      attach_to_untracked = false,
      preview_config = {
        border = "rounded",
        style = "minimal",
        relative = "cursor",
        row = 0,
        col = 1,
      },
      watch_gitdir = {
        interval = 5000, -- Increased from 3000ms
        follow_files = true,
      },
      sign_priority = 6,
      -- Additional performance: reduce internal operations
      trouble = false, -- Disable trouble integration
    },
  },
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeOpen", "NvimTreeFocus", "NvimTreeFindFile" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file explorer" },
      { "<leader>fE", "<cmd>NvimTreeFindFile<cr>", desc = "Find file in explorer" },
    },
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
        debounce_delay = 10, -- Reduced debounce (was 15ms)
      },
      view = {
        side = "right",
        signcolumn = "no",
        width = 30,
        preserve_window_proportions = true,
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
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          -- Skip if in diff mode or no args
          if vim.o.diff or vim.fn.argc() ~= 1 then
            return
          end

          local first_arg = vim.fn.argv(0)
          -- Early return for empty or non-directory args
          if first_arg == "" then
            return
          end

          local stat = vim.uv.fs_stat(first_arg)
          if not stat or stat.type ~= "directory" then
            return
          end

          -- Use schedule for immediate deferred execution
          vim.schedule(function()
            vim.cmd.cd(first_arg)
            vim.cmd.enew()
            local ok, api = pcall(require, "nvim-tree.api")
            if ok then
              api.tree.open()
              vim.schedule(function()
                pcall(api.tree.resize, 30)
              end)
            end
          end)
        end,
      })
    end,
    config = function(_, opts)
      require("nvim-tree").setup(opts)

      local group = vim.api.nvim_create_augroup("etabli_nvim_tree_width", { clear = true })

      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "NvimTree",
        callback = function(args)
          local win = vim.fn.bufwinid(args.buf)
          if win == -1 or vim.api.nvim_win_get_width(win) == opts.view.width then
            return
          end

          vim.api.nvim_win_set_width(win, opts.view.width)
        end,
      })
    end,
  },
}
