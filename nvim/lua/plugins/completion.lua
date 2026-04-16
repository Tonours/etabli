local copilot_node_command_cache = vim.g.copilot_node_command_cache or nil

local function best_copilot_node_command()
  if copilot_node_command_cache then
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
    if not version then
      return false
    end

    if version.major ~= 22 then
      return version.major > 22
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

  local candidates = {}
  local seen = {}

  local function add_candidate(path)
    if path and path ~= "" and not seen[path] and vim.fn.executable(path) == 1 then
      seen[path] = true
      table.insert(candidates, path)
    end
  end

  add_candidate(vim.fn.exepath("node"))
  for _, dir in ipairs(vim.split(vim.env.PATH or "", ":", { plain = true, trimempty = true })) do
    add_candidate(vim.fs.joinpath(dir, "node"))
  end

  local nvm_dir = vim.env.NVM_DIR or (vim.env.HOME and vim.fs.joinpath(vim.env.HOME, ".nvm") or nil)
  local nvm_nodes = nvm_dir and vim.fn.glob(vim.fs.joinpath(nvm_dir, "versions", "node", "*", "bin", "node"), false, true) or {}
  for _, path in ipairs(nvm_nodes) do
    add_candidate(path)
  end

  local best_path
  local best_version

  for _, path in ipairs(candidates) do
    local result = vim.system({ path, "--version" }, { text = true }):wait()
    local version = result.code == 0 and parse_node_version(vim.trim(result.stdout or "")) or nil
    if version and version_is_supported(version) and version_is_newer(version, best_version) then
      best_path = path
      best_version = version
    end
  end

  copilot_node_command_cache = best_path or vim.fn.exepath("node")
  vim.g.copilot_node_command_cache = copilot_node_command_cache
  return copilot_node_command_cache
end

return {
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
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          if #vim.api.nvim_list_uis() == 0 then
            return
          end

          vim.schedule(function()
            local ok_lazy, lazy = pcall(require, "lazy")
            if not ok_lazy then
              return
            end

            lazy.load({ plugins = { "nvim-cmp" } })
            pcall(require, "cmp")
          end)
        end,
      })
    end,
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "zbirenbaum/copilot.lua",
      "zbirenbaum/copilot-cmp",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local compare = cmp.config.compare
      local copilot_cmp = require("copilot_cmp")

      require("copilot").setup({
        copilot_node_command = best_copilot_node_command(),
        suggestion = { enabled = false },
        panel = { enabled = false },
        filetypes = {
          markdown = false,
          help = false,
          gitcommit = true,
          yaml = true,
        },
      })
      copilot_cmp.setup()
      copilot_cmp._on_insert_enter({})

      local function has_words_before()
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        if col == 0 then
          return false
        end

        local current_line = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
        return current_line:sub(col, col):match("%s") == nil
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
          ["<A-y>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.complete()
              return
            end

            cmp.complete()
          end, { "i" }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            elseif has_words_before() then
              cmp.complete()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        preselect = cmp.PreselectMode.None,
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        sources = cmp.config.sources({
          { name = "copilot", max_item_count = 3, group_index = 1 },
          { name = "nvim_lsp", max_item_count = 20 },
          { name = "path", max_item_count = 10 },
        }, {
          { name = "buffer", max_item_count = 10, keyword_length = 3 },
        }),
        formatting = {
          expandable_indicator = true,
        },
        performance = {
          debounce = 25,
          throttle = 8,
          fetching_timeout = 2000,
        },
        sorting = {
          priority_weight = 2,
          comparators = {
            require("copilot_cmp.comparators").prioritize,
            compare.offset,
            compare.exact,
            compare.score,
            compare.recently_used,
            compare.locality,
            compare.kind,
            compare.sort_text,
            compare.length,
            compare.order,
          },
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
