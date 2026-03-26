return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    init = function()
      vim.filetype.add({
        extension = {
          hbs = "handlebars",
        },
      })

      vim.treesitter.language.register("glimmer", "hbs")
      vim.treesitter.language.register("glimmer", "handlebars")
    end,
    config = function()
      require("nvim-treesitter").setup()

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "javascript.glimmer", "typescript.glimmer" },
        callback = function(args)
          pcall(vim.treesitter.start, args.buf, "glimmer")
        end,
      })
    end,
  },
}
