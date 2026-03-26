local lsp = require("config.lsp")

local prettier_filetypes = {
  css = true,
  hbs = true,
  handlebars = true,
  html = true,
  ["html.handlebars"] = true,
  javascript = true,
  javascriptreact = true,
  json = true,
  jsonc = true,
  scss = true,
  typescript = true,
  typescriptreact = true,
  yaml = true,
}

local prettier_configs = {
  ".prettierrc",
  ".prettierrc.json",
  ".prettierrc.json5",
  ".prettierrc.yml",
  ".prettierrc.yaml",
  ".prettierrc.toml",
  ".prettierrc.js",
  ".prettierrc.cjs",
  ".prettierrc.mjs",
  "prettier.config.js",
  "prettier.config.cjs",
  "prettier.config.mjs",
  "prettier.config.ts",
  "prettier.config.cts",
  "prettier.config.mts",
}

local function has_prettier_executable(start)
  if vim.fn.executable("prettier") == 1 then
    return true
  end

  local prettier_bin = vim.fs.find("node_modules", { path = start, upward = true })[1]
  if not prettier_bin then
    return false
  end

  return vim.fn.executable(vim.fs.joinpath(prettier_bin, ".bin", "prettier")) == 1
end

local function has_prettier(filename)
  local start = filename ~= "" and vim.fs.dirname(filename) or vim.fn.getcwd()
  if not has_prettier_executable(start) then
    return false
  end

  local found = vim.fs.find(prettier_configs, { path = start, upward = true })[1]

  if found then
    return true
  end

  local package_json = vim.fs.find("package.json", { path = start, upward = true })[1]
  if not package_json then
    return false
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_json), "\n"))
  if not ok or type(decoded) ~= "table" then
    return false
  end

  local dependencies = decoded.dependencies or {}
  local dev_dependencies = decoded.devDependencies or {}
  return decoded.prettier ~= nil or dependencies.prettier ~= nil or dev_dependencies.prettier ~= nil
end

local function setup_servers()
  local capabilities = lsp.capabilities()
  local servers = lsp.servers()

  require("mason").setup({ ui = { border = "rounded" } })
  require("mason-lspconfig").setup({
    ensure_installed = vim.tbl_keys(servers),
    automatic_enable = {
      exclude = { "copilot" },
    },
  })

  vim.lsp.config("*", {
    capabilities = capabilities,
  })

  for name, server_opts in pairs(servers) do
    vim.lsp.config(name, server_opts)
    vim.lsp.enable(name)
  end

  if vim.fn.executable("intelephense") == 1 then
    vim.lsp.config("intelephense", {
      cmd = { "intelephense", "--stdio" },
    })
    vim.lsp.enable("intelephense")
  end

  vim.lsp.enable("glint", false)

  lsp.setup_keymaps()
end

return {
  {
    "williamboman/mason.nvim",
    lazy = true,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = true,
    dependencies = { "williamboman/mason.nvim" },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "williamboman/mason-lspconfig.nvim",
    },
    config = setup_servers,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      formatters_by_ft = {
        css = { "prettier" },
        hbs = { "prettier" },
        handlebars = { "prettier" },
        html = { "prettier" },
        ["html.handlebars"] = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        scss = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        yaml = { "prettier" },
      },
      formatters = {
        prettier = {
          condition = function(_, ctx)
            if not prettier_filetypes[vim.bo[ctx.buf].filetype] then
              return false
            end

            return has_prettier(ctx.filename)
          end,
        },
      },
      notify_on_error = true,
    },
  },
}
