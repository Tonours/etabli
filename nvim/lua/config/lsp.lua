local M = {}

local copilot = require("config.copilot")
local telescope_loader = require("config.telescope")

local glint_config_files = {
  ".glintrc.yml",
  ".glintrc",
  ".glintrc.json",
  ".glintrc.js",
  "glint.config.js",
}

local server_commands = {
  astro = "astro-ls",
  copilot = "copilot-language-server",
  cssls = "vscode-css-language-server",
  ember = "ember-language-server",
  glint = "glint-language-server",
  html = "vscode-html-language-server",
  intelephense = "intelephense",
  jsonls = "vscode-json-language-server",
  lua_ls = "lua-language-server",
  tailwindcss = "tailwindcss-language-server",
  ts_ls = "typescript-language-server",
  yamlls = "yaml-language-server",
}

local function has_glint_dependency(package_json)
  local ok_read, lines = pcall(vim.fn.readfile, package_json)
  if not ok_read then
    return false
  end

  local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode or type(decoded) ~= "table" then
    return false
  end

  for _, field in ipairs({ "dependencies", "devDependencies", "peerDependencies" }) do
    local deps = decoded[field]
    if type(deps) == "table" then
      for name in pairs(deps) do
        if type(name) == "string" and name:match("^@glint/") then
          return true
        end
      end
    end
  end

  return false
end

local function glint_root_dir(bufnr, on_dir)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local config_file = vim.fs.find(glint_config_files, {
    path = path,
    type = "file",
    upward = true,
  })[1]

  if config_file then
    on_dir(vim.fs.dirname(config_file))
    return
  end

  local package_json = vim.fs.find("package.json", {
    path = path,
    type = "file",
    upward = true,
  })[1]

  if package_json and has_glint_dependency(package_json) then
    on_dir(vim.fs.dirname(package_json))
  end
end

M.glint_root_dir = glint_root_dir

function M.server_command(name)
  return server_commands[name]
end

function M.server_is_available(name)
  local command = server_commands[name]
  return command == nil or vim.fn.executable(command) == 1
end

function M.capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

  if ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end

  capabilities.textDocument.completion.completionItem.snippetSupport = true

  return capabilities
end

function M.servers()
  return {
    astro = {},
    copilot = {
      settings = {
        telemetry = {
          telemetryLevel = "off",
        },
      },
    },
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
    tailwindcss = {
      filetypes = { "astro", "css", "html", "javascript", "javascriptreact", "scss", "typescript", "typescriptreact" },
    },
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

      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, bufnr) then
        copilot.enable_buffer(bufnr, client)

        vim.keymap.set("i", "<A-l>", copilot.accept_inline, {
          buffer = bufnr,
          silent = true,
          desc = "Accept inline completion",
        })
        vim.keymap.set({ "i", "n" }, "<A-]>", function()
          copilot.select_inline(1)
        end, {
          buffer = bufnr,
          silent = true,
          desc = "Next inline completion",
        })
        vim.keymap.set({ "i", "n" }, "<A-[>", function()
          copilot.select_inline(-1)
        end, {
          buffer = bufnr,
          silent = true,
          desc = "Previous inline completion",
        })
      end

      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
      end

      map("gd", function()
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname:match("%.hbs$") then
          local ok, ember = pcall(require, "config.ember.definition")
          if ok and ember.goto_definition() then
            return
          end
        end
        vim.lsp.buf.definition()
      end, "Definition")
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
