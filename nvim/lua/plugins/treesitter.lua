return {
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPre", "BufNewFile" },
    build = ":TSUpdate",
    init = function()
      -- Batch filetype registrations for better performance
      vim.filetype.add({
        extension = {
          hbs = "handlebars",
        },
      })

      -- Defer language registration to not block startup
      vim.schedule(function()
        -- Register glimmer for handlebars variants in one call
        local lang = "glimmer"
        vim.treesitter.language.register(lang, { "hbs", "handlebars" })
      end)
    end,
    config = function()
      require("nvim-treesitter").setup()

      -- Performance: Disable treesitter for large files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "javascript.glimmer", "typescript.glimmer" },
        callback = function(args)
          -- Skip treesitter for large files
          if vim.b[args.buf].large_file then
            return
          end
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
              pcall(vim.treesitter.start, args.buf, "glimmer")
            end
          end)
        end,
      })

      -- Disable treesitter highlight for large files
      vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(args)
          if vim.b[args.buf].large_file then
            vim.treesitter.stop(args.buf)
          end
        end,
      })
    end,
  },
}
