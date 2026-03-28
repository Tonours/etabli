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

-- Cache for prettier detection results
local prettier_cache = {}
local prettier_cache_ttl = 10000 -- 10 seconds TTL (reduced from 15s for fresher data)
local prettier_cache_time = {}

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

  -- Check cache first
  local now = vim.loop.now()
  local cached = prettier_cache[start]
  local cached_time = prettier_cache_time[start]
  if cached ~= nil and cached_time and (now - cached_time) < prettier_cache_ttl then
    return cached
  end

  if not has_prettier_executable(start) then
    prettier_cache[start] = false
    prettier_cache_time[start] = now
    return false
  end

  local found = vim.fs.find(prettier_configs, { path = start, upward = true })[1]

  if found then
    prettier_cache[start] = true
    prettier_cache_time[start] = now
    return true
  end

  local package_json = vim.fs.find("package.json", { path = start, upward = true })[1]
  if not package_json then
    prettier_cache[start] = false
    prettier_cache_time[start] = now
    return false
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_json), "\n"))
  if not ok or type(decoded) ~= "table" then
    prettier_cache[start] = false
    prettier_cache_time[start] = now
    return false
  end

  local dependencies = decoded.dependencies or {}
  local dev_dependencies = decoded.devDependencies or {}
  local result = decoded.prettier ~= nil or dependencies.prettier ~= nil or dev_dependencies.prettier ~= nil

  prettier_cache[start] = result
  prettier_cache_time[start] = now
  return result
end

local function setup_servers()
  local capabilities = lsp.capabilities()
  local servers = lsp.servers()

  -- Clear prettier cache on directory change (batched cleanup)
  local clear_cache_timer = nil
  vim.api.nvim_create_autocmd("DirChanged", {
    callback = function()
      -- Debounce cache clear to avoid repeated clears during rapid directory changes
      if clear_cache_timer then
        vim.fn.timer_stop(clear_cache_timer)
      end
      clear_cache_timer = vim.fn.timer_start(25, function()
        prettier_cache = {}
        prettier_cache_time = {}
        clear_cache_timer = nil
      end)
    end,
  })

  -- Defer Mason setup to not block startup at all
  vim.schedule(function()
    -- Lazy-load Mason only when needed
    local ok_mason, mason = pcall(require, "mason")
    if not ok_mason then
      return
    end

    mason.setup({ ui = { border = "rounded" } })

    local ok_mason_lspconfig, mason_lspconfig = pcall(require, "mason-lspconfig")
    if ok_mason_lspconfig then
      mason_lspconfig.setup({
        ensure_installed = vim.tbl_keys(servers),
        automatic_enable = {
          exclude = { "copilot" },
        },
      })
    end
  end)

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
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
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
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
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
      -- Performance: skip formatting large files
      format_on_save = function(bufnr)
        if vim.b[bufnr].large_file then
          return nil
        end
        return { timeout_ms = 500, lsp_format = "fallback" }
      end,
    },
  },
}
