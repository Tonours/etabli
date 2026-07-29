local palette = require("config.palette")

return {
  {
    "catppuccin/nvim",
    name = "catppuccin.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      background = { light = "latte", dark = "mocha" },
      transparent_background = false,
      term_colors = true,
      dim_inactive = { enabled = false },
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
      },
      integrations = {
        cmp = true,
        gitsigns = true,
        markdown = true,
        neotree = true,
        treesitter = true,
        telescope = { enabled = true },
        which_key = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
      },
      custom_highlights = function(colors)
        return {
          -- Align float/chrome borders with tmux pane borders (surface0) and mauve accent.
          FloatBorder = { fg = colors.surface0, bg = colors.mantle },
          WinSeparator = { fg = colors.surface0 },
          BufferLineIndicatorSelected = { fg = colors.mauve },
          BufferLineBufferSelected = { fg = colors.text, bold = true },
          StatusLine = { fg = colors.text, bg = colors.mantle },
          StatusLineNC = { fg = colors.overlay1, bg = colors.mantle },
          -- Expose palette pin for smoke/docs (same hex as ghostty background).
          EtabliPaletteBase = { fg = palette.base },
          EtabliPaletteMauve = { fg = palette.mauve },
        }
      end,
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },
}
