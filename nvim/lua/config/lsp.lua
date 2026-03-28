local M = {}

local telescope_loader = require("config.telescope")

function M.capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

  if ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end

  -- Performance: Disable features that can slow down editing
  capabilities.textDocument.completion.completionItem.snippetSupport = true

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
            -- Performance: Limit workspace analysis
            maxPreload = 2000,
            preloadFileSize = 1000,
          },
          telemetry = { enable = false },
        },
      },
    },
    tailwindcss = {},
    ts_ls = {
      -- Performance settings for TypeScript
      settings = {
        typescript = {
          preferences = {
            includeCompletionsForModuleExports = false,
            includeCompletionsWithSnippetText = false,
          },
        },
        javascript = {
          preferences = {
            includeCompletionsForModuleExports = false,
            includeCompletionsWithSnippetText = false,
          },
        },
      },
    },
    yamlls = {},
  }
end

function M.setup_keymaps()
  local group = vim.api.nvim_create_augroup("etabli_lsp_attach", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(event)
      local bufnr = event.buf

      -- Skip if buffer is large (performance)
      if vim.b[bufnr].large_file then
        -- Detach LSP for large files to prevent performance issues
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client then
          vim.lsp.buf_detach_client(bufnr, client.id)
        end
        return
      end

      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
      end

      map("gd", vim.lsp.buf.definition, "Definition")
      map("gr", function()
        local telescope = telescope_loader.require("telescope.builtin")
        if telescope then
          telescope.lsp_references()
          return
        end

        vim.lsp.buf.references()
      end, "References")
      map("gI", vim.lsp.buf.implementation, "Implementation")
      map("<leader>ci", vim.lsp.buf.implementation, "Implementation")
      map("K", vim.lsp.buf.hover, "Hover")
      map("<leader>rn", vim.lsp.buf.rename, "Rename")
      map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    end,
  })
end

return M
