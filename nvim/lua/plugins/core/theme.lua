-- Catppuccin theme configuration
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      integrations = {
        cmp = true,
        gitsigns = true,
        telescope = true,
        treesitter = true,
        which_key = true,
        flash = true,
        noice = true,
        notify = true,
        mini = true,
        native_lsp = { enabled = true },
      },
    },
  },

  -- Set catppuccin as default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
