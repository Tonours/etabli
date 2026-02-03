-- Core editor plugins
return {
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

  -- Spectre for search & replace
  {
    "nvim-pack/nvim-spectre",
    keys = {
      { "<leader>sR", function() require("spectre").open() end, desc = "Search & Replace" },
      { "<leader>sw", function() require("spectre").open_visual({ select_word = true }) end, desc = "Search Word" },
    },
  },

  -- Color preview
  {
    "norcalli/nvim-colorizer.lua",
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
      require("colorizer").setup(opts.filetypes)
    end,
  },

  -- Extra treesitter parsers
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "css", "scss", "sql", "graphql", "prisma",
      })
    end,
  },
}
