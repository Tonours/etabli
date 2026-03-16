return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.astro = { "prettier_astro" }

      opts.formatters = opts.formatters or {}
      opts.formatters.prettier_astro = {
        inherit = "prettier",
        append_args = { "--plugin", "prettier-plugin-astro" },
        condition = function(_, ctx)
          return vim.fs.find("node_modules/prettier-plugin-astro/package.json", {
            path = ctx.dirname,
            upward = true,
          })[1] ~= nil
        end,
      }
    end,
  },
}
