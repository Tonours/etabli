local nvim_tree = require("config.nvim_tree")

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    -- Defer setup to not block file opening
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        once = true,
        callback = function(args)
          -- Defer render-markdown setup to allow immediate editing
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(args.buf) and vim.bo[args.buf].filetype == "markdown" then
              require("render-markdown").setup({})
              require("render-markdown").enable(args.buf)
            end
          end, 50)
        end,
      })
    end,
    -- Disable auto-setup - we handle it manually in init
    config = function() end,
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
    -- Defer loading to not block file opening
    event = "VeryLazy",
    init = function()
      -- Schedule gitsigns attach after buffer is fully loaded
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("etabli_gitsigns_lazy", { clear = true }),
        callback = function(args)
          -- Skip if not a file or special buffer
          if vim.bo[args.buf].buftype ~= "" or not vim.bo[args.buf].buflisted then
            return
          end
          -- Defer gitsigns attach by 200ms to prioritize editing responsiveness
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
              local ok, gitsigns = pcall(require, "gitsigns")
              if ok then
                gitsigns.attach(args.buf)
              end
            end
          end, 200)
        end,
      })
    end,
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
        border = { "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" },
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
    opts = function()
      return nvim_tree.opts()
    end,
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
                pcall(api.tree.resize, nvim_tree.width)
              end)
            end
          end)
        end,
      })
    end,
    config = function(_, opts)
      nvim_tree.setup(opts)
    end,
  },
}
