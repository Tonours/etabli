local statusline = require("config.statusline")

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      integrations = {
        mason = true,
        telescope = true,
        treesitter = true,
      },
      custom_highlights = function(colors)
        return {
          DiagnosticSignError = { fg = colors.red, bg = colors.base },
          DiagnosticSignWarn = { fg = colors.yellow, bg = colors.base },
          DiagnosticSignInfo = { fg = colors.sky, bg = colors.base },
          DiagnosticSignHint = { fg = colors.teal, bg = colors.base },
          DiagnosticFloatingError = { fg = colors.red },
          DiagnosticFloatingWarn = { fg = colors.yellow },
          DiagnosticFloatingInfo = { fg = colors.sky },
          DiagnosticFloatingHint = { fg = colors.teal },
          TelescopeBorder = { fg = colors.surface1, bg = colors.base },
          TelescopePromptBorder = { fg = colors.blue, bg = colors.mantle },
          TelescopePromptNormal = { bg = colors.mantle },
          TelescopePromptPrefix = { fg = colors.blue, bg = colors.mantle },
          TelescopeResultsNormal = { bg = colors.base },
          TelescopeSelection = { fg = colors.text, bg = colors.surface0, bold = true },
          TelescopeMatching = { fg = colors.lavender, bold = true },
          NvimTreeNormal = { bg = colors.base },
          NvimTreeNormalNC = { bg = colors.base },
          NvimTreeRootFolder = { fg = colors.blue, bold = true },
          NvimTreeFolderName = { fg = colors.text },
          NvimTreeOpenedFolderName = { fg = colors.blue, bold = true },
          NvimTreeOpenedFile = { fg = colors.lavender, bold = true },
          NvimTreeSpecialFile = { fg = colors.mauve, underline = true },
          NvimTreeIndentMarker = { fg = colors.surface1 },
          WinSeparator = { fg = colors.surface1 },
          NvimTreeWinSeparator = { fg = colors.surface1, bg = colors.base },
        }
      end,
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "catppuccin-mocha",
        globalstatus = true,
        component_separators = { left = "|", right = "|" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {
          {
            statusline.project_label,
            color = statusline.project_color,
          },
        },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "diagnostics" },
        lualine_y = {},
        lualine_z = { "location" },
      },
    },
  },
}
