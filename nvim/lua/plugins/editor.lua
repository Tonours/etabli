return {
  {
    "echasnovski/mini.bufremove",
    keys = {
      { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Delete buffer" },
      { "<leader>bD", function() require("mini.bufremove").delete(0, true) end, desc = "Delete buffer (force)" },
    },
    opts = {},
  },
  {
    "lewis6991/gitsigns.nvim",
    version = "eb60cc7b94c4",
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
        border = "single",
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
}
