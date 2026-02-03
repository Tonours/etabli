-- Core LSP configuration
return {
  -- ESLint auto-fix on save
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        eslint = {},
      },
      setup = {
        eslint = function(_, opts)
          local on_attach = opts.on_attach
          opts.on_attach = function(client, bufnr)
            if on_attach then
              on_attach(client, bufnr)
            end
            if client.name == "eslint" then
              vim.api.nvim_create_autocmd("BufWritePre", {
                buffer = bufnr,
                command = "EslintFixAll",
              })
            end
          end
        end,
      },
    },
  },
}
