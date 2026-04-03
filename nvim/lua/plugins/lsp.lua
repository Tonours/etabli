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
local prettier_cache_ttl = 10000 -- 10 seconds TTL
local prettier_cache_time = {}
local prettier_package_cache = {}
local prettier_package_cache_mtime = {}

local function parent_dir(path)
  local parent = vim.fs.dirname(path)
  if parent == path then
    return nil
  end

  return parent
end

local function set_prettier_cache(paths, value, now)
  for _, path in ipairs(paths) do
    prettier_cache[path] = value
    prettier_cache_time[path] = now
  end
end

local function cached_prettier(start, now)
  local cached = prettier_cache[start]
  local cached_time = prettier_cache_time[start]
  if cached == nil or not cached_time or (now - cached_time) >= prettier_cache_ttl then
    return nil
  end

  return cached
end

local function package_json_has_prettier(package_json)
  local stat = vim.uv.fs_stat(package_json)
  if not stat or not stat.mtime then
    prettier_package_cache[package_json] = false
    prettier_package_cache_mtime[package_json] = nil
    return false
  end

  local mtime = string.format("%s:%s", stat.mtime.sec or 0, stat.mtime.nsec or 0)
  if prettier_package_cache_mtime[package_json] == mtime and prettier_package_cache[package_json] ~= nil then
    return prettier_package_cache[package_json]
  end

  local ok_read, lines = pcall(vim.fn.readfile, package_json)
  if not ok_read then
    prettier_package_cache[package_json] = false
    prettier_package_cache_mtime[package_json] = mtime
    return false
  end

  local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode or type(decoded) ~= "table" then
    prettier_package_cache[package_json] = false
    prettier_package_cache_mtime[package_json] = mtime
    return false
  end

  local dependencies = decoded.dependencies or {}
  local dev_dependencies = decoded.devDependencies or {}
  local result = decoded.prettier ~= nil or dependencies.prettier ~= nil or dev_dependencies.prettier ~= nil

  prettier_package_cache[package_json] = result
  prettier_package_cache_mtime[package_json] = mtime
  return result
end

local function has_prettier_executable(start)
  if vim.fn.executable("prettier") == 1 then
    return true
  end

  local dir = start
  while dir do
    if vim.fn.executable(vim.fs.joinpath(dir, "node_modules", ".bin", "prettier")) == 1 then
      return true
    end

    dir = parent_dir(dir)
  end

  return false
end

local function has_prettier(filename)
  local start = filename ~= "" and vim.fs.dirname(filename) or vim.fn.getcwd()

  -- Check cache first
  local now = vim.loop.now()
  local cached = cached_prettier(start, now)
  if cached ~= nil then
    return cached
  end

  if not has_prettier_executable(start) then
    set_prettier_cache({ start }, false, now)
    return false
  end

  local visited = {}
  local dir = start

  while dir do
    table.insert(visited, dir)

    local dir_cached = cached_prettier(dir, now)
    if dir_cached ~= nil then
      set_prettier_cache(visited, dir_cached, now)
      return dir_cached
    end

    for _, config in ipairs(prettier_configs) do
      if vim.uv.fs_stat(vim.fs.joinpath(dir, config)) then
        set_prettier_cache(visited, true, now)
        return true
      end
    end

    local package_json = vim.fs.joinpath(dir, "package.json")
    if vim.uv.fs_stat(package_json) then
      local result = package_json_has_prettier(package_json)
      set_prettier_cache(visited, result, now)
      return result
    end

    dir = parent_dir(dir)
  end

  set_prettier_cache(visited, false, now)
  return false
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
        prettier_package_cache = {}
        prettier_package_cache_mtime = {}
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

  vim.lsp.config("glint", {
    root_dir = lsp.glint_root_dir,
  })
  vim.lsp.enable("glint")

  if vim.fn.executable("intelephense") == 1 then
    vim.lsp.config("intelephense", {
      cmd = { "intelephense", "--stdio" },
    })
    vim.lsp.enable("intelephense")
  end

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
