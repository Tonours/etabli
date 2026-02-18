-- React/JSX/TSX development with Biome (linting, formatting, LSP)
return {
  -- Treesitter: JSX/TSX parsers
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "tsx",
        "javascript",
        "typescript",
        "css",
        "html",
      })
    end,
  },

  -- LSP: Biome (only attaches when biome.json exists)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        biome = {},
      },
    },
  },

  -- Formatting: Biome via conform.nvim (only when biome.json exists)
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      local biome_fts = {
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
        "json",
        "jsonc",
        "css",
        "graphql",
        "svelte",
        "vue",
        "astro",
      }
      for _, ft in ipairs(biome_fts) do
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        table.insert(opts.formatters_by_ft[ft], "biome")
      end

      opts.formatters = opts.formatters or {}
      opts.formatters.biome = {
        require_cwd = true,
      }
    end,
  },

  -- Mason: auto-install biome
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "biome" })
    end,
  },
}
