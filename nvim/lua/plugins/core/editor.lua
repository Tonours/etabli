-- Core editor plugins
return {
  -- Disable neo-tree (keep snacks explorer)
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },

  -- Show hidden files in snacks explorer
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            hidden = true,
          },
        },
      },
    },
  },

  -- Harpoon for quick file navigation
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ha", function() require("harpoon"):list():add() end, desc = "Harpoon Add" },
      { "<leader>hh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Harpoon Menu" },
      { "<leader>1", function() require("harpoon"):list():select(1) end, desc = "Harpoon 1" },
      { "<leader>2", function() require("harpoon"):list():select(2) end, desc = "Harpoon 2" },
      { "<leader>3", function() require("harpoon"):list():select(3) end, desc = "Harpoon 3" },
      { "<leader>4", function() require("harpoon"):list():select(4) end, desc = "Harpoon 4" },
      { "<leader>5", function() require("harpoon"):list():select(5) end, desc = "Harpoon 5" },
    },
    config = function()
      require("harpoon"):setup()
    end,
  },

  -- Color preview (NvChad fork, actively maintained)
  {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      filetypes = {
        "css",
        "scss",
        "html",
        "javascript",
        "typescript",
        "typescriptreact",
        "javascriptreact",
      },
    },
    config = function(_, opts)
      require("colorizer").setup({ filetypes = opts.filetypes })
    end,
  },

  -- Extra treesitter parsers
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "css", "scss", "sql", "graphql", "prisma",
      })
    end,
  },
}
