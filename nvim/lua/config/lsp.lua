local M = {}

function M.capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

  if ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end

  return capabilities
end

function M.servers()
  return {
    cssls = {},
    ember = {
      filetypes = { "hbs", "handlebars", "html.handlebars", "javascript.glimmer", "typescript.glimmer" },
    },
    html = {},
    jsonls = {},
    lua_ls = {
      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            checkThirdParty = false,
          },
        },
      },
    },
    tailwindcss = {},
    ts_ls = {},
    yamlls = {},
  }
end

function M.setup_keymaps()
  local group = vim.api.nvim_create_augroup("etabli_lsp_attach", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(event)
      local bufnr = event.buf
      local telescope = require("telescope.builtin")
      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
      end

      map("gd", vim.lsp.buf.definition, "Definition")
      map("gr", telescope.lsp_references, "References")
      map("gI", vim.lsp.buf.implementation, "Implementation")
      map("<leader>ci", vim.lsp.buf.implementation, "Implementation")
      map("K", vim.lsp.buf.hover, "Hover")
      map("<leader>rn", vim.lsp.buf.rename, "Rename")
      map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    end,
  })
end

return M
