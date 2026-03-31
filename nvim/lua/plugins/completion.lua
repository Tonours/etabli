local copilot_node_command_cache = nil

-- Persistent cache using vim.g to survive across plugin reloads
vim.g.copilot_node_command_cache = vim.g.copilot_node_command_cache or nil

local function best_copilot_node_command()
  -- Check persistent cache first
  if vim.g.copilot_node_command_cache then
    return vim.g.copilot_node_command_cache
  end

  -- Check session cache
  if copilot_node_command_cache then
    vim.g.copilot_node_command_cache = copilot_node_command_cache
    return copilot_node_command_cache
  end

  local function parse_node_version(output)
    local major, minor, patch = (output or ""):match("^v(%d+)%.(%d+)%.(%d+)")
    if not major then
      return nil
    end
    return { major = tonumber(major), minor = tonumber(minor), patch = tonumber(patch) }
  end

  local function version_is_supported(version)
    if not version or version.major ~= 22 then
      return version and version.major > 22 or false
    end
    return version.minor >= 13
  end

  local function version_is_newer(left, right)
    if not right then
      return true
    end
    if left.major ~= right.major then
      return left.major > right.major
    end
    if left.minor ~= right.minor then
      return left.minor > right.minor
    end
    return left.patch > right.patch
  end

  local function candidate_nodes()
    local candidates = {}
    local seen = {}

    local function add(path)
      if path and path ~= "" and not seen[path] and vim.fn.executable(path) == 1 then
        seen[path] = true
        table.insert(candidates, path)
      end
    end

    add(vim.fn.exepath("node"))

    for _, dir in ipairs(vim.split(vim.env.PATH or "", ":", { plain = true, trimempty = true })) do
      add(vim.fs.joinpath(dir, "node"))
    end

    local nvm_dir = vim.env.NVM_DIR or (vim.env.HOME and vim.fs.joinpath(vim.env.HOME, ".nvm") or nil)
    local nvm_nodes = nvm_dir and vim.fn.glob(vim.fs.joinpath(nvm_dir, "versions", "node", "*", "bin", "node"), false, true) or {}
    for _, path in ipairs(nvm_nodes) do
      add(path)
    end

    return candidates
  end

  local function node_supports_sqlite(path)
    local result = vim.system({ path, "-p", "typeof require('node:sqlite')" }, { text = true }):wait()
    return result.code == 0 and vim.trim(result.stdout or "") == "object"
  end

  local best_path
  local best_version

  for _, path in ipairs(candidate_nodes()) do
    local result = vim.system({ path, "--version" }, { text = true }):wait()
    local version = result.code == 0 and parse_node_version(vim.trim(result.stdout or "")) or nil

    if version and version_is_supported(version) and node_supports_sqlite(path) then
      if version_is_newer(version, best_version) then
        best_path = path
        best_version = version
      end
    end
  end

  copilot_node_command_cache = best_path or vim.fn.exepath("node")
  vim.g.copilot_node_command_cache = copilot_node_command_cache
  return copilot_node_command_cache
end

local function ensure_copilot_node_command()
  if vim.g.copilot_node_command_cache then
    return vim.g.copilot_node_command_cache
  end

  return best_copilot_node_command()
end

local function quiet_copilot_on_exit(code, _, client_id)
  local client = require("copilot.client")

  if client.id == client_id then
    vim.schedule(function()
      client.teardown()
      client.id = nil
      client.capabilities = nil
    end)
  end
end

local function setup_copilot_cmp()
  local copilot_cmp = require("copilot_cmp")
  copilot_cmp.setup()

  local group = vim.api.nvim_create_augroup("etabli_copilot_cmp", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = args.data and vim.lsp.get_client_by_id(args.data.client_id) or nil
      if not client or client.name ~= "copilot" then
        return
      end

      copilot_cmp._on_insert_enter({})
    end,
  })
end

local copilot_cmp_ready = false

local function maybe_setup_copilot_cmp()
  if copilot_cmp_ready or vim.bo.filetype == "markdown" then
    return
  end

  copilot_cmp_ready = true
  setup_copilot_cmp()
end

return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    opts = function()
      local node_cmd = ensure_copilot_node_command()
      return {
        copilot_node_command = node_cmd,
        panel = {
          enabled = false,
        },
        suggestion = {
          enabled = false,
        },
        filetypes = {
          gitcommit = true,
          help = true,
          markdown = false,
          yaml = true,
        },
        server_opts_overrides = {
          on_exit = quiet_copilot_on_exit,
        },
      }
    end,
  },
  {
    "zbirenbaum/copilot-cmp",
    lazy = true,
    dependencies = {
      "zbirenbaum/copilot.lua",
    },
    config = function()
      vim.schedule(maybe_setup_copilot_cmp)
    end,
  },
  {
    "L3MON4D3/LuaSnip",
    lazy = true,
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp = require("cmp")

      if vim.bo.filetype ~= "markdown" then
        local ok_lazy, lazy = pcall(require, "lazy")
        if ok_lazy then
          lazy.load({ plugins = { "copilot-cmp" } })
        end
      end

      cmp.setup({
        completion = {
          completeopt = "menu,menuone,noselect",
        },
        experimental = {
          ghost_text = false,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
        }),
        preselect = cmp.PreselectMode.None,
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp", max_item_count = 20 },
          { name = "path", max_item_count = 10 },
          { name = "copilot", max_item_count = 3 },
        }, {
          { name = "buffer", max_item_count = 10, keyword_length = 3 },
        }),
        -- Performance: limit items shown and add debouncing
        formatting = {
          expandable_indicator = true,
        },
        -- Performance: reduce completion trigger frequency
        performance = {
          debounce = 25, -- Debounce completion by 25ms (was 30ms)
          throttle = 8, -- Throttle completion by 8ms (was 10ms)
          fetching_timeout = 200, -- Timeout for fetching completions (was 250ms)
        },
      })

      cmp.setup.filetype("markdown", {
        sources = cmp.config.sources({
          { name = "path", max_item_count = 8 },
        }, {
          { name = "buffer", max_item_count = 8, keyword_length = 5 },
        }),
        performance = {
          debounce = 40,
          throttle = 15,
          fetching_timeout = 120,
        },
      })
    end,
  },
}
