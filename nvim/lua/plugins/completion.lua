local function parse_node_version(output)
  local major, minor, patch = (output or ""):match("^v(%d+)%.(%d+)%.(%d+)")
  if not major then
    return nil
  end

  return {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
  }
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
  local nvm_nodes = nvm_dir and vim.fn.glob(vim.fs.joinpath(nvm_dir, "versions", "node", "*", "bin", "node"), false, true)
    or {}
  for _, path in ipairs(nvm_nodes) do
    add(path)
  end

  return candidates
end

local function node_supports_sqlite(path)
  local result = vim.system({ path, "-p", "typeof require('node:sqlite')" }, { text = true }):wait()
  return result.code == 0 and vim.trim(result.stdout or "") == "object"
end

local function best_copilot_node_command()
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

  return best_path or vim.fn.exepath("node")
end

local copilot_node_command = best_copilot_node_command()

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

return {
  {
    "zbirenbaum/copilot.lua",
    lazy = false,
    cmd = "Copilot",
    opts = {
      copilot_node_command = copilot_node_command ~= "" and copilot_node_command or nil,
      panel = {
        enabled = false,
      },
      suggestion = {
        enabled = false,
      },
      filetypes = {
        gitcommit = true,
        markdown = false,
        yaml = true,
      },
      server_opts_overrides = {
        on_exit = quiet_copilot_on_exit,
      },
    },
  },
  {
    "zbirenbaum/copilot-cmp",
    event = "InsertEnter",
    dependencies = {
      "zbirenbaum/copilot.lua",
    },
    config = function()
      require("copilot_cmp").setup()
    end,
  },
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "zbirenbaum/copilot-cmp",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

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
            luasnip.lsp_expand(args.body)
          end,
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "path" },
          { name = "copilot" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },
}
